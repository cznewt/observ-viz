#!/usr/bin/env python3
"""Build the docs site's library pages and board tree.

One page per observ-lib, grouped by namespace (Runtimes, System, Kubernetes,
...): what the library is, its signals (what each shows, the metrics its query
reads, unit, query, recording rule), the metrics with the collector that
produces each, its alert rules with their runbooks, its recording rules - and
its board, every tab as the docs Grafana renders it. The boards are one part of
a library; the Boards section files every board in the Grafana folders it lives
in and links each to its library (or to a page of its own when no library owns
it: the analysis, chart-type, deployment-target and base boards).

Inputs:
  docs/boards.json            libraries, mixin boards and the collector registry
                              (scripts/gen-lib-doc.py)
  docs/shots/manifest.json    the screenshots (docs-shots branch, scripts/shots.py);
                              optional - without it every board gets a placeholder
Outputs (gitignored, written at docs build time):
  docs/observ-libs/index.md, <namespace>/index.md, <namespace>/<lib>.md
  docs/boards/index.md, <folder>/.../index.md   the Grafana folder tree
  docs/boards/<folder>/.../<uid>.md             a board no library owns
  docs/.gen/overview.md       the home page's overview (docs/index.md includes it)
  mkdocs.gen.yml              mkdocs.yml + the generated navigation + redirects
                              from the former pages
Build with `mkdocs build -f mkdocs.gen.yml` (see `just docs`).

Another repository (observ-libs) builds its own tree with the same script:
--docs its docs folder (boards.json in it), --mkdocs its mkdocs.yml (the
generated file lands next to it), --site its name for the overview pages,
--lib-prefix how its library paths read. Shots of several Grafanas sit in
<docs>/shots/<name>/, each with its manifest.json.
"""
import argparse
import glob
import json
import os
import re
import shutil

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
SHOTS = os.path.join(DOCS, "shots")
LIB_PREFIX = "g.libs."
LIBS_DIR = "observ-libs"
# top-level board folders, in this order; a board in any other root folder becomes a workload
SECTIONS = ["Analysis", "Platform", "Workloads", "Components", "Reference", "Base"]
RUNTIMES = ["Reference", "Runtimes"]
FALLBACK_FOLDER = ["Components", "Common"]
# library namespaces (the first part of the path), in this order; one-part paths
# (alerts, logs, backstage) are cross-cutting; unknown ones follow alphabetically
NAMESPACES = [("runtimes", "Runtimes"), ("frameworks", "Frameworks"), ("instrumentation", "Instrumentation"),
              ("system", "System"), ("kubernetes", "Kubernetes"), ("databases", "Databases"),
              ("networking", "Networking"), ("webservers", "Web servers"), ("monitoring", "Monitoring"),
              ("collector", "Collector"), ("services", "Services"), ("applications", "Applications"),
              ("automation", "Automation"), ("cicd", "CI/CD"), ("iot", "IoT"), ("demos", "Demos"),
              ("cross-cutting", "Cross-cutting"), ("analysis", "Analysis")]
# deployment-target boards instantiate a library under another uid: their page
# links to the library's page instead of repeating its alerts
DEPLOY = {
    "observ-viz-deploy-kube-pod": "kubernetes.pod",
    "observ-viz-deploy-cadvisor": "kubernetes.cadvisor",
}
ADMONITION = {"critical": "danger", "warning": "warning", "info": "info"}


def method(path):
    """The method libraries are documented by their boards (Analysis / <method>)."""
    return path.startswith("analysis.")


def skipped(path):
    """No page of their own: the method libraries, and the composer (it needs a
    whitebox to build anything)."""
    return method(path) or path == "service"


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-") or "board"


def fence(e):
    return "`" + e.replace("\n", " ").replace("|", "\\|") + "`" if e else "—"


def cell(s):
    return (s or "").replace("\n", " ").replace("|", "\\|")


def code(names):
    return "<br>".join(f"`{n}`" for n in names) if names else "—"


def rel(target, page):
    return os.path.relpath(target, os.path.dirname(page)).replace(os.sep, "/")


def table(header, rows):
    return ["| " + " | ".join(header) + " |", "|" + "|".join("---" for _ in header) + "|"] + \
           ["| " + " | ".join(str(c) for c in r) + " |" for r in rows] + [""]


