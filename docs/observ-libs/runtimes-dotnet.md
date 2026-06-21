# .NET runtime  (`g.libs.runtimes.dotnet`)

Dashboard uid `observ-viz-dotnet` · 8 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` | `instance:dotnet_cpu_utilisation:rate5m` |
| `exceptions` | short | `rate(dotnet_exceptions_total{job=~"$job"}[$__rate_interval])` | `instance:dotnet_exceptions:rate5m` |
| `gcCollections` | ops | `sum without(generation)(rate(dotnet_collection_count_total{job=~"$job"}[$__rate_interval]))` | — |
| `gcHeap` | bytes | `dotnet_total_memory_bytes{job=~"$job"}` | — |
| `jitMethods` | short | `rate(dotnet_jit_method_total{job=~"$job"}[$__rate_interval])` | — |
| `processThreads` | short | `process_num_threads{job=~"$job"}` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job"}` | — |
| `threadpool` | short | `dotnet_threadpool_num_threads{job=~"$job"}` | — |

## Dashboard

- **Garbage collection** — `cpu`, `gcCollections`, `gcHeap`, `rss`
- **Threads** — `processThreads`, `threadpool`
- **Exceptions** — `exceptions`
- **JIT** — `jitMethods`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `DotnetDown` | critical | 5m | — |
| `DotnetHighExceptionRate` | warning | 15m | — |
| `DotnetHighCpu` | warning | 15m | — |
| `DotnetThreadPoolStarvation` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:dotnet_exceptions:rate5m` | `rate(dotnet_exceptions_total[5m])` |
| `instance:dotnet_cpu_utilisation:rate5m` | `rate(process_cpu_seconds_total[5m])` |
