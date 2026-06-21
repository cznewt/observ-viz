# JVM runtime  (`g.libs.runtimes.jvm`)

Dashboard uid `observ-viz-jvm` · 8 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `classesLoaded` | short | `jvm_classes_loaded_classes{job=~"$job"}` |
| `gcPauseAvg` | s | `rate(jvm_gc_pause_seconds_sum{job=~"$job"}[$__rate_interval]) / rate(jvm_gc_pause_seconds_count{job=~"$job"}[$__rate_interval])` |
| `gcRate` | ops | `rate(jvm_gc_pause_seconds_count{job=~"$job"}[$__rate_interval])` |
| `heapMax` | bytes | `sum without(area,id)(jvm_memory_max_bytes{area="heap",job=~"$job"})` |
| `heapUsed` | bytes | `sum without(area,id)(jvm_memory_used_bytes{area="heap",job=~"$job"})` |
| `nonheapUsed` | bytes | `sum without(area,id)(jvm_memory_used_bytes{area="nonheap",job=~"$job"})` |
| `threadsDaemon` | short | `jvm_threads_daemon_threads{job=~"$job"}` |
| `threadsLive` | short | `jvm_threads_live_threads{job=~"$job"}` |

## Dashboard

- **Memory** — `heapMax`, `heapUsed`, `nonheapUsed`
- **Garbage collection** — `gcPauseAvg`, `gcRate`
- **Threads** — `threadsDaemon`, `threadsLive`
- **Classes** — `classesLoaded`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `JvmProcessDown` | critical | 5m | — |
| `JvmHighHeapMemory` | warning | 15m | — |
| `JvmSlowGcPause` | warning | 15m | — |
| `JvmHighThreadCount` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:jvm_heap_utilisation:ratio` | `sum without(area,id)(jvm_memory_used_bytes{area="heap"}) / sum without(area,id)(jvm_memory_max_bytes{area="heap"})` |
| `instance:jvm_gc_rate:rate5m` | `rate(jvm_gc_pause_seconds_count[5m])` |
