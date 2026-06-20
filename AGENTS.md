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
- `panels` (56 presets, 8 categories), `annotations` (base + severity + reboot/service_failed), `tokens`, `utils` (label→selector/legend, chainLabels), `alert`/`logs`/`deploy`, `pack`.

## observ-libs (`g.libs.*`) — 23 domain packs
`runtimes.{golang,jvm,python,dotnet,nodejs}` · `system.{linux,docker,windows}` · `kubernetes.{pod,cadvisor}` · `databases.sql.{postgres,mysql}` · `databases.kv.{redis,memcached,etcd}` · `monitoring.{prometheus,mimir,loki,tempo,pyroscope}` · `collector.alloy` · `alerts` · `logs`.
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

[`just`]: https://github.com/casey/just
