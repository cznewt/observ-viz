# observ-viz

A standalone [Jsonnet](https://jsonnet.org/) library — in the spirit of
[grafonnet](https://github.com/grafana/grafonnet) — for generating **Grafana
dashboard schema v2** resources (`dashboard.grafana.app/v2beta1`).

Where grafonnet targets the v1 (monolithic `panels[]`) model, observ-viz targets
the **v2 model**, whose defining idea is that **panels are reusable "elements"
defined once** and **layouts reference them by name**:

```
spec.elements   = { <name>: PanelKind, ... }   # define each panel once
spec.layout     = GridLayout | RowsLayout | AutoGridLayout | TabsLayout
                  # layout items hold an ElementReference{name} — not the panel
```

## Why

grafonnet is v1-only ([grafana/grafonnet#264](https://github.com/grafana/grafonnet/issues/264)),
so there is no Jsonnet builder for the v2 schema. observ-viz fills that gap and adds:

- **Native v2 builders** — dashboard / element / layout / query / variable-kind / annotation.
- **First-class layouts** — `grid`, `rows`, `autoGrid`, `tabs`, nesting freely.
- **A generic escape hatch** — `panel.base(vizKind, …)` / `query.base(dsKind, spec)`
  work for *any* panel or datasource immediately (v2 stores both as a `kind` +
  free-form `spec`), so coverage is never blocked on a typed builder.
- **A Python schema generator** — typed builders are generated from Grafana
  schemas, so adding a datasource/panel is "drop a schema, run the generator".
- **A lean signal abstraction** + reusable **alert** / **logs** libs and domain
  **packs** (kube, cadvisor, windows/linux/docker services, Go/JVM/Python/.NET/Node runtimes).

## Install

```sh
jb install https://github.com/cznewt/observ-viz@master
```

```jsonnet
local g = import 'observ-viz/g.libsonnet';
```

## Quickstart

```jsonnet
local g = import 'observ-viz/g.libsonnet';
local ds = '${datasource}';

// 1) define a reusable element
local up =
  g.panel.timeSeries.new('Up')
  + g.panel.timeSeries.withTargets([ g.query.prometheus.new(ds, 'up') ])
  + g.panel.timeSeries.standardOptions.withUnit('short');

// 2) layout references it BY NAME
g.dashboard.new('Minimal')
+ g.dashboard.withElements(g.element.panel('up', up))
+ g.dashboard.withLayout(
    g.layout.grid.new() + g.layout.grid.withItems([ g.layout.grid.item('up', 0, 0, 12, 8) ]))
```

Call `.toResource()` for the full `apiVersion/kind/metadata/spec` envelope
(grafanactl / k8s API), or `.toSpec()` for the bare `DashboardV2Spec` (grizzly).

## Layout of this repo

| Path | What |
|------|------|
| `gen/` | **Generated** typed builders (do not hand-edit) |
| `custom/` | Hand-written veneer: `new()` constructors, layouts, util |
| `signal/` | Lean v2-native signal abstraction |
| `library/` | Common reusable element definitions |
| `alert/`, `logs/` | Reusable alert-rule + log builders |
| `packs/` | Domain & runtime observ-lib packs |
| `patterns/` | Whole-dashboard encapsulations (RED, alerts overview) |
| `generator/` | Python schema → Jsonnet builder generator |
| `examples/` | Worked dashboards |

## Development

```sh
just compile      # local _jsonnet compile + structural checks (no docker)
just gen          # regenerate gen/ from generator/schemas
just render       # full docker render + golden diff (monitor-tools image)
just test         # compile + generator unit tests
```

## Status

Experimental. Schema fidelity tracks `dashboard.grafana.app/v2beta1`.
