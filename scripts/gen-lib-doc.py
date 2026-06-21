#!/usr/bin/env python3
"""Generate a detailed doc page per observ-lib (signals + dashboard groups +
alerts + recording rules) into docs/observ-libs/, plus an index.

  gen-lib-doc.py [lib.dotted.path ...]   # default: all libs in the index
"""
import json
import os
import sys

import _jsonnet

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTDIR = os.path.join(ROOT, "docs", "observ-libs")

GROUPS = {
    "Runtimes": ["runtimes.golang", "runtimes.jvm", "runtimes.python", "runtimes.dotnet", "runtimes.nodejs"],
    "System": ["system.linux", "system.docker", "system.windows"],
    "Kubernetes": ["kubernetes.pod", "kubernetes.cadvisor"],
    "Databases": ["databases.sql.postgres", "databases.sql.mysql", "databases.kv.redis", "databases.kv.memcached", "databases.kv.etcd"],
    "Monitoring": ["monitoring.prometheus", "monitoring.mimir", "monitoring.loki", "monitoring.tempo", "monitoring.pyroscope"],
    "Collector": ["collector.alloy"],
    "Networking": ["networking.wireguard", "networking.unifi"],
    "Applications": ["applications.syncthing"],
    "Cross-cutting": ["alerts", "logs"],
}
ALL = [p for v in GROUPS.values() for p in v]


def ev(snip):
    return json.loads(_jsonnet.evaluate_snippet("t", snip, jpathdir=[ROOT]))


def lib_data(p):
    snip = (
        f"local l=(import 'g.libsonnet').libs.{p}.new({{}});"
        "local sig(k)= l.signals[k];"
        "{"
        " title: l.config.dashboardTitle, uid: l.config.uid,"
        " signals: [{ n:k,"
        "   u: (local d=sig(k).asTimeSeries('x').spec.vizConfig.spec.fieldConfig.defaults; if std.objectHas(d,'unit') then d.unit else ''),"
        "   e: sig(k).asTarget().spec.query.spec.expr,"
        "   re: sig(k).asRecordingRule('_', '', '5m').expr } for k in std.objectFields(l.signals)],"
        " groups: [{ t:g.title, els:std.objectFields(g.elements) } for g in (if std.objectHas(l.grafana,'groups') then l.grafana.groups else [])],"
        " alerts: [{ n:r.alert, sev:(if std.objectHas(r.labels,'severity') then r.labels.severity else ''),"
        "   f:r['for'], e:r.expr, url:(if std.objectHas(r.annotations,'runbook_url') then r.annotations.runbook_url else '') }"
        "   for grp in (if std.objectHas(l,'prometheus') then l.prometheus.alerts else []) for r in grp.rules],"
        " records: [{ n:r.record, e:r.expr } for grp in (if std.objectHas(l,'prometheus') && std.objectHas(l.prometheus,'rules') then l.prometheus.rules else []) for r in grp.rules],"
        "}"
    )
    return ev(snip)


def fence(e):
    return "`" + e.replace("\n", " ").replace("|", "\\|") + "`"


def page(p, d):
    L = [f"# {d['title']}  (`g.libs.{p}`)", "",
         f"Dashboard uid `{d['uid']}` · {len(d['signals'])} signals · {len(d['alerts'])} alerts · {len(d['records'])} recording rules.", ""]
    recorded_by = {r["e"]: r["n"] for r in d["records"]}
    L += ["## Signals", "",
          "Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).", "",
          "| Signal | Unit | Query | Recorded as |", "|--------|------|-------|-------------|"]
    for s in d["signals"]:
        rec = recorded_by.get(s.get("re"))
        L.append(f"| `{s['n']}` | {s['u'] or '—'} | {fence(s['e'])} | {('`' + rec + '`') if rec else '—'} |")
    L += ["", "## Dashboard", ""]
    for g in d["groups"]:
        L.append(f"- **{g['t']}** — " + ", ".join(f"`{e}`" for e in g["els"]))
    if d["alerts"]:
        L += ["", "## Alerts", "", "| Alert | Severity | For | Runbook |", "|-------|----------|-----|---------|"]
        seen = set()
        for a in d["alerts"]:
            if a["n"] in seen:
                continue
            seen.add(a["n"])
            rb = f"[runbook]({a['url']})" if a["url"] else "—"
            L.append(f"| `{a['n']}` | {a['sev']} | {a['f']} | {rb} |")
    if d["records"]:
        L += ["", "## Recording rules", "", "| Record | Expression |", "|--------|------------|"]
        for r in d["records"]:
            L.append(f"| `{r['n']}` | {fence(r['e'])} |")
    L.append("")
    return "\n".join(L)


def main():
    libs = sys.argv[1:] or ALL
    os.makedirs(OUTDIR, exist_ok=True)
    written = []
    for p in libs:
        try:
            d = lib_data(p)
        except Exception as exc:  # noqa: BLE001
            print(f"  SKIP {p}: {str(exc).splitlines()[0]}")
            continue
        slug = p.replace(".", "-")
        with open(os.path.join(OUTDIR, slug + ".md"), "w") as fh:
            fh.write(page(p, d))
        written.append((p, slug, d))
    # index
    idx = ["# observ-libs reference", "",
           "Detailed reference per observ-lib — signals, dashboard groups, alerts, recording rules.", "",
           "| Lib | Signals | Alerts | Rules |", "|-----|---------|--------|-------|"]
    for p, slug, d in written:
        idx.append(f"| [`{p}`]({slug}.md) | {len(d['signals'])} | {len(d['alerts'])} | {len(d['records'])} |")
    idx.append("")
    with open(os.path.join(OUTDIR, "index.md"), "w") as fh:
        fh.write("\n".join(idx))
    print(f"wrote {len(written)} lib page(s) + index to docs/observ-libs/")


if __name__ == "__main__":
    main()
