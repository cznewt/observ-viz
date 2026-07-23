#!/usr/bin/env python3
"""Generate docs/collectors.md — per-collector metric inventories + the
signal -> collector cross-reference.

Collector definitions come from libs/common-lib/collectors.libsonnet. When
GRAFANA_URL/GRAFANA_TOKEN are available (.env), every live metric name is
pulled from the datasource and assigned to the collector with the longest
matching pattern, so the doc lists exactly what each exporter produces on
this fleet. Signals are evaluated from every observ-lib and mapped to the
collectors that can supply their metrics (multi-collector unions shown).
"""
import json
import os
import re
import sys
import urllib.request

import _jsonnet

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_env():
    envf = os.path.join(ROOT, ".env")
    if os.path.exists(envf):
        for line in open(envf):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k, v)


def registry():
    out = json.loads(_jsonnet.evaluate_snippet(
        "c", "(import 'libs/common-lib/collectors.libsonnet').collectors", jpathdir=[ROOT]))
    comp = {}
    for name, c in out.items():
        comp[name] = {
            "source": c.get("source", ""),
            "notes": c.get("notes", ""),
            "patterns": [(p, re.compile("^(?:" + p + ")$")) for p in c["patterns"]],
        }
    return comp


def live_metrics():
    url = os.environ.get("GRAFANA_URL")
    token = os.environ.get("GRAFANA_TOKEN")
    if not url or not token:
        return None
    req = urllib.request.Request(
        url + "/api/datasources/proxy/uid/newt-mimir/api/v1/label/__name__/values")
    req.add_header("Authorization", "Bearer " + token)
    try:
        return sorted(json.load(urllib.request.urlopen(req, timeout=30))["data"])
    except Exception as e:  # noqa: BLE001
        print("WARN: live metric fetch failed:", e, file=sys.stderr)
        return None


def assign(metrics, reg):
    per = {name: [] for name in reg}
    for m in metrics:
        best, best_len = None, -1
        for name, c in reg.items():
            for pat, rx in c["patterns"]:
                if rx.match(m) and len(pat) > best_len:
                    best, best_len = name, len(pat)
        if best:
            per[best].append(m)
    return per


METRIC_RX = re.compile(r"[a-zA-Z_][a-zA-Z0-9_:]*")
FUNC_WORDS = set("""rate irate sum max min avg count count_values topk bottomk by on group_left group_right
label_replace label_join or and unless without increase delta idelta changes predict_linear
last_over_time max_over_time min_over_time avg_over_time count_over_time sum_over_time present_over_time
time timestamp vector scalar histogram_quantile clamp_max clamp_min abs ceil floor round sort sort_desc
queriesSelector instant interval""".split())


def lib_signals(reg):
    idx = json.loads(_jsonnet.evaluate_snippet(
        "l", "std.objectFields((import 'libs/observ-libs.libsonnet'))", jpathdir=[ROOT]))
    snip = """
local libs = import 'libs/observ-libs.libsonnet';
local flat(prefix, o) =
  if std.objectHas(o, 'new') then [{ name: prefix, lib: o }]
  else std.flattenArrays([flat(prefix + '.' + f, o[f]) for f in std.objectFields(o) if std.type(o[f]) == 'object']);
local packs = flat('', { x: libs }).x
"""
    # simpler: enumerate dotted packs via python-side probing
    packs = []
    def walk(path):
        expr = "local l = import 'libs/observ-libs.libsonnet'; std.objectFields(l" + path + ")"
        try:
            fields = json.loads(_jsonnet.evaluate_snippet("w", expr, jpathdir=[ROOT]))
        except Exception:
            return
        if "new" in fields:
            packs.append(path)
            return
        for f in fields:
            walk(path + "['" + f + "']")
    walk("")
    out = {}
    for path in packs:
        dotted = path.replace("']['", ".").strip("[']")
        expr = ("local l = import 'libs/observ-libs.libsonnet'; local p = l" + path + ".new({});"
                "if std.objectHas(p, 'signals') then {"
                " [k]: p.signals[k].asTarget().spec.query.spec.expr for k in std.objectFields(p.signals) } else {}")
        try:
            sigs = json.loads(_jsonnet.evaluate_snippet("s", expr, jpathdir=[ROOT]))
        except Exception:
            continue
        rows = []
        for sname in sorted(sigs):
            tokens = set(METRIC_RX.findall(sigs[sname])) - FUNC_WORDS
            cols = set()
            mets = set()
            for t in tokens:
                best, best_len = None, -1
                for cname, c in reg.items():
                    if cname == "app.exporters":
                        continue
                    for pat, rx in c["patterns"]:
                        if rx.match(t) and len(pat) > best_len:
                            best, best_len = cname, len(pat)
                if best:
                    cols.add(best)
                    mets.add(t)
            if mets:
                rows.append((sname, sorted(mets), sorted(cols)))
        if rows:
            out[dotted] = rows
    return out