# ---- metrics: the metric names a PromQL expression reads ----
STRINGS = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'|`[^`]*`')
NAME_MATCHER = re.compile(r'__name__\s*(=~|=)\s*"((?:[^"\\]|\\.)*)"')
GROUPING = re.compile(r"\b(by|without|on|ignoring|group_left|group_right)\s*\([^()]*\)")
IDENT = re.compile(r"(?<![A-Za-z0-9_:$.])[A-Za-z_:][A-Za-z0-9_:]*")
NOT_METRICS = set("""by without on ignoring group_left group_right bool and or unless offset atan2 inf nan
sum min max avg group stddev stdvar count count_values bottomk topk quantile limitk limit_ratio
abs absent absent_over_time ceil changes clamp clamp_max clamp_min day_of_month day_of_week day_of_year
days_in_month delta deriv exp floor histogram_avg histogram_count histogram_fraction histogram_quantile
histogram_stddev histogram_stdvar histogram_sum holt_winters double_exponential_smoothing hour idelta
increase irate label_join label_replace ln log2 log10 minute month predict_linear rate resets round scalar
sgn sort sort_desc sort_by_label sort_by_label_desc sqrt time timestamp vector year avg_over_time
min_over_time max_over_time sum_over_time count_over_time quantile_over_time stddev_over_time
stdvar_over_time last_over_time present_over_time mad_over_time start end info""".split())


def metrics_of(expr):
    found = set()
    for op, val in NAME_MATCHER.findall(expr or ""):
        found.update(v for v in (val.split("|") if op == "=~" else [val]) if re.fullmatch(r"[A-Za-z_:][A-Za-z0-9_:]*", v))
    s = STRINGS.sub('""', expr or "")
    s = re.sub(r"\{[^{}]*\}", "{}", s)            # label matchers
    s = re.sub(r"\[[^\[\]]*\]", "[]", s)          # ranges and subqueries
    s = GROUPING.sub(r"\1", s)                    # by (...) / on (...) label lists
    s = re.sub(r"\$\{[^}]*\}|\$\w+", " ", s)      # dashboard variables
    for m in IDENT.finditer(s):
        word = m.group(0)
        if word in NOT_METRICS or s[m.end():].lstrip().startswith("("):
            continue
        found.add(word)
    return sorted(found)


def compile_collectors(reg):
    return {name: dict(c, rx=[(p, re.compile("^(?:" + p + ")$")) for p in c["patterns"]]) for name, c in reg.items()}


def collector_of(metric, collectors):
    """The collector whose longest pattern matches (exporters.libsonnet), or None."""
    best, best_len = None, -1
    for name, c in collectors.items():
        for pat, rx in c["rx"]:
            if rx.match(metric) and len(pat) > best_len:
                best, best_len = name, len(pat)
    return best


# ---- libraries and boards ----
def namespace(p):
    return p.split(".")[0] if "." in p else "cross-cutting"


def ns_title(ns):
    return dict(NAMESPACES).get(ns, ns.replace("-", " ").capitalize())


def ns_order(ns):
    keys = [k for k, _ in NAMESPACES]
    return (keys.index(ns), ns) if ns in keys else (len(keys) - 1.5, ns)


def lib_page(p):
    parts = p.split(".")
    name = "-".join(parts[1:]) if len(parts) > 1 else p
    return os.path.join(LIBS_DIR, namespace(p), name + ".md")


def lib_alias(uid, libs):
    """The library a board renders under a uid of its own (reference runtime and
    framework boards, scenario instances of a service preset)."""
    for pattern, prefix in ((r"observ-viz-lang-(.+)$", "runtimes."), (r"observ-viz-framework-(.+)$", "frameworks."),
                            (r"scn-[^-]+-(.+)$", "services.")):
        m = re.match(pattern, uid)
        if m and prefix + m.group(1) in libs:
            return prefix + m.group(1)
    return None


def lib_folder(path, lib, alias_folder):
    folder = list(lib["folder"])
    if path.startswith(("runtimes.", "frameworks.")) and (not folder or folder[0] == "Components"):
        return RUNTIMES  # every runtime board in one place, as the reference boards are
    if folder and folder[0] not in SECTIONS:
        return ["Workloads"] + folder  # a root of its own (Parental Control): what runs on the platform
    return folder or alias_folder or FALLBACK_FOLDER


def short_title(title, folder):
    """'RED / Kubernetes API server' under Analysis / RED reads 'Kubernetes API server'."""
    for f in reversed(folder):
        for sep in (" / ", ": "):
            if title.lower().startswith(f.lower() + sep):
                return title[len(f) + len(sep):]
    return title


