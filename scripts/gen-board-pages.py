#!/usr/bin/env python3
"""Build the docs board tree: one page per board, filed like the Grafana
folders, with every tab rendered and the board's alerts, recording rules and
signals on the same page.

Inputs:
  docs/boards.json            libraries and mixin boards (scripts/gen-lib-doc.py)
  docs/shots/manifest.json    the screenshots (docs-shots branch, scripts/shots.py);
                              optional - without it every board gets a placeholder
Outputs (gitignored, written at docs build time):
  docs/boards/<folder>/.../<uid>.md   one page per board
  docs/boards/<folder>/.../index.md   a page per folder listing its boards
  docs/boards/index.md                every folder at a glance
  mkdocs.gen.yml                      mkdocs.yml + the board navigation + redirects
                                      from the former observ-libs / dashboards /
                                      visualizations pages
Build with `mkdocs build -f mkdocs.gen.yml` (see `just docs`).

Another repository (observ-libs) builds its own tree with the same script:
--docs its docs folder (boards.json in it), --mkdocs its mkdocs.yml (the
generated file lands next to it), --site its name for the overview page,
--lib-prefix how its library paths read. Shots
of several Grafanas sit in <docs>/shots/<name>/, each with its manifest.json.

One page per board:
- a library's page is its own board (uid from the library), filed in the
  library's folder; when that board is not rendered but another uid renders the
  library (the reference runtime / framework boards, a site's scenario
  instance), the page shows that board's screenshots
- a component pack a service board wraps (monitoring.mimir inside
  services.mimir) is documented on the service's page, unless the component's
  own board is the rendered one
- mixin boards (analysis, chart types, deployment targets, base) get their own
  pages; a deployment-target board links to its library's page
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
BOARDS = os.path.join(DOCS, "boards")
SHOTS = os.path.join(DOCS, "shots")
LIB_PREFIX = "g.libs."
# top-level sections, in this order; a board in any other root folder becomes a workload
SECTIONS = ["Analysis", "Platform", "Workloads", "Components", "Reference", "Base"]
RUNTIMES = ["Reference", "Runtimes"]
FALLBACK_FOLDER = ["Components", "Common"]
# component packs whose page folds into the service board that wraps them
FOLDABLE = ("monitoring.", "collector.", "cicd.")
# deployment-target boards instantiate a library under another uid: their page
# links to the library's page instead of repeating its alerts
DEPLOY = {
    "observ-viz-deploy-kube-pod": "kubernetes.pod",
    "observ-viz-deploy-cadvisor": "kubernetes.cadvisor",
}


def skipped(path):
    """The method libraries are documented by their boards (Analysis / <method>);
    the composer needs a whitebox to build anything."""
    return path.startswith("analysis.") or path == "service"


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-") or "board"


def fence(e):
    return "`" + e.replace("\n", " ").replace("|", "\\|") + "`" if e else "—"


def cell(s):
    return (s or "").replace("\n", " ").replace("|", "\\|")


def rel(target, page):
    return os.path.relpath(target, os.path.dirname(page)).replace(os.sep, "/")


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


def collect(data, shots):
    """uid -> page entry; plus folded uid -> uid of the page that documents it."""
    libs, mix = data["libs"], data["boards"]
    aliases = {}
    for uid in sorted(set(mix) | set(shots)):
        p = lib_alias(uid, libs)
        if p:
            aliases.setdefault(p, []).append(uid)
    alias_uids = {u for us in aliases.values() for u in us}
    boards = {}
    for uid, b in mix.items():
        if uid in alias_uids:
            continue  # documented on its library's page
        folder = ["Base"] if b.get("source") == "base" else b["folder"]
        boards[uid] = {"uid": uid, "shot": uid, "title": b["title"], "folder": folder,
                       "description": b.get("description", "")}
    for p, lib in sorted(libs.items()):
        if skipped(p):
            continue
        uid = lib["uid"]
        shot = uid if uid in shots else next((a for a in aliases.get(p, []) if a in shots), uid)
        alias_folder = next((mix[a]["folder"] for a in aliases.get(p, []) if a in mix), None)
        if uid not in boards:
            boards[uid] = {"uid": uid, "shot": shot, "title": lib["title"],
                           "folder": lib_folder(p, lib, alias_folder), "description": ""}
        b = boards[uid]
        b.update(lib=p, owner=True)
        if b["shot"] not in shots:
            b["shot"] = shot
        b["description"] = b["description"] or lib.get("description", "")
    # a service board's own component pack is documented on the service's page
    uid_lib = {lib["uid"]: p for p, lib in libs.items()}
    folded = {}
    for p, lib in sorted(libs.items()):
        w = uid_lib.get(lib.get("whitebox") or "")
        if not w or not w.startswith(FOLDABLE) or skipped(p):
            continue
        wb, sb = boards.get(libs[w]["uid"]), boards.get(lib["uid"])
        if not wb or not sb or wb["uid"] in folded or wb["shot"] in shots:
            continue
        wrappers = sorted(q for q, l in libs.items() if l.get("whitebox") == lib["whitebox"] and not skipped(q))
        target = (next((q for q in wrappers if boards[libs[q]["uid"]]["shot"] in shots), None)
                  or next((q for q in wrappers if q.split(".")[-1] == w.split(".")[-1]), wrappers[0]))
        if target == p:
            folded[wb["uid"]] = sb["uid"]
            sb.setdefault("builtOn", []).append(w)
    for uid in folded:
        boards[uid]["folded"] = True
    for uid, p in DEPLOY.items():
        if uid in boards and p in libs:
            boards[uid].setdefault("lib", p)
    # rendered boards nothing above knows (a site's own scenario boards)
    for uid, s in shots.items():
        if uid not in boards and uid not in alias_uids:
            boards[uid] = {"uid": uid, "shot": uid, "title": s["title"],
                           "folder": s.get("folderPath") or [s.get("folder") or "Other"], "description": s.get("description", "")}
    for b in boards.values():
        if not b.get("description") and b["shot"] in shots:
            b["description"] = shots[b["shot"]].get("description", "")
        if not b["folder"]:
            b["folder"] = FALLBACK_FOLDER
        elif b["folder"][0] not in SECTIONS:
            b["folder"] = ["Workloads"] + list(b["folder"])
        b["dir"] = os.path.join("boards", *[slug(f) for f in b["folder"]])
        b["page"] = os.path.join(b["dir"], b["uid"] + ".md")
    pages = {u: b for u, b in boards.items() if not b.get("folded")}
    # a service board next to the component board it wraps (or next to a board
    # of the same title) says it is the service one
    for b in pages.values():
        b["navTitle"] = short_title(b["title"], b["folder"])
    seen = {}
    for b in pages.values():
        seen.setdefault((tuple(b["folder"]), b["navTitle"]), []).append(b)
    for b in pages.values():
        if not (b.get("lib") or "").startswith("services."):
            continue
        component = pages.get(libs[b["lib"]].get("whitebox") or "")
        if len(seen[(tuple(b["folder"]), b["navTitle"])]) > 1 or (component and component["folder"] == b["folder"]):
            b["navTitle"] += " (service)"
    return pages, {u: boards[t]["page"] for u, t in folded.items()}, aliases


def short_title(title, folder):
    """'RED / Kubernetes API server' under Analysis / RED reads 'Kubernetes API server'."""
    for f in reversed(folder):
        for sep in (" / ", ": "):
            if title.lower().startswith(f.lower() + sep):
                return title[len(f) + len(sep):]
    return title


def board_page(b, pages, libs, manifest):
    page = b["page"]
    shot = manifest["boards"].get(b["shot"])
    lib = libs.get(b["lib"]) if b.get("lib") else None
    L = [f"# {b['title']}", ""]
    if b.get("description"):
        L += [b["description"], ""]
    rows = []
    if b.get("lib"):
        rows.append(("Library", f"`{LIB_PREFIX}{b['lib']}`"))
    for w in b.get("builtOn", []):
        rows.append(("Built on", f"`{LIB_PREFIX}{w}` (its signals, alerts and rules are part of this board's)"))
    rows += [("Board uid", f"`{b['uid']}`"), ("Grafana folder", " / ".join(b["folder"]))]
    if shot and b["shot"] != b["uid"]:
        rows.append(("Screenshots", f"of `{b['shot']}`, the board that renders this library on the docs Grafana"))
    if b.get("lib") and not b.get("owner"):
        owner = next((o for o in pages.values() if o.get("lib") == b["lib"] and o.get("owner")), None)
        if owner:
            rows.append(("Alerts, rules, signals", f"on the library's own board: [{owner['title']}]({rel(owner['page'], page)})"))
    # the first row is the table header (a markdown table needs one)
    L += [f"| {rows[0][0]} | {rows[0][1]} |", "|---|---|"] + [f"| {k} | {v} |" for k, v in rows[1:]] + [""]
    if shot and shot.get("tabs"):
        masked = "; log lines are masked" if shot.get("logsMasked", manifest.get("logsMasked")) else ""
        L += [f"*Rendered from {shot.get('grafana', manifest.get('grafana', ''))} on {shot.get('rendered', manifest.get('rendered', ''))}: each tab as that Grafana "
              f"draws it with its own data, so a panel without data there shows \"No data\"{masked}.*", ""]
        for t in shot["tabs"]:
            if len(shot["tabs"]) > 1:
                L += [f"## {t['title']}", ""]
            if t.get("loading"):
                L += ["*Some queries were still running when this was captured, so a panel may be empty.*", ""]
            L += [f"![{b['title']} - {t['title']}]({rel(os.path.join('shots', t['file']), page)})", ""]
    else:
        L += ['!!! note "Not rendered"', "    The docs Grafana does not run this board, so there is no screenshot of it yet.", ""]
    if lib and b.get("owner"):
        if lib["alerts"]:
            # "Alert rules", not "Alerts": many boards have an Alerts tab of their own
            L += ["## Alert rules", "", "| Alert | Severity | For | Expression |", "|-------|----------|-----|------------|"]
            for a in lib["alerts"]:
                name = f"`{a['n']}`" + (f"<br>{cell(a.get('s'))}" if a.get("s") else "")
                L.append(f"| {name} | {a['sev']} | {a['f']} | {fence(a['e'])} |")
            L.append("")
        if lib["records"]:
            L += ["## Recording rules", "", "| Record | Expression |", "|--------|------------|"]
            L += [f"| `{r['n']}` | {fence(r['e'])} |" for r in lib["records"]] + [""]
        if lib["signals"]:
            recorded_by = {r["e"]: r["n"] for r in lib["records"]}
            L += ["## Signals", "", "Each signal's query and the recording rule it produces (if any).", "",
                  "| Signal | Unit | Query | Recorded as |", "|--------|------|-------|-------------|"]
            for s in lib["signals"]:
                rec = recorded_by.get(s.get("re"))
                L.append(f"| `{s['n']}` | {s['u'] or '—'} | {fence(s['e'])} | {('`' + rec + '`') if rec else '—'} |")
            L.append("")
        if lib["queries"]:
            L += ["## Queries", "", "| Query | Expression |", "|-------|------------|"]
            L += [f"| `{q['n']}` | {fence(q['e'])} |" for q in lib["queries"]] + [""]
        if lib["groups"] or lib["panels"]:
            L += ["## Building blocks", ""]
            L += [f"- **{g['t']}**: " + ", ".join(f"`{e}`" for e in g["els"]) for g in lib["groups"]]
            if lib["panels"]:
                L.append("- **Panels** (`.grafana.panels`): " + ", ".join(f"`{e}`" for e in lib["panels"]))
            L.append("")
    return "\n".join(L)


def tree_of(pages):
    """folder tuple -> {'boards': [...], 'subs': set()}"""
    tree = {}
    for b in pages.values():
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


def index_page(folder, node, tree, libs, manifest):
    path = index_path(folder)
    L = [f"# {folder[-1]}", "", f"Grafana folder **{' / '.join(folder)}**.", ""]
    if node["subs"]:
        L += ["| Folder | Boards |", "|--------|--------|"]
        L += [f"| [{s[-1]}]({rel(index_path(s), path)}) | {count(tree, s)} |" for s in sorted(node["subs"])] + [""]
    if node["boards"]:
        L += ["| Board | Library | Tabs | Alerts |", "|-------|---------|------|--------|"]
        for b in sorted(node["boards"], key=lambda x: x["navTitle"].lower()):
            shot = manifest["boards"].get(b["shot"])
            tabs = len(shot["tabs"]) if shot else "not rendered"
            alerts = len(libs[b["lib"]]["alerts"]) if b.get("owner") and b.get("lib") in libs else "—"
            lib = f"`{b['lib']}`" if b.get("lib") else "—"
            L.append(f"| [{b['navTitle']}]({rel(b['page'], path)}) | {lib} | {tabs} | {alerts} |")
        L.append("")
    return path, "\n".join(L)


def nav_for(folder, tree):
    node = tree[folder]
    items = [index_path(folder)]
    items += [{s[-1]: nav_for(s, tree)} for s in sorted(node["subs"])]
    items += [{b["navTitle"]: b["page"]} for b in sorted(node["boards"], key=lambda x: x["navTitle"].lower())]
    return items


def redirects(pages, folded, aliases, libs):
    """The former observ-libs reference, Dashboards and Visualizations pages."""
    out = {"observ-libs/index.md": "boards/index.md", "dashboards/index.md": "boards/index.md",
           "visualizations/index.md": "boards/reference/panels/index.md"}
    by_lib = {b["lib"]: b["page"] for b in pages.values() if b.get("owner")}
    for b in pages.values():
        out[f"dashboards/{b['uid']}.md"] = b["page"]
        if b["folder"][-1] == "Panels":
            out[f"visualizations/{b['uid']}.md"] = b["page"]
    for p, page in by_lib.items():
        out[f"observ-libs/{p.replace('.', '-')}.md"] = page
        for a in aliases.get(p, []):
            out[f"dashboards/{a}.md"] = page
    for uid, page in folded.items():
        out[f"dashboards/{uid}.md"] = page
        p = next((q for q, l in libs.items() if l["uid"] == uid), None)
        if p:
            out[f"observ-libs/{p.replace('.', '-')}.md"] = page
    return out


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


def main():
    global DOCS, BOARDS, SHOTS, LIB_PREFIX
    ap = argparse.ArgumentParser()
    ap.add_argument("--docs", default=DOCS, help="the docs folder: boards.json in, boards/ and shots/ under it")
    ap.add_argument("--mkdocs", default=os.path.join(ROOT, "mkdocs.yml"), help="the mkdocs.yml the generated one inherits")
    ap.add_argument("--site", default="observ-viz", help="what the overview page calls the boards' source")
    ap.add_argument("--lib-prefix", default=LIB_PREFIX, help="how a page writes a library path (observ-viz: g.libs.)")
    a = ap.parse_args()
    LIB_PREFIX = a.lib_prefix
    DOCS = os.path.abspath(a.docs)
    BOARDS, SHOTS = os.path.join(DOCS, "boards"), os.path.join(DOCS, "shots")
    data = json.load(open(os.path.join(DOCS, "boards.json")))
    manifest = manifests()
    pages, folded, aliases = collect(data, manifest["boards"])
    shutil.rmtree(BOARDS, ignore_errors=True)
    for b in pages.values():
        os.makedirs(os.path.join(DOCS, b["dir"]), exist_ok=True)
        with open(os.path.join(DOCS, b["page"]), "w") as fh:
            fh.write(board_page(b, pages, data["libs"], manifest) + "\n")
    tree = tree_of(pages)
    for folder, node in tree.items():
        path, text = index_page(folder, node, tree, data["libs"], manifest)
        with open(os.path.join(DOCS, path), "w") as fh:
            fh.write(text + "\n")
    top = [s for s in SECTIONS if (s,) in tree]
    overview = ["# Boards", "",
                f"Every board {a.site} ships, filed in the same folders as in Grafana. Each page shows every tab of the "
                "board as the docs Grafana draws it, then the alerts, recording rules and signals of the library behind it.",
                "", "| Folder | Boards |", "|--------|--------|"]
    overview += [f"| [{s}]({slug(s)}/index.md) | {count(tree, (s,))} |" for s in top]
    with open(os.path.join(BOARDS, "index.md"), "w") as fh:
        fh.write("\n".join(overview) + "\n")
    # only `nav` is read; a !!python/name tag (a superfences custom fence) is left alone
    loader = type("Loader", (yaml.SafeLoader,), {})
    loader.add_multi_constructor("tag:yaml.org,2002:python/", lambda *_: None)
    base = yaml.load(open(a.mkdocs), Loader=loader)
    gen = {
        "INHERIT": os.path.basename(a.mkdocs),
        "nav": base["nav"] + [{s: nav_for((s,), tree)} for s in top],
        "plugins": ["search", {"redirects": {"redirect_maps": redirects(pages, folded, aliases, data["libs"])}}],
    }
    with open(os.path.join(os.path.dirname(os.path.abspath(a.mkdocs)), "mkdocs.gen.yml"), "w") as fh:
        fh.write("# generated by scripts/gen-board-pages.py - do not edit\n")
        yaml.safe_dump(gen, fh, sort_keys=False, allow_unicode=True)
    rendered = sum(1 for b in pages.values() if b["shot"] in manifest["boards"])
    print(f"{len(pages)} board pages ({rendered} rendered, {len(folded)} components folded into their service) "
          f"in {len(tree)} folders -> docs/boards/, mkdocs.gen.yml")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
