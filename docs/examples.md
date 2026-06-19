# Examples & local Grafana

## Local stack

A `docker-compose.yml` brings up Grafana 13 (with the v2 / new-layouts feature
flags), Prometheus, Loki, and node-exporter:

```sh
just up          # start the stack
just load-all    # examples + reference + scenarios, via the v2 app-platform API
just status      # list folders + dashboards
# open http://localhost:3000  (admin / admin)
```

Dashboards are pushed as real `dashboard.grafana.app/v2beta1` resources through
the Grafana app-platform (kubernetes-style) API — `scripts/load.py` renders each
`*.jsonnet` and POSTs it, creating Grafana folders as needed.

## Worked examples (`examples/`)

| File | Shows |
|------|-------|
| `minimal-grid.jsonnet` | smallest valid dashboard |
| `red-dashboard.jsonnet` | RED from signals + variables + deploy annotations |
| `alerts-overview.jsonnet` | nested `RowsLayout` → grids (alerts pattern) |
| `golang-pack.jsonnet` / `linux-pack.jsonnet` / `prometheus-pack.jsonnet` | packs with live data |
| `doom.jsonnet` | targets the real `grafana-doom-datasource` plugin via `query.base` |
| `doom-iframe.jsonnet` | DOOM via the `text` panel in HTML mode (plays immediately) |

## DOOM 🔫

`examples/doom.jsonnet` proves the generic escape hatch — it targets a
third-party datasource plugin with **zero library code**:

```jsonnet
g.panel.timeSeries.new('DOOM')
+ g.panel.withTargets([
    g.query.base('grafana-doom-datasource', { queryType: 'screen', halfResolution: true })
    + g.query.withDatasource('doom'),
  ])
```

`just doom` loads the iframe variant (no plugin needed); the datasource variant
renders once the plugin is installed.

## Verify locally (no docker)

```sh
just compile     # _jsonnet compile of every example + structural checks
just packs       # render every pack end-to-end
just test        # both
```
