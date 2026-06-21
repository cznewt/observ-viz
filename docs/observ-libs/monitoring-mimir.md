# Mimir  (`g.libs.monitoring.mimir`)

Dashboard uid `observ-viz-mimir` · 6 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` |
| `heap` | bytes | `go_memstats_heap_inuse_bytes{job=~"$job"}` |
| `ingesterSeries` | short | `sum(cortex_ingester_memory_series{job=~"$job"})` |
| `queries` | reqps | `sum(rate(cortex_query_frontend_queries_total{job=~"$job"}[$__rate_interval]))` |
| `receivedSamples` | short | `sum(rate(cortex_distributor_received_samples_total{job=~"$job"}[$__rate_interval]))` |
| `requestP99` | s | `histogram_quantile(0.99, sum by (le)(rate(cortex_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` |

## Dashboard

- **Writes** — `ingesterSeries`, `receivedSamples`
- **Reads** — `queries`, `requestP99`
- **Resources** — `cpu`, `heap`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `MimirDown` | critical | 5m | — |
| `MimirHighRequestLatency` | warning | 15m | — |
| `MimirHighHeapMemory` | warning | 15m | — |
| `MimirHighCpu` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:cortex_received_samples:rate5m` | `sum(rate(cortex_distributor_received_samples_total[5m]))` |
| `instance:cortex_queries:rate5m` | `sum(rate(cortex_query_frontend_queries_total[5m]))` |