def collect(data, shots):
    """Library entries (path -> page) and every board (uid -> entry) in its Grafana folder."""
    libs, mix = data["libs"], data["boards"]
    aliases = {}
    for uid in sorted(set(mix) | set(shots)):
        p = lib_alias(uid, libs)
        if p:
            aliases.setdefault(p, []).append(uid)
    alias_uids = {u for us in aliases.values() for u in us}
    lib_entries = {}
    for p, lib in sorted(libs.items()):
        if skipped(p):
            continue
        uid = lib["uid"]
        shot = uid if uid in shots else next((a for a in aliases.get(p, []) if a in shots), None)
        lib_entries[p] = {"path": p, "lib": lib, "page": lib_page(p), "uid": uid, "shot": shot,
                          "title": lib["title"], "aliases": aliases.get(p, [])}
    boards = {}
    for uid, b in mix.items():
        if uid in alias_uids:
            continue  # documented on its library's page
        folder = ["Base"] if b.get("source") == "base" else b["folder"]
        boards[uid] = {"uid": uid, "shot": uid, "title": b["title"], "folder": folder,
                       "description": b.get("description", "")}
    for p, e in lib_entries.items():
        alias_folder = next((mix[a]["folder"] for a in e["aliases"] if a in mix), None)
        b = boards.setdefault(e["uid"], {"uid": e["uid"], "title": e["title"], "description": "",
                                          "folder": lib_folder(p, e["lib"], alias_folder)})
        if b.get("lib"):
            continue  # two libraries on one board uid: the first one owns it
        b.update(lib=p, page=e["page"], shot=e["shot"])
        e["folder"] = b["folder"]
    for uid, p in DEPLOY.items():
        if uid in boards and p in lib_entries:
            boards[uid]["deploys"] = p
    # rendered boards nothing above knows (a site's own scenario boards)
    for uid, s in shots.items():
        if uid not in boards and uid not in alias_uids:
            boards[uid] = {"uid": uid, "shot": uid, "title": s["title"],
                           "folder": s.get("folderPath") or [s.get("folder") or "Other"], "description": s.get("description", "")}
    for b in boards.values():
        if not b.get("description") and b.get("shot") in shots:
            b["description"] = shots[b["shot"]].get("description", "")
        if not b["folder"]:
            b["folder"] = FALLBACK_FOLDER
        elif b["folder"][0] not in SECTIONS:
            b["folder"] = ["Workloads"] + list(b["folder"])
        b["dir"] = os.path.join("boards", *[slug(f) for f in b["folder"]])
        b["boardPage"] = os.path.join(b["dir"], b["uid"] + ".md")  # the board tree's own path (old pages too)
        b.setdefault("page", b["boardPage"])
        b["navTitle"] = short_title(b["title"], b["folder"])
    # what wraps what: a service library's whitebox is a component library's board
    uid_lib = {e["uid"]: p for p, e in lib_entries.items()}
    for p, e in lib_entries.items():
        w = uid_lib.get(e["lib"].get("whitebox") or "")
        if w and w != p:
            e["wraps"] = w
            lib_entries[w].setdefault("wrappedBy", []).append(p)
    return lib_entries, boards, aliases


# ---- pages ----
class Ctx:
    def __init__(self, data, manifest, entries, boards, collectors):
        self.data, self.manifest, self.entries, self.boards = data, manifest, entries, boards
        self.collectors = collectors


def anchor(heading):
    """The id mkdocs' toc gives a heading (it keeps underscores)."""
    return re.sub(r"[-\s]+", "-", re.sub(r"[^\w\s-]", "", heading).strip().lower())


def collector_link(name, ctx, page):
    if not name:
        return "—"
    c = ctx.collectors[name]
    target = os.path.join("exporters", c["exporter"] + ".md")
    label = f"{c['exporter']} / {c['collector']}"
    if os.path.exists(os.path.join(DOCS, target)):
        return f"[{label}]({rel(target, page)}#{anchor(c['collector'])})"
    return label


def lib_metrics(lib):
    """metric -> the signals, alert rules and recording rules that read it."""
    uses = {}

    def add(expr, kind, name):
        for m in metrics_of(expr):
            uses.setdefault(m, {"signals": [], "alerts": [], "records": []})[kind].append(name)
    for s in lib["signals"]:
        if s.get("k", "prometheus") == "prometheus":
            add(s["e"], "signals", s["n"])
    for a in lib["alerts"]:
        add(a["e"], "alerts", a["n"])
    for r in lib["records"]:
        add(r["e"], "records", r["n"])
    return uses