def slug(name):
    return name.replace(".", "-")


def main():
    load_env()
    reg = registry()
    live = live_metrics()
    per = assign(live, reg) if live else {}
    sigmap = lib_signals(reg)
    outdir = os.path.join(ROOT, "docs", "collectors")
    os.makedirs(outdir, exist_ok=True)
    for f in os.listdir(outdir):
        if f.endswith(".md"):
            os.remove(os.path.join(outdir, f))

    # reverse map: collector -> [(lib, signal, metrics)]
    consumers = {}
    for lib, rows in sigmap.items():
        for sname, mets, cols in rows:
            for cname in cols:
                consumers.setdefault(cname, []).append((lib, sname, mets))

    # index page
    idx = ["# Collectors", "",
           "One page per collector — its metric families and, when the live "
           "inventory is reachable, every metric it currently produces on this "
           "fleet. Generated by `scripts/gen-collector-docs.py` from "
           "`libs/common-lib/collectors.libsonnet`.", "",
           "| Collector | Source | Live metrics | Consuming signals |",
           "| --- | --- | --- | --- |"]
    for name in sorted(reg):
        idx += ["| [" + name + "](" + slug(name) + ".md) | " + reg[name]["source"]
                + " | " + (str(len(per.get(name, []))) if live else "—")
                + " | " + str(len(consumers.get(name, []))) + " |"]
    idx += ["", "See also the [signal map](signals.md)."]
    open(os.path.join(outdir, "index.md"), "w").write("\n".join(idx) + "\n")

    # one page per collector
    for name in sorted(reg):
        c = reg[name]
        lines = ["# " + name, "", "- **source**: " + c["source"]]
        if c["notes"]:
            lines += ["- **notes**: " + c["notes"]]
        lines += ["- **patterns**: " + ", ".join("`" + p + "`" for p, _ in c["patterns"]), ""]
        cons = consumers.get(name, [])
        if cons:
            lines += ["## Consuming signals", "", "| Lib | Signal | Metrics |", "| --- | --- | --- |"]
            for lib, sname, mets in sorted(cons):
                lines += ["| " + lib + " | " + sname + " | "
                          + "<br>".join("`" + m + "`" for m in mets) + " |"]
            lines += [""]
        ms = per.get(name, [])
        lines += ["## Live metrics (%s)" % (len(ms) if live else "inventory unavailable"), ""]
        lines += (["- `" + m + "`" for m in ms] if ms else ["_none currently in the datasource_"])
        open(os.path.join(outdir, slug(name) + ".md"), "w").write("\n".join(lines) + "\n")

    # signal map page
    lines = ["# Signals -> collectors", "",
             "Which collector(s) can supply each observ-lib signal "
             "(multiple collectors = cross-OS/exporter union).", ""]
    for lib in sorted(sigmap):
        lines += ["## " + lib, "", "| Signal | Metrics | Collectors |", "| --- | --- | --- |"]
        for sname, mets, cols in sigmap[lib]:
            lines += ["| " + sname + " | " + "<br>".join("`" + m + "`" for m in mets)
                      + " | " + ", ".join("[" + cname + "](" + slug(cname) + ".md)" for cname in cols) + " |"]
        lines += [""]
    open(os.path.join(outdir, "signals.md"), "w").write("\n".join(lines) + "\n")

    legacy = os.path.join(ROOT, "docs", "collectors.md")
    if os.path.exists(legacy):
        os.remove(legacy)
    n_live = sum(len(v) for v in per.values()) if live else 0
    print("wrote docs/collectors/: %d pages, %d live metrics, %d libs cross-referenced"
          % (len(reg) + 2, n_live, len(sigmap)))


if __name__ == "__main__":
    main()
