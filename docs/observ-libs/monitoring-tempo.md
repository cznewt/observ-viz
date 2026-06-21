# Tempo  (`g.libs.monitoring.tempo`)

Dashboard uid `observ-viz-tempo` · 9 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `blocklistLength` | short | `max(tempodb_blocklist_length{job=~"$job"})` |
| `blocksFlushed` | short | `sum(rate(tempo_ingester_blocks_flushed_total{job=~"$job"}[$__rate_interval]))` |
| `bytesReceived` | Bps | `sum(rate(tempo_distributor_bytes_received_total{job=~"$job"}[$__rate_interval]))` |
| `goroutines` | short | `go_goroutines{job=~"$job"}` |
| `heapInuse` | bytes | `go_memstats_heap_inuse_bytes{job=~"$job"}` |
| `requestP99` | s | `histogram_quantile(0.99, sum by (le)(rate(tempo_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` |
| `requestRate` | reqps | `sum(rate(tempo_request_duration_seconds_count{job=~"$job"}[$__rate_interval]))` |
| `spansReceived` | short | `sum(rate(tempo_distributor_spans_received_total{job=~"$job"}[$__rate_interval]))` |
| `tracesCreated` | short | `sum(rate(tempo_ingester_traces_created_total{job=~"$job"}[$__rate_interval]))` |

## Dashboard

- **Ingest** — `bytesReceived`, `spansReceived`, `tracesCreated`
- **Storage** — `blocklistLength`, `blocksFlushed`
- **Requests** — `requestP99`, `requestRate`
- **Resources** — `goroutines`, `heapInuse`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `TempoDown` | critical | 5m | — |
| `TempoHighBlocklistLength` | warning | 15m | — |
| `TempoSlowRequests` | warning | 15m | — |
| `TempoHighGoroutines` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:tempo_spans_received:rate5m` | `sum(rate(tempo_distributor_spans_received_total[5m]))` |
| `instance:tempo_request_rate:rate5m` | `sum(rate(tempo_request_duration_seconds_count[5m]))` |
