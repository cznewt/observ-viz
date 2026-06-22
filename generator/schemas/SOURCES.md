# observ-viz generator — sources & provenance

This document records where the generated `gen/observ-viz-v2beta1/` (and
`gen/observ-viz-latest/`) builders come from.

## The authoritative schema

`generator/schemas/dashboardv2beta1.jsonschema.json` is the foundation-sdk
Grafana **`dashboard.grafana.app/v2beta1`** dashboard JSON Schema (~126
definitions under top-level `definitions`), with `common.jsonschema.json`
supplying referenced common defs. These are the AUTHORITATIVE source.

* **Provenance.** Exported from the Grafana foundation-sdk
  (`github.com/grafana/grafana/apps/dashboard`, kind `dashboard`, version
  `v2beta1`), via the SDK's JSON-Schema export (the `dashboard.grafana.app`
  CUE → OpenAPI/JSON-Schema pipeline). The two files are committed verbatim; to
  refresh, re-export from the pinned foundation-sdk commit and overwrite them
  (the manual-export step), then run `just gen` and `just compile`.

## Two generation paths

The generator (`generator/observ_viz_gen`) reads those schemas
(`schema.py` → an IR of `SchemaKind{name, kind_const, fields[]}` /
`SchemaField{name, json_type, enum, default, ref, items_ref}`, resolving
`$ref` / `allOf` / `oneOf`) and emits two classes of file:

1. **Schema-emitted structural kinds** — the NEW layout kinds
   (`layout/{grid,autoGrid,rows,tabs}.libsonnet`) and `conditionalRendering`
   are emitted DIRECTLY from the schema (`schema_emit.py`): each `*Kind`/`*Spec`
   pair becomes a `new(...)` constructor (stamping the schema `kind` const) plus
   `withX` setters for every spec property, with item sub-builders
   (`grid.item`, `rows.row`, `tabs.tab`, …). These replace the hand-written
   constructs in `custom/layout.libsonnet`.
2. **Curated setter files** — dashboard / annotation / timeSettings / variable /
   the query envelope are emitted from a curated manifest (`manifest.py`) that
   carries friendly help text + argument defaults. `validate.py` CROSS-CHECKS
   every curated setter against its schema definition on each `--check`, so the
   curated surface is a provably faithful subset of the v2beta1 schema.

## What the generator produces

`observ_viz_gen` emits the typed v2beta1 libsonnet setter builders consumed by
the hand-written veneer in `custom/`. The veneer (`custom/{dashboard,annotation,
panel,query,variable}.libsonnet`) layers constructors (`new(...)`), kind tags,
and convenience methods over these generated setters; `main.libsonnet` at the
repo root wires the two together.

The full file set (20 files), each prefixed with
`// This file is generated, do not manually edit.`:

| file | shape | source | roots setters at |
| --- | --- | --- | --- |
| `observ-viz-v2beta1/main.libsonnet` | import map | manifest | — |
| `observ-viz-v2beta1/_versions.libsonnet` | viz-kind -> pluginVersion map | curated | — |
| `observ-viz-v2beta1/dashboard.libsonnet` | documented setters | manifest (schema-checked) | `spec` |
| `observ-viz-v2beta1/annotation.libsonnet` | documented setters | manifest (schema-checked) | `spec` |
| `observ-viz-v2beta1/timeSettings.libsonnet` | documented setters | manifest (schema-checked) | bare object |
| `observ-viz-v2beta1/variable/main.libsonnet` | compact, per-kind groups | manifest (schema-checked) | `spec` |
| `observ-viz-v2beta1/panel/main.libsonnet` | import map | manifest | — |
| `observ-viz-v2beta1/panel/{stat,table,timeSeries}.libsonnet` | compact nested groups | **curated** (not in dashboard schema) | `spec.vizConfig.spec` |
| `observ-viz-v2beta1/query/main.libsonnet` | import map | manifest | — |
| `observ-viz-v2beta1/query/{prometheus,loki}.libsonnet` | documented setters | **curated** (free-form DataQuery) | `spec.query.spec` |
| `observ-viz-v2beta1/layout/main.libsonnet` | import map | **schema** | — |
| `observ-viz-v2beta1/layout/{grid,autoGrid,rows,tabs}.libsonnet` | constructor + setters + item sub-builder | **schema** | `spec` |
| `observ-viz-v2beta1/conditionalRendering.libsonnet` | group/data/variable/timeRangeSize builders | **schema** | `spec` |
| `observ-viz-latest/main.libsonnet` | redirect import | manifest | — |

The `panel/{stat,table,timeSeries}`, `query/{prometheus,loki}` and
`_versions.libsonnet` files are **curated and left untouched** by schema
generation: panel viz options live in the free-form `vizConfig` and datasource
query specs in the free-form `DataQuery.spec`, neither of which is described by
the dashboard schema.