def where(metric, ctx, records):
    if metric in records:
        return "recording rule (this library)"
    return collector_of(metric, ctx.collectors)


def screenshots(shot, title, page, ctx, heading="###"):
    L = []
    masked = "; log lines are masked" if shot.get("logsMasked", ctx.manifest.get("logsMasked")) else ""
    L += [f"*Rendered from {shot.get('grafana', ctx.manifest.get('grafana', ''))} on {shot.get('rendered', ctx.manifest.get('rendered', ''))}: each tab as that Grafana "
          f"draws it with its own data, so a panel without data there shows \"No data\"{masked}.*", ""]
    for t in shot["tabs"]:
        if len(shot["tabs"]) > 1:
            L += [f"{heading} {t['title']}", ""]
        if t.get("loading"):
            L += ["*Some queries were still running when this was captured, so a panel may be empty.*", ""]
        L += [f"![{title} - {t['title']}]({rel(os.path.join('shots', t['file']), page)})", ""]
    return L


def runbook_block(a):
    sev = a.get("sev") or "warning"
    head = f"{a['n']} · {sev}" + (f" · for {a['f']}" if a.get("f") else "")
    # the runbook's own headings (Meaning, Impact, ...) as bold lines, so they
    # stay out of the page's table of contents
    body = re.sub(r"^#{1,6} +(.+?) *#*$", r"**\1**", a.get("rb") or "", flags=re.M)
    L = [f'<a id="runbook-{slug(a["n"])}"></a>', "", f'??? {ADMONITION.get(sev, "note")} "{head}"']
    L += [("    " + line) if line else "" for line in body.split("\n")]
    return L + [""]


