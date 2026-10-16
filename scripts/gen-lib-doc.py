#!/usr/bin/env python3
"""Generate docs/boards.json: every board observ-viz ships, the Grafana folder
it is filed in, and the library behind it with its signals, alerts and
recording rules.

  gen-lib-doc.py

- libs:   every observ-lib under g.libs (found by walking the index, not a
          hand-kept list): title, board uid, folder, description, signals (or
          panel queries), dashboard groups/panels, alerts and recording rules.
- boards: the boards the reference and base mixins render (analysis, chart
          types, runtimes, deployment targets, common, base), with their folder.

The docs build (scripts/gen-board-pages.py) turns this, plus the screenshots
from the docs-shots branch, into one page per board in a navigation tree that
mirrors the Grafana folders. Run it after changing a library (a few minutes:
every board is evaluated) and commit docs/boards.json.
"""
import json
import os
import sys

import _jsonnet

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "boards.json")


def ev(snip):
    return json.loads(_jsonnet.evaluate_snippet("t", snip, jpathdir=[ROOT]))


# the folder chain (titles, root first) a board resource carries in its annotations
FOLDER = """
local folder(res) =
  local a = std.get(std.get(res, 'metadata', {}), 'annotations', {});
  if std.objectHas(a, 'observ-viz.dev/folder-path') then [f.title for f in std.parseJson(a['observ-viz.dev/folder-path'])]
  else (if std.objectHas(a, 'observ-viz.dev/folder-parent-title') then [a['observ-viz.dev/folder-parent-title']] else [])
       + (if std.objectHas(a, 'observ-viz.dev/folder-title') then [a['observ-viz.dev/folder-title']] else []);
"""


def lib_paths():
    return ev("""local libs = (import 'g.libsonnet').libs;
local walk(o, p) = std.flattenArrays([
  local v = o[k];
  if std.isObject(v) then (if std.objectHasAll(v, 'new') && std.isFunction(v.new) then [p + k] else walk(v, p + k + '.')) else []
  for k in std.objectFields(o)
]);
walk(libs, '')""")


def lib_data(p):
    return ev(FOLDER + f"""
local l = (import 'g.libsonnet').libs.{p}.new({{}});
local sig(k) = l.signals[k];
local res = l.grafana.dashboard;
local ann(r, k) = std.get(std.get(r, 'annotations', {{}}), k, '');
{{
  title: l.config.dashboardTitle,
  uid: l.config.uid,
  folder: folder(res),
  description: std.get(res.spec, 'description', ''),
  // a service board's whitebox: the component pack it wraps
  whitebox: if std.objectHas(l, 'whitebox') then std.get(l.whitebox.config, 'uid', '') else '',
  signals: if !std.objectHas(l, 'signals') then [] else [{{
    n: k,
    u: (local d = sig(k).asTimeSeries('x').spec.vizConfig.spec.fieldConfig.defaults; std.get(d, 'unit', '')),
    e: sig(k).asTarget().spec.query.spec.expr,
    re: sig(k).asRecordingRule('_', '', '5m').expr,
  }} for k in std.objectFields(l.signals)],
  // libs without signals (logs) expose their panel queries instead
  queries: if std.objectHas(l, 'signals') || !std.objectHas(l, 'queries') then [] else
    [{{ n: k, e: std.get(std.get(std.get(std.get(l.queries[k], 'spec', {{}}), 'query', {{}}), 'spec', {{}}), 'expr', '') }} for k in std.objectFields(l.queries)],
  groups: [{{ t: g.title, els: std.objectFields(g.elements) }} for g in std.get(l.grafana, 'groups', [])],
  panels: if std.objectHas(l.grafana, 'groups') || !std.objectHas(l.grafana, 'panels') then [] else std.objectFields(l.grafana.panels),
  alerts: [{{ n: r.alert, sev: std.get(r.labels, 'severity', ''), f: r['for'], e: r.expr,
             s: ann(r, 'summary'), d: ann(r, 'description') }}
           for grp in (if std.objectHas(l, 'prometheus') then l.prometheus.alerts else []) for r in grp.rules],
  records: [{{ n: r.record, e: r.expr }}
            for grp in (if std.objectHas(l, 'prometheus') then std.get(l.prometheus, 'rules', []) else []) for r in grp.rules],
}}""")


def mixin_boards():
    """The boards the reference and base mixins render: uid -> title, folder, description."""
    return ev(FOLDER + """
local ref = (import 'libs/reference-lib/mixin.libsonnet').grafanaDashboards;
local base = import 'libs/common-lib/base.libsonnet';
local baseBoards = base.home.new({}).grafana.dashboards + base.cluster.new({}).grafana.dashboards + base.clusterDetail.new({}).grafana.dashboards;
local entry(res, src) = { uid: res.metadata.name, title: res.spec.title, folder: folder(res), description: std.get(res.spec, 'description', ''), source: src };
[entry(ref[k], 'reference') for k in std.objectFields(ref)]
+ [entry(if std.objectHas(baseBoards[k], 'toResource') then baseBoards[k].toResource() else baseBoards[k], 'base') for k in std.objectFields(baseBoards)]""")


def main():
    data = {"libs": {}, "boards": {}, "errors": {}}
    paths = lib_paths()
    for p in paths:
        try:
            data["libs"][p] = lib_data(p)
        except Exception as exc:  # noqa: BLE001 - a lib that needs config (the composer) is skipped
            data["errors"][p] = str(exc).splitlines()[0][:200]
            print(f"  SKIP {p}: {data['errors'][p]}")
    for b in mixin_boards():
        data["boards"][b["uid"]] = {k: v for k, v in b.items() if k != "uid"}
    with open(OUT, "w") as fh:
        json.dump(data, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"wrote {len(data['libs'])} libraries ({len(data['errors'])} skipped) + {len(data['boards'])} mixin boards to docs/boards.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