## Why a hand-authored manifest (not schema fetching)

The Grafana dashboard schema **v2beta1** (`dashboard.grafana.app`) is the
upstream source of truth for these field names/types. In principle a generator
could fetch the published CUE/OpenAPI schema and derive every setter. We
deliberately do **not** do that here:

1. **Curated surface, not the full schema.** The committed builders expose a
   small, opinionated subset of the v2 schema (the fields observ-viz packs
   actually use), with friendly help text and sensible argument defaults
   (e.g. `withFrom(value='now-6h')`). A raw schema dump would emit hundreds of
   setters and none of the curation.
2. **Two deliberate dialects.** Some files carry grafonnet-style `'#withX'::`
   doc descriptors (dashboard / annotation / timeSettings / query/*); the
   variable + panel-option files are intentionally compact (shared `local`
   helpers, nested groups, no descriptors). That stylistic split is an authoring
   choice, not something a schema encodes.
3. **Hermetic + offline.** Generation must run in CI and on contributor laptops
   with no network and no Grafana checkout. The manifest is plain Python data,
   so `observ-viz-gen all` is deterministic and dependency-free.
4. **Stable provenance for pins.** `_versions.libsonnet` maps each viz kind to
   the `pluginVersion` stamped into `vizConfig.spec`; those pins are policy
   decisions recorded here, not derived from a schema.

`generator/manifest.py` is therefore the single source of truth. To add or
change a kind/field: edit `manifest.py`, run `just gen` (or
`make gen` / `cd generator && python3 -m observ_viz_gen all`), and the parity
test (`generator/tests/test_parity.py`, `make gen-test`) guards against drift.

The empty `schemas/datasources/` and `schemas/panels/` directories are reserved
for optional future schema snapshots (provenance fixtures) should we later
choose to cross-check the manifest against upstream; they are not consumed by
the current manifest-driven generation.

## v2beta1 facts captured as manifest data

These are the non-obvious v2 changes versus the older v1 builders, recorded as
data in `manifest.py` so they survive regeneration:

- **`variable.hide` is a STRING enum, not an int.** v2 uses
  `dontHide | hideLabel | hideVariable` (string), whereas v1 dashboards used a
  numeric hide flag (0/1/2). The compact variable file emits a bare
  `withHide(value)` setter (the compact dialect carries no `'#withX'::`
  descriptor, so the enum cannot be advertised inline); the allowed values are
  documented here and noted on `VARIABLE_COMMON` in `manifest.py`.
- **Variable kinds dropped the `Kind` suffix / `type` field.** The serialized
  kind tags (`QueryVariable`, `DatasourceVariable`, `CustomVariable`,
  `IntervalVariable`, `TextVariable`, `ConstantVariable`, `GroupByVariable`,
  `AdhocVariable`) and the per-kind `new(...)` constructors live in
  `custom/variable.libsonnet`; only the field setters are generated.
- **`dashboard.cursorSync` is a string enum** (`Off | Crosshair | Tooltip`),
  modelled with `enums=` on the `CursorSync` field.
- **Panel `vizConfig`** is `{ kind: 'VizConfig', group: <pluginId>,
  version: <pluginVersion>, spec: { options, fieldConfig } }`. The generated
  panel-option setters root at `spec.vizConfig.spec`; the envelope + version
  pin lookup live in `custom/panelBase.libsonnet` + `_versions.libsonnet`.
- **Queries embed the datasource inside the `DataQuery`** as
  `{ name: <uid> }` (v2), handled by `custom/query.libsonnet`; the generated
  query files only set the inner query spec via the `q(o)` helper.

## conditionalRendering — out of generator scope (documented here)

v2beta1 adds **conditional rendering** to rows/tabs/panels. The kinds are:

- `ConditionalRenderingGroup` — `{ spec: { visibility, condition, items } }`
- `ConditionalRenderingData` — `{ spec: { value } }` (show only if queries
  return data)
- `ConditionalRenderingVariable` — `{ spec: { variable, operator, value } }`

(`ConditionalRenderingTimeRange` also exists upstream but is not currently
exposed.) These are assembled entirely in `custom/layout.libsonnet`
(`layout.conditional.*`, `layout.withConditionalRendering`, `layout.showIfData`)
and are **not** emitted by the generator — they are hand-authored veneer.

Relatedly, the **`{ kind, spec }` transformation wrapping** is also veneer-only:
`custom/panel.libsonnet`'s `withTransformations` accepts the flat
`{ id, options }` form and wraps each into
`{ kind: id, spec: { id, options } }`. The generator does not produce any
transformation setters.