def library_page(e, ctx):
    page, lib, p = e["page"], e["lib"], e["path"]
    shot = ctx.manifest["boards"].get(e["shot"]) if e["shot"] else None
    board = ctx.boards[e["uid"]]
    uses = lib_metrics(lib)
    records = {r["n"] for r in lib["records"]}
    collectors = sorted({c for m in uses for c in [where(m, ctx, records)] if c and c in ctx.collectors})
    L = [f"# {e['title']}", ""]
    desc = lib.get("description") or board.get("description")
    if desc:
        L += [desc, ""]
    rows = [("Library", f"`{LIB_PREFIX}{p}`")]
    folder_index = index_path(board["folder"])
    rows.append(("Board", f"`{e['uid']}` in [{' / '.join(board['folder'])}]({rel(folder_index, page)})"
                 + (f" · {len(shot['tabs'])} tabs rendered" if shot else " · not rendered")))
    if e["shot"] and e["shot"] != e["uid"]:
        rows.append(("Screenshots", f"of `{e['shot']}`, the board that renders this library on the docs Grafana"))
    if e.get("wraps"):
        w = ctx.entries[e["wraps"]]
        rows.append(("Wraps", f"[{w['title']}]({rel(w['page'], page)}) (`{LIB_PREFIX}{w['path']}`): its signals, alerts and rules are part of this board's"))
    if e.get("wrappedBy"):
        rows.append(("Wrapped by", ", ".join(f"[{ctx.entries[q]['title']}]({rel(ctx.entries[q]['page'], page)})" for q in sorted(e["wrappedBy"]))))
    deploys = [b for b in ctx.boards.values() if b.get("deploys") == p]
    if deploys:
        rows.append(("Deployment boards", ", ".join(f"[{b['title']}]({rel(b['page'], page)})" for b in deploys)))
    if collectors:
        rows.append(("Collectors", ", ".join(collector_link(c, ctx, page) for c in collectors)))
    n_alerts = len({a["n"] for a in lib["alerts"]})
    parts = [f"[{len(lib['signals'])} signals](#signals)" if lib["signals"] else "",
             f"[{len(uses)} metrics](#metrics)" if uses else "",
             f"[{n_alerts} alert rules](#alert-rules) with [runbooks](#runbooks)" if lib["alerts"] else "",
             f"[{len(lib['records'])} recording rules](#recording-rules)" if lib["records"] else "",
             "[the board](#board)"]
    rows.append(("Contents", " · ".join(x for x in parts if x)))
    L += table(list(rows[0]), rows[1:])

    if lib["signals"]:
        recorded_by = {r["e"]: r["n"] for r in lib["records"]}
        L += ["## Signals", "", "Each signal: what it shows, the metrics its query reads, its unit, the query the board runs "
              "and the recording rule it produces (if any).", ""]
        rows = []
        for s in lib["signals"]:
            title = s.get("t") or s["n"]
            name = (f"**{cell(title)}**<br>`{s['n']}`" if title != s["n"] else f"`{s['n']}`") + (f"<br>{cell(s['d'])}" if s.get("d") else "")
            mets = code(metrics_of(s["e"])) if s.get("k", "prometheus") == "prometheus" else f"— ({s.get('k')})"
            rec = recorded_by.get(s.get("re"))
            rows.append((name, mets, s["u"] or "—", fence(s["e"]), f"`{rec}`" if rec else "—"))
        L += table(["Signal", "Metrics", "Unit", "Query", "Recorded as"], rows)
    if uses:
        L += ["## Metrics", "", f"Every metric the library reads, the [collector](" + rel("exporters/index.md", page)
              + ") that produces it, and what reads it.", ""]
        rows = []
        for m in sorted(uses):
            u = uses[m]
            src = where(m, ctx, records)
            rows.append((f"`{m}`", src if src and src not in ctx.collectors else collector_link(src, ctx, page),
                         ", ".join(f"`{x}`" for x in sorted(set(u["signals"]))) or "—",
                         ", ".join(f"[{x}](#runbook-{slug(x)})" for x in sorted(set(u["alerts"]))) or "—",
                         ", ".join(f"`{x}`" for x in sorted(set(u["records"]))) or "—"))
        L += table(["Metric", "Collector", "Signals", "Alert rules", "Recording rules"], rows)
    if lib["alerts"]:
        # "Alert rules", not "Alerts": many boards have an Alerts tab of their own
        L += ["## Alert rules", ""]
        rows = []
        for a in lib["alerts"]:
            name = f"`{a['n']}`" + (f"<br>{cell(a.get('s'))}" if a.get("s") else "")
            rb = f"[runbook](#runbook-{slug(a['n'])})" + (f" · [written]({a['u']})" if a.get("u") else "")
            rows.append((name, a["sev"], a["f"], fence(a["e"]), rb))
        L += table(["Alert", "Severity", "For", "Expression", "Runbook"], rows)
    if lib["records"]:
        L += ["## Recording rules", ""] + table(["Record", "Expression"], [(f"`{r['n']}`", fence(r["e"])) for r in lib["records"]])
    if lib["alerts"]:
        L += ["## Runbooks", "", "One per alert rule - the runbook the rule carries, or one generated from it - the text the "
              "board's Runbooks tab shows.", ""]
        seen = set()
        for a in lib["alerts"]:
            if a["n"] not in seen:
                seen.add(a["n"])
                L += runbook_block(a)
    if lib.get("queries"):
        L += ["## Queries", ""] + table(["Query", "Expression"], [(f"`{q['n']}`", fence(q["e"])) for q in lib["queries"]])
    if lib.get("groups") or lib.get("panels"):
        L += ["## Building blocks", ""]
        L += [f"- **{g['t']}**: " + ", ".join(f"`{x}`" for x in g["els"]) for g in lib["groups"]]
        if lib.get("panels"):
            L.append("- **Panels** (`.grafana.panels`): " + ", ".join(f"`{x}`" for x in lib["panels"]))
        L.append("")
    L += ["## Board", ""]
    if shot and shot.get("tabs"):
        L += screenshots(shot, e["title"], page, ctx)
    else:
        note = "The docs Grafana does not run this board, so there is no screenshot of it yet."
        if e.get("wrappedBy"):
            note += " It is rendered as part of " + ", ".join(
                f"[{ctx.entries[q]['title']}]({rel(ctx.entries[q]['page'], page)})" for q in sorted(e["wrappedBy"])) + "."
        L += ['!!! note "Not rendered"', "    " + note, ""]
    return "\n".join(L)


def board_page(b, ctx):
    """A board no library owns: analysis, chart types, deployment targets, base."""
    page = b["page"]
    shot = ctx.manifest["boards"].get(b["shot"])
    L = [f"# {b['title']}", ""]
    if b.get("description"):
        L += [b["description"], ""]
    rows = [("Board uid", f"`{b['uid']}`"), ("Grafana folder", f"[{' / '.join(b['folder'])}]({rel(index_path(b['folder']), page)})")]
    if b.get("deploys"):
        e = ctx.entries[b["deploys"]]
        rows.append(("Library", f"[{e['title']}]({rel(e['page'], page)}) (`{LIB_PREFIX}{e['path']}`): its signals, alerts and runbooks"))
    L += table(list(rows[0]), rows[1:])
    if shot and shot.get("tabs"):
        L += screenshots(shot, b["title"], page, ctx, heading="##")
    else:
        L += ['!!! note "Not rendered"', "    The docs Grafana does not run this board, so there is no screenshot of it yet.", ""]
    return "\n".join(L)


