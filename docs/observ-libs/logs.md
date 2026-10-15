# Logs  (`g.libs.logs`)

Dashboard uid `observ-viz-logs` · 3 queries · 0 alerts · 0 recording rules · [every tab rendered](../dashboards/observ-viz-logs.md).

## Queries

The panel queries the library builds (`.queries`).

| Query | Expression |
|-------|------------|
| `logs` | `{}` |
| `rate` | `sum(rate({} [$__rate_interval]))` |
| `volumeByLevel` | `sum by (detected_level) (count_over_time({} [$__auto]))` |

## Dashboard

- **Panels** (`.grafana.panels`) — `logs`, `logsVolume`, `rate`
