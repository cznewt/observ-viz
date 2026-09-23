# Process (base instrumentation)  (`g.libs.runtimes.process`)

Dashboard uid `observ-viz-process` · 14 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` | `job_instance:process_cpu_seconds:rate5m` |
| `down` | short | `sum(up{job=~"$job"} == 0) or vector(0)` | — |
| `fdUtil` | percent | `100 * process_open_fds{job=~"$job"} / process_max_fds{job=~"$job"}` | — |
| `maxFds` | short | `process_max_fds{job=~"$job"}` | — |
| `openFds` | short | `process_open_fds{job=~"$job"}` | — |
| `restarts1h` | short | `sum(changes(process_start_time_seconds{job=~"$job"}[1h])) or vector(0)` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job"}` | — |
| `scrapeDuration` | s | `scrape_duration_seconds{job=~"$job"}` | — |
| `scrapeSamples` | short | `scrape_samples_scraped{job=~"$job"}` | — |
| `targetTable` | short | `max by (job, instance) (up{job=~"$job"})` | — |
| `threads` | short | `process_threads{job=~"$job"}` | — |
| `up` | short | `sum(up{job=~"$job"})` | — |
| `uptime` | s | `time() - process_start_time_seconds{job=~"$job"}` | — |
| `vsz` | bytes | `process_virtual_memory_bytes{job=~"$job"}` | — |

## Dashboard

- **Overview** — `ov1_up`, `ov2_down`, `ov3_restarts`, `ov4_cpu`, `ov5_rss`, `ov6_fd`
- **Process** — `cpu`, `rss`, `threads`, `uptime`
- **File descriptors** — `fdUtil`, `openFds`
- **Scrape** — `scrapeDuration`, `scrapeSamples`, `targetTable`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `ProcessDown` | critical | 5m | — |
| `ProcessRestartLoop` | warning | 5m | — |
| `ProcessFileDescriptorsNearLimit` | warning | 10m | — |
| `ScrapeSlow` | info | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job_instance:process_cpu_seconds:rate5m` | `rate(process_cpu_seconds_total[5m])` |
| `job:process_resident_memory_bytes:sum` | `sum by (job) (process_resident_memory_bytes)` |
