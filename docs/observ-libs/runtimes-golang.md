# Go runtime  (`g.libs.runtimes.golang`)

Dashboard uid `observ-viz-golang` · 11 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` |
| `gcPauseMax` | s | `go_gc_duration_seconds{quantile="1", job=~"$job"}` |
| `gcRate` | ops | `rate(go_gc_duration_seconds_count{job=~"$job"}[$__rate_interval])` |
| `goroutines` | short | `go_goroutines{job=~"$job"}` |
| `heapAlloc` | bytes | `go_memstats_heap_alloc_bytes{job=~"$job"}` |
| `heapInuse` | bytes | `go_memstats_heap_inuse_bytes{job=~"$job"}` |
| `heapObjects` | short | `go_memstats_heap_objects{job=~"$job"}` |
| `openFds` | short | `process_open_fds{job=~"$job"}` |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job"}` |
| `stackInuse` | bytes | `go_memstats_stack_inuse_bytes{job=~"$job"}` |
| `threads` | short | `go_threads{job=~"$job"}` |

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
