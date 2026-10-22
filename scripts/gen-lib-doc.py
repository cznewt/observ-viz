#!/usr/bin/env python3
"""Generate docs/boards.json: every library and board observ-viz ships, the
Grafana folder each board is filed in, the libraries' signals, alerts with
their runbooks and recording rules, and the collectors behind the metrics.

  gen-lib-doc.py

- libs:   every observ-lib under g.libs (found by walking the index, not a
          hand-kept list): title, board uid, folder, description, signals (or
          panel queries) with their title and description, dashboard
          groups/panels, alerts with their runbooks, and recording rules.
- boards: the boards the reference and base mixins render (analysis, chart
          types, runtimes, deployment targets, common, base), with their folder.
- collectors: the exporter / collector registry (libs/common-lib/exporters.libsonnet)
          with the metric patterns each collector produces.

The docs build (scripts/gen-board-pages.py) turns this, plus the screenshots
from the docs-shots branch, into one page per library and a board tree that
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
local runbook = import 'libs/common-lib/alert/runbook.libsonnet';
local sig(k) = l.signals[k];
local hidden(o, f, d) = if std.objectHasAll(o, f) then o[f] else d;
local res = l.grafana.dashboard;
local ann(r, k) = std.get(std.get(r, 'annotations', {{}}), k, '');
{{
  title: l.config.dashboardTitle,
  uid: l.config.uid,
  folder: folder(res),
  description: std.get(res.spec, 'description', ''),
  // a service board's whitebox: the component pack it wraps
  whitebox: if std.objectHas(l, 'whitebox') then std.get(l.whitebox.config, 'uid', '') else '',
  // n key, t title, d description, k datasource kind (prometheus / loki / ...),
  // u unit, e the board's query, re the recording-rule form
  signals: if !std.objectHas(l, 'signals') then [] else [{{
    n: k,
    t: hidden(sig(k), '_name', k),
    d: hidden(sig(k), '_description', ''),
    k: hidden(sig(k), '_type', 'prometheus'),
    u: (local d = sig(k).asTimeSeries('x').spec.vizConfig.spec.fieldConfig.defaults; std.get(d, 'unit', '')),
    e: sig(k).asTarget().spec.query.spec.expr,
    re: sig(k).asRecordingRule('_', '', '5m').expr,
  }} for k in std.objectFields(l.signals)],
  // libs without signals (logs) expose their panel queries instead
  queries: if std.objectHas(l, 'signals') || !std.objectHas(l, 'queries') then [] else
    [{{ n: k, e: std.get(std.get(std.get(std.get(l.queries[k], 'spec', {{}}), 'query', {{}}), 'spec', {{}}), 'expr', '') }} for k in std.objectFields(l.queries)],
  groups: [{{ t: g.title, els: std.objectFields(g.elements) }} for g in std.get(l.grafana, 'groups', [])],
  panels: if std.objectHas(l.grafana, 'groups') || !std.objectHas(l.grafana, 'panels') then [] else std.objectFields(l.grafana.panels),
  // u the rule's runbook_url (a written runbook, else the alert's page on the
  // docs site), rb the runbook the board's Runbooks tab shows
  alerts: [{{ n: r.alert, sev: std.get(r.labels, 'severity', ''), f: r['for'], e: r.expr,
             s: ann(r, 'summary'), d: ann(r, 'description'), u: ann(r, 'runbook_url'), rb: runbook.of(r) }}
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


def collectors():
    """'<exporter>/<collector>' -> exporter, collector, source, metric patterns."""
    out = ev("(import 'libs/common-lib/exporters.libsonnet').exporters")
    return {e + "/" + c: {"exporter": e, "collector": c, "source": ex.get("source", ""), "patterns": col["patterns"]}
            for e, ex in out.items() for c, col in ex["collectors"].items()}


def main():
    # runbookBase: the docs site the alerts' runbook_url points at (one page per alert name)
    data = {"libs": {}, "boards": {}, "errors": {}, "collectors": collectors(),
            "runbookBase": ev("(import 'libs/common-lib/alert/runbook.libsonnet').docsBase")}
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
