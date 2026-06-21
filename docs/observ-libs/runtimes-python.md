# Python runtime  (`g.libs.runtimes.python`)

Dashboard uid `observ-viz-python` · 6 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` | `instance:python_cpu_usage:rate5m` |
| `gcCollections` | ops | `sum without(generation)(rate(python_gc_collections_total{job=~"$job"}[$__rate_interval]))` | — |
| `gcObjects` | short | `rate(python_gc_objects_collected_total{job=~"$job"}[$__rate_interval])` | — |
| `maxFds` | short | `process_max_fds{job=~"$job"}` | — |
| `openFds` | short | `process_open_fds{job=~"$job"}` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job"}` | — |

## Dashboard

- **Garbage collection** — `gcCollections`, `gcObjects`
- **Process** — `cpu`, `rss`
- **File descriptors** — `maxFds`, `openFds`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `PythonProcessDown` | critical | 5m | — |
| `PythonHighCpu` | warning | 15m | — |
| `PythonHighMemory` | warning | 15m | — |
| `PythonFileDescriptorsExhausted` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:python_cpu_usage:rate5m` | `rate(process_cpu_seconds_total[5m])` |
| `instance:python_gc_collections:rate5m` | `sum without (generation) (rate(python_gc_collections_total[5m]))` |