def tree_of(boards):
    """folder tuple -> {'boards': [...], 'subs': set()}"""
    tree = {}
    for b in boards.values():
        f = tuple(b["folder"])
        for i in range(1, len(f) + 1):
            node = tree.setdefault(f[:i], {"boards": [], "subs": set()})
            if i < len(f):
                node["subs"].add(f[:i + 1])
        tree[f]["boards"].append(b)
    return tree


def index_path(folder):
    return os.path.join("boards", *[slug(f) for f in folder], "index.md")


def count(tree, folder):
    return sum(len(v["boards"]) for k, v in tree.items() if k[:len(folder)] == folder)


def folder_page(folder, node, tree, ctx):
    path = index_path(folder)
    L = [f"# {folder[-1]}", "", f"Grafana folder **{' / '.join(folder)}**: every board in it, with the library it documents.", ""]
    if node["subs"]:
        L += table(["Folder", "Boards"], [(f"[{s[-1]}]({rel(index_path(s), path)})", count(tree, s)) for s in sorted(node["subs"])])
    if node["boards"]:
        rows = []
        for b in sorted(node["boards"], key=lambda x: x["navTitle"].lower()):
            shot = ctx.manifest["boards"].get(b.get("shot"))
            lib = ctx.entries.get(b.get("lib") or b.get("deploys") or "")
            alerts = len({a["n"] for a in lib["lib"]["alerts"]}) if lib and b.get("lib") else "—"
            rows.append((f"[{b['navTitle']}]({rel(b['page'], path)})",
                         f"[`{lib['path']}`]({rel(lib['page'], path)})" if lib else "—",
                         len(shot["tabs"]) if shot else "not rendered", alerts))
        L += table(["Board", "Library", "Tabs", "Alert rules"], rows)
    return path, "\n".join(L)


def nav_for(folder, tree):
    """The board tree's navigation: folder pages, and the boards no library owns."""
    node = tree[folder]
    items = [index_path(folder)]
    items += [{s[-1]: nav_for(s, tree)} for s in sorted(node["subs"])]
    items += [{b["navTitle"]: b["page"]} for b in sorted(node["boards"], key=lambda x: x["navTitle"].lower()) if not b.get("lib")]
    return items


def lib_counts(e, ctx):
    lib = e["lib"]
    shot = ctx.manifest["boards"].get(e["shot"]) if e["shot"] else None
    return (len(lib["signals"]), len(lib_metrics(lib)), len({a["n"] for a in lib["alerts"]}), len(lib["records"]),
            f"{len(shot['tabs'])} tabs" if shot else "not rendered")


def libs_by_ns(ctx):
    groups = {}
    for p, e in ctx.entries.items():
        groups.setdefault(namespace(p), []).append(e)
    return [(ns, sorted(groups[ns], key=lambda x: x["title"].lower())) for ns in sorted(groups, key=ns_order)]


def lib_rows(entries, page, ctx):
    return [(f"[{e['title']}]({rel(e['page'], page)})<br>`{e['path']}`",) + lib_counts(e, ctx) for e in entries]


LIB_HEADER = ["Library", "Signals", "Metrics", "Alert rules", "Recording rules", "Board"]


def method_rows(ctx, page, tree):
    """The method libraries: documented by their Analysis boards."""
    rows = []
    for p, lib in sorted(ctx.data["libs"].items()):
        if not method(p):
            continue
        folder = next((f for f in tree if len(f) == 2 and f[0] == "Analysis" and slug(f[1]) == slug(lib["title"].split()[0])), ("Analysis",))
        rows.append((f"[{lib['title']}]({rel(index_path(folder), page)})<br>`{p}`", len(lib["signals"]), len(lib_metrics(lib)),
                     len({a["n"] for a in lib["alerts"]}), len(lib["records"]), f"{count(tree, folder)} boards"))
    return rows


