# observ-viz — agent context

A standalone **Jsonnet** library + tooling for **Grafana dashboard schema v2**
(`dashboard.grafana.app/v2beta1`). v2's idea: panels are reusable **elements**
defined once; **layouts** reference them by name. Repo + jb dependency:
`github.com/cznewt/observ-viz`. Toolchain image: `ghcr.io/cznewt/observ-lib`.

Only local requirement for any workflow below: **Docker + [`just`]**. `jb`/`jsonnet`
run from images, nothing else is installed.

## Three ways to use it

**1 · Render with the image (no vendoring).** The image bundles observ-viz on the jpath.
```sh
docker run --rm -v "$PWD":/work ghcr.io/cznewt/observ-lib render <manifest.jsonnet> > board.json
docker run --rm -v "$PWD":/work ghcr.io/cznewt/observ-lib render-lib system.linux --validate
#   render-lib -> build/<lib>/{dashboards/<uid>.json, alerts/<group>.yaml, rules/<group>.yaml}
```

**2 · Author your own dashboards (vendor with jb).** `jsonnetfile.json` declares
common-lib + observ-viz (`github.com/cznewt/observ-viz`, subdirs `libs/common-lib`
and "", legacyImports). Then:
```jsonnet
local g = import 'g.libsonnet';
local ds = '${datasource}';
local up = g.panel.timeSeries.new('Up')
  + g.panel.timeSeries.withTargets([ g.query.prometheus.new(ds, 'up') ])
  + g.panel.timeSeries.standardOptions.withUnit('short');
g.dashboard.new('Minimal')
+ g.dashboard.withElements(g.element.panel('up', up))
+ g.dashboard.withLayout(g.layout.grid.new()
    + g.layout.grid.withItems([ g.layout.grid.item('up', 0, 0, 12, 8) ]))
// .toResource() = full k8s envelope · .toSpec() = bare DashboardV2Spec
```
Render: `jsonnet -J vendor/github.com/cznewt/observ-viz -J vendor -J . dashboards.jsonnet`.

**3 · Ship an observ-lib (dashboards + alerts + rules).** Copy `templates/observ-lib/`
(`main.libsonnet` + `mixin.libsonnet` + `config.libsonnet` + `justfile`); `just build`.

## Core API (`g.*`)
- `g.dashboard` — `new(title)` / `withUid/withDescription/withTags/withVariables/withAnnotations/withElements/withLayout` · `toResource()` / `toSpec()`.
- `g.element.panel(name, panelObj)` → `{name: PanelKind}` · `g.element.ref(name)`.
- `g.panel.<type>.new(title)` (25 types) + `.withTargets/.standardOptions.withUnit/.options.*/.custom.*`; generic `g.panel.base(kind, title)`.
- `g.query.prometheus.new(ds, expr)` / `g.query.loki.new` / … ; generic `g.query.base(kind, spec)`.
- `g.layout.{grid,rows,autoGrid,tabs}` — items reference elements **by name** (`grid.item(name,x,y,w,h)`, `rows.row(title, layout)`, `tabs.tab(title, layout)`); nestable.
- `g.variable.<kind>.new(...)`, `g.annotation.new(...)`.

