# observ-viz reference-mixin

A reference *consumer* of observ-viz — the same shape as the `reference-mixin` in
monitor-tools, but producing **Grafana v2** boards organized into a Grafana folder.

```
reference-mixin/
├─ jsonnetfile.json            # deps: observ-viz, docsonnet, xtd
├─ config.libsonnet            # _config: datasource, folder, tags
├─ mixin.libsonnet             # dashboards + config  (monitoring-mixin shape)
├─ dashboards/
│  ├─ dashboards.libsonnet     # grafanaDashboards+:: { '<name>.json': board }
│  └─ panels.libsonnet         # "panel gallery" — one of every panel type
└─ render.jsonnet              # -> { '<name>.json': <v2 resource> }
```

Boards (all placed in the **observ-viz Reference** folder):
- `reference-panels` — a gallery of every Grafana panel type
- `reference-red` — RED pattern
- `reference-alerts` — alerts overview pattern
- `reference-go` — Go runtime pack
- `reference-linux` — Linux node pack
- `reference-postgres` — PostgreSQL pack

## Use

In-repo (no vendoring), against the local Grafana from the repo root:

```sh
just up
python3 scripts/load.py reference-mixin/render.jsonnet   # creates the folder + boards
```

As a vendored consumer:

```sh
jb install         # pulls observ-viz per jsonnetfile.json
jsonnet -J vendor -m out reference-mixin/render.jsonnet
```

`mixin.libsonnet` also exposes the standard `grafanaDashboards+::` map for the
monitor-tools render pipeline. Vendored consumers import the library via
`import 'observ-viz/g.libsonnet'` (here the repo root provides `g.libsonnet`).
