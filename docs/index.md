# observ-viz

A standalone [Jsonnet](https://jsonnet.org/) library — in the spirit of
[grafonnet](https://github.com/grafana/grafonnet) — for generating **Grafana
dashboard schema v2** resources (`dashboard.grafana.app/v2beta1`).

**Slim core, lots of mixins.** The core is just the v2 builders + layouts +
a lean signal abstraction. Everything else — library panels, alert/log/deploy
helpers, domain **packs**, **scenarios**, and the **reference** boards — is a
mixin on top.

## The v2 idea

Where grafonnet targets the v1 (monolithic `panels[]`) model, observ-viz targets
the **v2 model**: panels are reusable **elements** defined once, and **layouts**
reference them by name.

```
spec.elements = { <name>: PanelKind, ... }   # define each panel once
spec.layout   = GridLayout | RowsLayout | AutoGridLayout | TabsLayout
                # items hold an ElementReference{name}, not the panel
```

## Quickstart

```jsonnet
local g = import 'observ-viz/g.libsonnet';
local ds = '${datasource}';

local up =
  g.panel.timeSeries.new('Up')
  + g.panel.timeSeries.withTargets([ g.query.prometheus.new(ds, 'up') ])
  + g.panel.timeSeries.standardOptions.withUnit('short');

g.dashboard.new('Minimal')
+ g.dashboard.withElements(g.element.panel('up', up))
+ g.dashboard.withLayout(
    g.layout.grid.new() + g.layout.grid.withItems([ g.layout.grid.item('up', 0, 0, 12, 8) ]))
```

`.toResource()` → the full `apiVersion/kind/metadata/spec` envelope (grafanactl /
k8s API). `.toSpec()` → the bare `DashboardV2Spec` (grizzly).

## What's inside

| Layer | What |
|-------|------|
| **core** | `dashboard`, `panel` (all 25 Grafana panel types), `query`, `layout`, `variable`, `element`, `util` |
| **signal** | lean v2-native signal: metric → element / target |
| **library / alert / logs / deploy** | reusable styled panels, alert rules, log panels, deploy annotations |
| **packs** | observ-lib mixins, mirroring the [alloy-resources](https://github.com/cznewt/alloy-resources) module tree |
| **scenarios** | aggregates of packs per environment (+ Backstage Systems) |
| **reference** | 3 Grafana folders: Panel / Language / Deployment reference |

See [Concepts](concepts.md) to get oriented, or jump to
[Examples & local Grafana](examples.md) to see it running.