## common-lib (`g.common.*`)
- `signal` — `new(name, type, ds, expr, unit)` then `.filteringSelector/.groupLabels/.aggLevel` then `.asTimeSeries/.asStat/.asTable/.asTarget(title)`. Rich form: `init(...)` + `addSignal(name, type='counter'|'histogram'|'gauge'|…, expr/unit)` (auto rate/quantile wrapping) + variable generation.
- `panels` (56 presets, 8 categories), `annotations` (base + severity + reboot/service_failed), `tokens`, `utils` (label→selector/legend, chainLabels), `alert`/`logs`/`deploy`, `pack`, `podrows` (the Overview's Pods table / Resources / Logs rows, shared by service boards and — scoped to the pods behind `$job`, gated on `has_pods` — every job-scoped tabbed pack board, or one naming its pods with `podMetric`; `overviewPods: false` opts out).

## observ-libs (`g.libs.*`) — domain packs
`runtimes.{golang,jvm,python,dotnet,nodejs}` · `system.{linux,docker,windows,systemd,processExporter}` · `networking.{wireguard,unifi,ingressNginx}` · `cicd.{backstage,argocd}` · `kubernetes.{pod,cadvisor,cluster,multicluster}` · `monitoring.{...,alertmanager,alertHandler,opencost,anomalyExporter}` · `databases.sql.{postgres,mysql}` · `databases.kv.{redis,memcached,etcd}` · `monitoring.{prometheus,mimir,loki,tempo,pyroscope,grafana}` · `collector.alloy` · `alerts` · `logs`.
`services.{alloy,grafana,mimir}` — a whitebox pack wrapped by `g.libs.service` (`libs/service-observ-lib`): one board per service whose Overview opens on the shared pod rows (`podrows`: Pods table with node, phase, restarts, age, CPU, memory vs limit; Resources; Logs), gated on the Kubernetes / Containers markers, then the app's own instances table; then platform tabs (Kubernetes / Containers / Docker / systemd / Host process / Process / Go runtime / Windows / Logs — pod logs + Kubernetes events on kube, the journal for a systemd unit) gated on presence, joined on cluster/namespace/pod (kube) or $host + a static unit/service/group/container identity (hosts). The systemd / Host process / Ingress tabs embed `system.systemd`, `system.processExporter` and `networking.ingressNginx` (each lib exports an element-map builder next to `new()`), and the composer merges every embedded pack's alert/recording rules, scoped per platform and renamed `<app>-<group>`.
Each `new(config)` → `{ signals, grafana:{dashboard,dashboards,elements,layout}, prometheus:{alerts,rules}, asMonitoringMixin() }`.

## observ-lib container contract
`pack.build(cfg, signals, groups, alerts, rules)`:
- alerting: `g.common.alert.rule.new(name, expr, for, severity, labels, annotations)` in `g.common.alert.rule.group(name, [...])`
- recording: `g.common.alert.rule.record(name, expr, labels)` in a group
- `g.common.signal.new(name,'prometheus',ds,expr,unit).filteringSelector(sel)` for series

## justfiles (the Makefile_mixin analogue)
- `examples/justfiles/`: `render-with-image.justfile`, `vendor-and-render.justfile`, `observ-lib.justfile` (+ `jsonnetfile.json`, `dashboards.jsonnet`).
- `templates/observ-lib/justfile`: `init / vendor / dashboards / alerts / rules / build / fmt / lint / clean` — render this lib's dashboards + alerting + recording rules.

## Conventions
- **Pure Jsonnet for the C++ `_jsonnet` binding** — no `std.floorToInt`/`std.get`/`std.member`/`std.objectKeysValues`; use `std.objectHas`/`std.objectFields`/`std.foldl`/`std.count`.
- Slim core; domain logic lives in `libs/` mixins.

## Where the rest is documented
`README.md` · `CONTRIBUTING.md` · docs site (mkdocs, GitHub Pages): `docs/capabilities.md`
(full feature list), `docs/usage.md` (the three workflows), `docs/render.md` (container),
`docs/docker.md` (image), `docs/api.md` (builders), `docs/libs.md` (observ-libs),
`docs/panels.md` (chart types).

The site's board tree (one page per board, filed like the Grafana folders: every
tab rendered, then the alert rules, recording rules and signals) is generated:
- `docs/boards.json` (committed) - `just docs-boards` (scripts/gen-lib-doc.py)
  after changing a library: every library and mixin board, its folder, signals,
  alerts and rules;
- the screenshots - `just docs-shots build/shots --jobs 3` on the monlab Grafana,
  then `just docs-shots-publish build/shots` (orphan `docs-shots` branch);
- the pages + navigation - scripts/gen-board-pages.py writes `docs/boards/` and
  `mkdocs.gen.yml` (INHERIT: mkdocs.yml, plus redirects from the old pages) at
  docs build time; build/serve with `-f mkdocs.gen.yml` (`just docs`, `just docs-serve`).

[`just`]: https://github.com/casey/just

## Agent skills (`skills/`)
Five skills, linked from `.claude/skills/` and `.agents/skills/`, packaged as a Claude
Code plugin by `.claude-plugin/` - use them rather than ad-hoc curl or guessing:
- `telemetry-query` (`scripts/ovq.py`): metrics, logs, traces, profiles, alerts, rules,
  board layouts through `GRAFANA_URL` / `GRAFANA_TOKEN` (a Viewer token; `--env <file|profile>`).
- `observ-viz-catalog` (`scripts/catalog.py`): library / board / signal / alert lookup
  from `docs/boards.json` and `docs/exporters/`.
- `board-verify` (`scripts/board_check.py`): every visible panel query of a board, with
  its variables and conditional rendering.
- `alert-triage` (`scripts/triage.py`): an alert's fact sheet; the diagnosis is advice only.
- `observ-lib-authoring`: the edit loop for `libs/` - names from live telemetry, `just test`,
  `just validate-lib`, test push, board-verify, `just docs-boards`.
The scripts are stdlib Python and import each other by relative path; keep the skill
folders side by side. docs/agents.md is the user documentation.

## Deploying through monitor-tools
Every scenario (`scenarios/<name>`) exposes `asMonitoringMixin()` = `{grafanaDashboards (v2 specs), prometheusAlerts, prometheusRules}`. monitor-tools ships an `observ-viz` mixin (`docker/files/mixins/observ-viz-mixin`) that vendors this repo with jb and selects a scenario via `config.scenario`; its `grafana.render: grafanactl` path pushes v2 boards through the app-platform API. `scenarios/platform` = site-agnostic platform boards, `scenarios/monlab` = one service board per monitoring-lab catalog component.
