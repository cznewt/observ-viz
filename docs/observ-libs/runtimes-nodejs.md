# Node.js runtime  (`g.libs.runtimes.nodejs`)

Dashboard uid `observ-viz-nodejs` · 8 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `activeHandles` | short | `nodejs_active_handles_total{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `activeRequests` | short | `nodejs_active_requests_total{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `eventloopLag` | s | `nodejs_eventloop_lag_seconds{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `eventloopLagP99` | s | `nodejs_eventloop_lag_p99_seconds{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `gcDuration` | s | `rate(nodejs_gc_duration_seconds_sum{job=~"$job", instance=~"$instance", instance=~"$instance"}[$__rate_interval])` | — |
| `heapTotal` | bytes | `nodejs_heap_size_total_bytes{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `heapUsed` | bytes | `nodejs_heap_size_used_bytes{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |

## Dashboard

- **Event loop** — `eventloopLag`, `eventloopLagP99`
- **Memory** — `heapTotal`, `heapUsed`, `rss`
- **Garbage collection** — `gcDuration`
- **Handles** — `activeHandles`, `activeRequests`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `NodeJsDown` | critical | 5m | — |
| `NodeJsHighEventLoopLag` | warning | 15m | — |
| `NodeJsHighHeapUsage` | warning | 15m | — |
| `NodeJsHighGcTime` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:nodejs_heap_utilisation:ratio` | `nodejs_heap_size_used_bytes / nodejs_heap_size_total_bytes` |
| `instance:nodejs_gc_duration:rate5m` | `rate(nodejs_gc_duration_seconds_sum{job=~".+"}[5m])` |
