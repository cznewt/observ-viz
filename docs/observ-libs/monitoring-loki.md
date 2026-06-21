# Loki  (`g.libs.monitoring.loki`)

Dashboard uid `observ-viz-loki` · 6 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `bytes` | Bps | `sum(rate(loki_distributor_bytes_received_total{job=~"$job"}[$__rate_interval]))` |
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` |
| `heap` | bytes | `go_memstats_heap_inuse_bytes{job=~"$job"}` |
| `lines` | short | `sum(rate(loki_distributor_lines_received_total{job=~"$job"}[$__rate_interval]))` |
| `requestP99` | s | `histogram_quantile(0.99, sum by (le)(rate(loki_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` |
| `streams` | short | `sum(loki_ingester_memory_streams{job=~"$job"})` |

## Dashboard

- **Writes** — `bytes`, `lines`, `streams`
- **Reads** — `requestP99`
- **Resources** — `cpu`, `heap`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `LokiDown` | critical | 5m | — |
| `LokiHighRequestLatency` | warning | 15m | — |
| `LokiHighHeapMemory` | warning | 15m | — |
| `LokiManyActiveStreams` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:loki_lines_received:rate5m` | `sum(rate(loki_distributor_lines_received_total[5m]))` |
| `instance:loki_bytes_received:rate5m` | `sum(rate(loki_distributor_bytes_received_total[5m]))` |