def overview(ctx, tree, site):
    """docs/.gen/overview.md: totals, every library by namespace, the board folders (paths relative to docs/index.md)."""
    libs = ctx.data["libs"]
    every = [lib for p, lib in libs.items() if p != "service"]
    metrics = set()
    for lib in every:
        metrics |= set(lib_metrics(lib))
    rendered = sum(1 for b in ctx.boards.values() if b.get("shot") in ctx.manifest["boards"])
    exporters = {c["exporter"] for c in ctx.collectors.values()}
    L = [f"**{len(every)}** observ-libs · **{len(ctx.boards)}** boards ({rendered} rendered) · "
         f"**{sum(len(x['signals']) for x in every)}** signals · **{len(metrics)}** metrics · "
         f"**{sum(len(x['alerts']) for x in every)}** alert rules with runbooks · **{sum(len(x['records']) for x in every)}** recording rules · "
         f"**{len(ctx.collectors)}** collectors in {len(exporters)} exporters", "",
         "## observ-libs", "",
         f"Every library {site} ships under `{LIB_PREFIX.rstrip('.')}`, by namespace. A library's page has its signals (what each shows "
         "and the metrics behind it), the collectors those metrics come from, its alert rules with their runbooks, its "
         "recording rules, and its board with every tab rendered.", ""]
    for ns, entries in libs_by_ns(ctx):
        L += [f"### {ns_title(ns)}", ""] + table(LIB_HEADER, lib_rows(entries, "index.md", ctx))
    rows = method_rows(ctx, "index.md", tree)
    if rows:
        L += ["### Analysis", "", "The method libraries, documented by their boards (Boards / Analysis).", ""] + table(LIB_HEADER, rows)
    L += ["## Boards", "", "Every board in the Grafana folder it is filed in - see [Boards](boards/index.md).", ""]
    L += table(["Folder", "Boards"], [(f"[{s}](boards/{slug(s)}/index.md)", count(tree, (s,))) for s in SECTIONS if (s,) in tree])
    L += ["## Collectors", "", "Where the metrics come from: [the exporters and their collectors](exporters/index.md), "
          "and [which collector supplies each signal](exporters/signals.md).", ""]
    return "\n".join(L)


def redirects(ctx, real):
    """The former pages: the observ-libs reference, the old Guide page, Dashboards,
    Visualizations, and the library boards' pages in the board tree."""
    out = {"dashboards/index.md": "boards/index.md", "visualizations/index.md": "boards/reference/panels/index.md",
           "libs.md": f"{LIBS_DIR}/index.md"}
    for b in ctx.boards.values():
        out[f"dashboards/{b['uid']}.md"] = b["page"]
        out[b["boardPage"]] = b["page"]
        if b["folder"][-1] == "Panels":
            out[f"visualizations/{b['uid']}.md"] = b["page"]
    for p, e in ctx.entries.items():
        out[f"observ-libs/{p.replace('.', '-')}.md"] = e["page"]
        for a in e["aliases"]:
            out[f"dashboards/{a}.md"] = e["page"]
    return {k: v for k, v in sorted(out.items()) if k != v and k not in real}


def manifests():
    """<docs>/shots/manifest.json, or one per Grafana in <docs>/shots/<name>/:
    every rendered board, with the Grafana it came from and its tab files
    relative to <docs>/shots. The first Grafana that has a board wins."""
    paths = sorted(glob.glob(os.path.join(SHOTS, "manifest.json")) + glob.glob(os.path.join(SHOTS, "*", "manifest.json")))
    merged = {"boards": {}}
    for path in paths:
        m = json.load(open(path))
        sub = os.path.relpath(os.path.dirname(path), SHOTS)
        for k in ("grafana", "rendered", "logsMasked"):
            merged.setdefault(k, m.get(k))
        for b in m.get("boards", []):
            if not b.get("tabs") or b["uid"] in merged["boards"]:
                continue
            tabs = [dict(t, file=t["file"] if sub == "." else sub + "/" + t["file"]) for t in b["tabs"]]
            merged["boards"][b["uid"]] = dict(b, tabs=tabs, grafana=m.get("grafana", ""), rendered=m.get("rendered", ""),
                                              logsMasked=m.get("logsMasked", False))
    return merged


