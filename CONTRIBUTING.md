# Contributing to observ-viz

## Dev setup

Local steps use the Python `_jsonnet` binding (`pip install jsonnet`). Full
render / vendor / format / lint use the `ghcr.io/cznewt/monitor-tools:latest`
image (so no native `jb`/`jsonnet` needed). [`just`](https://github.com/casey/just)
drives everything.

## Run the tests

```sh
just test       # compile (examples) + packs (every observ-lib) + panels (presets + chart boards)
# or individually:
just compile    # tests/compile.py   — examples + structural invariants
just packs      # tests/packs.py     — every observ-lib renders .grafana.dashboard.toResource()
just panels     # tests/panels.py    — every common-lib preset + reference variation board
```

## Add an observ-lib

1. Create `libs/<name>-observ-lib/main.libsonnet`:

   ```jsonnet
   local pack = import 'libs/common-lib/pack.libsonnet';
   local signal = import 'libs/common-lib/signal/main.libsonnet';
   local alert = import 'libs/common-lib/alert/main.libsonnet';
   {
     new(config={}):
       local cfg = {
         uid: 'observ-viz-<name>', dashboardTitle: '<Title>',
         dashboardTags: ['<name>'], datasource: '${datasource}',
         selector: 'job=~"$job"', varMetric: '<a metric that always exists>',
       } + config;
       local sig(name, expr, unit, desc='') =
         signal.new(name, 'prometheus', cfg.datasource, expr, unit)
         .filteringSelector(cfg.selector).withDescription(desc);
       local signals = { /* metric+expr signal per series */ };
       pack.build(cfg, signals,
         [ { title: '<Group>', width: 12, height: 8, elements: { /* signals.x.asTimeSeries(...) */ } } ],
         [ /* optional alerting rule groups: alert.rule.group(name, [alert.rule.new(...)]) */ ],
         [ /* optional recording rule groups: alert.rule.group(name, [alert.rule.record(...)]) */ ]),
   }
   ```

2. Add a `jsonnetfile.json` (copy any existing lib's — it declares the observ-viz dep for jb).
3. Register it in `libs/observ-libs.libsonnet` under the right group (`runtimes` / `system` / `databases` / …).
4. Add its dotted path to the `PACKS` list in `tests/packs.py`.
5. `just packs` to verify, then `just docs-libs` to refresh `docs/libs.md`.

The signal abstraction does the heavy lifting — see [common-lib `signal`](docs/libs.md#common-lib)
for `init`/`addSignal` (typed counter/histogram/gauge) and the `as*` renderers.

## Add a panel type or datasource

The generic `g.panel.base(kind)` / `g.query.base(kind, spec)` already work for
**anything** (v2 stores both as `kind` + free-form `spec`). For a typed builder,
drop a schema under `generator/schemas/`, add a registry line, and run `just gen`.

## Rules

`pack.build(cfg, signals, groups, alerts, rules)`:
- alerting — `g.common.alert.rule.new(name, expr, for, severity, labels, annotations)` inside `g.common.alert.rule.group(name, [...])`
- recording — `g.common.alert.rule.record(name, expr, labels)` inside a group

`just render-lib <lib> --validate` renders the container to `build/<lib>/{dashboards,alerts,rules}/`.

## Docs

```sh
just docs-panels   # regenerate docs/panels.md from the chart definitions
just docs-libs     # regenerate docs/libs.md from the observ-lib index
just docs          # build the mkdocs site
```

The `docs` GitHub Action regenerates the generated pages and deploys to GitHub
Pages on every push to `main`.

## Conventions

- **Pure Jsonnet for the C++ `_jsonnet` binding** — no `std.floorToInt` /
  `std.get` / `std.member` / `std.objectKeysValues`. Use `std.objectHas` /
  `std.objectFields` / `std.foldl` / `std.count`.
- Match the surrounding comment density, naming and idiom.
- Keep the core slim; put domain logic in `libs/` mixins.
