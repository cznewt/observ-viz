# Go runtime  (`g.libs.runtimes.golang`)

Dashboard uid `observ-viz-golang` · 11 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job", instance=~"$instance", instance=~"$instance"}[$__rate_interval])` | `instance:go_cpu_usage:rate5m` |
| `gcPauseMax` | s | `go_gc_duration_seconds{quantile="1", job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `gcRate` | ops | `rate(go_gc_duration_seconds_count{job=~"$job", instance=~"$instance", instance=~"$instance"}[$__rate_interval])` | `instance:go_gc_rate:rate5m` |
| `goroutines` | short | `go_goroutines{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `heapAlloc` | bytes | `go_memstats_heap_alloc_bytes{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `heapInuse` | bytes | `go_memstats_heap_inuse_bytes{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `heapObjects` | short | `go_memstats_heap_objects{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `openFds` | short | `process_open_fds{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `stackInuse` | bytes | `go_memstats_stack_inuse_bytes{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |
| `threads` | short | `go_threads{job=~"$job", instance=~"$instance", instance=~"$instance"}` | — |

## Dashboard

- **Go runtime** — `cpu`, `goroutines`, `openFds`, `threads`
- **Memory** — `heapAlloc`, `heapInuse`, `rss`, `stackInuse`
- **Garbage collection** — `gcPauseMax`, `gcRate`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `GoProcessDown` | critical | 5m | — |
| `GoHighGoroutines` | warning | 15m | — |
| `GoHighHeapMemory` | warning | 15m | — |
| `GoSlowGcPause` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:go_cpu_usage:rate5m` | `rate(process_cpu_seconds_total[5m])` |
| `instance:go_gc_rate:rate5m` | `rate(go_gc_duration_seconds_count[5m])` |