def write(rel_path, text):
    path = os.path.join(DOCS, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(text + "\n")


def main():
    global DOCS, SHOTS, LIB_PREFIX
    ap = argparse.ArgumentParser()
    ap.add_argument("--docs", default=DOCS, help="the docs folder: boards.json in, observ-libs/, boards/ and shots/ under it")
    ap.add_argument("--mkdocs", default=os.path.join(ROOT, "mkdocs.yml"), help="the mkdocs.yml the generated one inherits")
    ap.add_argument("--site", default="observ-viz", help="what the overview pages call the libraries' source")
    ap.add_argument("--lib-prefix", default=LIB_PREFIX, help="how a page writes a library path (observ-viz: g.libs.)")
    a = ap.parse_args()
    LIB_PREFIX = a.lib_prefix
    DOCS = os.path.abspath(a.docs)
    SHOTS = os.path.join(DOCS, "shots")
    data = json.load(open(os.path.join(DOCS, "boards.json")))
    manifest = manifests()
    entries, boards, aliases = collect(data, manifest["boards"])
    ctx = Ctx(data, manifest, entries, boards, compile_collectors(data.get("collectors", {})))
    for d in (LIBS_DIR, "boards", ".gen"):
        shutil.rmtree(os.path.join(DOCS, d), ignore_errors=True)
    for e in entries.values():
        write(e["page"], library_page(e, ctx))
    groups = libs_by_ns(ctx)
    for ns, ns_entries in groups:
        page = os.path.join(LIBS_DIR, ns, "index.md")
        write(page, "\n".join([f"# {ns_title(ns)}", "", f"The {ns_title(ns)} libraries.", ""] + table(LIB_HEADER, lib_rows(ns_entries, page, ctx))))
    tree = tree_of(boards)
    lib_index = os.path.join(LIBS_DIR, "index.md")
    L = ["# observ-libs", "", f"Every library {a.site} ships, by namespace - the same list as on the [home page]({rel('index.md', lib_index)}).", ""]
    L += table(["Namespace", "Libraries", "Signals", "Alert rules"],
               [(f"[{ns_title(ns)}]({ns}/index.md)", len(es), sum(len(e["lib"]["signals"]) for e in es),
                 sum(len({x["n"] for x in e["lib"]["alerts"]}) for e in es)) for ns, es in groups])
    write(lib_index, "\n".join(L))
    for b in boards.values():
        if not b.get("lib"):
            write(b["page"], board_page(b, ctx))
    for folder, node in tree.items():
        path, text = folder_page(folder, node, tree, ctx)
        write(path, text)
    top = [s for s in SECTIONS if (s,) in tree]
    write(os.path.join("boards", "index.md"), "\n".join(
        ["# Boards", "", f"Every board {a.site} ships, filed in the same folders as in Grafana. A library's board is documented on the "
         "library's page (signals, metrics, alert rules, runbooks, every tab rendered); the boards no library owns - the "
         "analysis methods, chart types, deployment targets and base boards - have pages of their own.", ""]
        + table(["Folder", "Boards"], [(f"[{s}]({slug(s)}/index.md)", count(tree, (s,))) for s in top])))
    write(os.path.join(".gen", "overview.md"), overview(ctx, tree, a.site))
    # only `nav` is read; a !!python/name tag (a superfences custom fence) is left alone
    loader = type("Loader", (yaml.SafeLoader,), {})
    loader.add_multi_constructor("tag:yaml.org,2002:python/", lambda *_: None)
    base = yaml.load(open(a.mkdocs), Loader=loader)
    libs_nav = {"observ-libs": [lib_index] + [{ns_title(ns): [os.path.join(LIBS_DIR, ns, "index.md")] + [{e["title"]: e["page"]} for e in es]}
                                               for ns, es in groups]}
    boards_nav = {"Boards": [os.path.join("boards", "index.md")] + [{s: nav_for((s,), tree)} for s in top]}
    nav = list(base["nav"])
    at = next((i + 1 for i, item in enumerate(nav) if isinstance(item, dict) and "Guide" in item), len(nav))
    nav = nav[:at] + [libs_nav] + nav[at:] + [boards_nav]
    real = {os.path.relpath(f, DOCS).replace(os.sep, "/") for f in glob.glob(os.path.join(DOCS, "**", "*.md"), recursive=True)}
    gen = {
        "INHERIT": os.path.basename(a.mkdocs),
        "nav": nav,
        "plugins": ["search", {"redirects": {"redirect_maps": redirects(ctx, real)}}],
    }
    with open(os.path.join(os.path.dirname(os.path.abspath(a.mkdocs)), "mkdocs.gen.yml"), "w") as fh:
        fh.write("# generated by scripts/gen-board-pages.py - do not edit\n")
        yaml.safe_dump(gen, fh, sort_keys=False, allow_unicode=True)
    rendered = sum(1 for b in boards.values() if b.get("shot") in manifest["boards"])
    print(f"{len(entries)} library pages in {len(groups)} namespaces, {len(boards)} boards ({rendered} rendered, "
          f"{sum(1 for b in boards.values() if not b.get('lib'))} with pages of their own) in {len(tree)} folders "
          f"-> docs/{LIBS_DIR}/, docs/boards/, docs/.gen/overview.md, mkdocs.gen.yml")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
