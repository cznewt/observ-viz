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

## Usage

Three ways to use it — and `jb`/`jsonnet` run from a Docker image, so the only
local requirement is Docker + [`just`](https://github.com/casey/just). Each has a
ready-made justfile in [`examples/justfiles/`](examples/justfiles/); the full
walkthrough is in [docs/usage.md](docs/usage.md).

```sh
# 1) render with the image, no vendoring — a bundled observ-lib -> dashboards/ + alerts/ + rules/
docker run --rm -v "$PWD":/work ghcr.io/cznewt/observ-lib render-lib iot.homeAssistant --validate

# 2) author your own dashboards: vendor + render        (vendor-and-render.justfile)
# 3) ship an observ-lib container: dashboards+alerts+rules (observ-lib.justfile)
```

## Layout of this repo

| Path | What |
|------|------|
| `gen/` | **Generated** typed builders (do not hand-edit) |
| `custom/` | Hand-written veneer: dashboard / element / panel / query / layout / variable / annotation / util |
| `libs/common-lib/` | Shared base: signal engine, 56 panel presets, annotations, tokens, utils, alert/logs/deploy, the `pack` contract |
| `libs/*-observ-lib/` | 26 domain observ-libs (runtimes · system · kubernetes · databases · collector · infra · iot · alerts · logs) |
| `libs/reference-lib/` | Reference boards (4 Grafana folders) · `scenarios/` deployment profiles · `patterns/` (RED, alerts overview) |
| `templates/observ-lib/` | Generic observ-lib justfile + mixin template (Makefile_mixin analogue) |
| `scripts/`, `docker/` | Render / load / deploy tooling + the renderer image |
| `examples/` | Worked dashboards + [example justfiles](examples/justfiles/) · `generator/` schema → builder generator |

## Development

```sh
just test         # compile + packs + panels (no docker)
just render-lib iot.homeAssistant --validate   # render an observ-lib -> 3 dirs
just up           # local Grafana+Prometheus+Loki   ·   just load-all
just docs         # build the docs site
```

Full capability list: [docs/capabilities.md](docs/capabilities.md). Docs site
is published to GitHub Pages from `main`.

## Status

Experimental. Schema fidelity tracks `dashboard.grafana.app/v2beta1`.
