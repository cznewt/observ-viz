# Pyroscope  (`g.libs.monitoring.pyroscope`)

Dashboard uid `observ-viz-pyroscope` · 8 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` |
| `goroutines` | short | `go_goroutines{job=~"$job"}` |
| `heapInuse` | bytes | `go_memstats_heap_inuse_bytes{job=~"$job"}` |
| `latencyP50` | s | `histogram_quantile(0.50, sum by (le)(rate(pyroscope_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` |
| `latencyP99` | s | `histogram_quantile(0.99, sum by (le)(rate(pyroscope_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` |
| `receivedBytes` | Bps | `sum(rate(pyroscope_distributor_received_compressed_bytes_sum{job=~"$job"}[$__rate_interval]))` |
| `requestRate` | reqps | `sum(rate(pyroscope_request_duration_seconds_count{job=~"$job"}[$__rate_interval]))` |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job"}` |

## Dashboard

- **Ingest** — `receivedBytes`
- **Requests** — `latencyP50`, `latencyP99`, `requestRate`
- **Resources** — `cpu`, `goroutines`, `heapInuse`, `rss`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `PyroscopeDown` | critical | 5m | — |
| `PyroscopeHighRequestLatency` | warning | 15m | — |
| `PyroscopeHighHeapMemory` | warning | 15m | — |
| `PyroscopeHighGoroutines` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:pyroscope_request_rate:rate5m` | `sum by (instance)(rate(pyroscope_request_duration_seconds_count[5m]))` |
| `instance:pyroscope_cpu_usage:rate5m` | `rate(process_cpu_seconds_total[5m])` |
