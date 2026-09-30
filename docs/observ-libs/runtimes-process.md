# Process (base instrumentation)  (`g.libs.runtimes.process`)

Dashboard uid `observ-viz-process` · 14 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job", instance=~"$instance"}[$__rate_interval])` | `job_instance:process_cpu_seconds:rate5m` |
| `down` | short | `sum(up{job=~"$job", instance=~"$instance"} == 0) or vector(0)` | — |
| `fdUtil` | percent | `100 * process_open_fds{job=~"$job", instance=~"$instance"} / process_max_fds{job=~"$job", instance=~"$instance"}` | — |
| `maxFds` | short | `process_max_fds{job=~"$job", instance=~"$instance"}` | — |
| `openFds` | short | `process_open_fds{job=~"$job", instance=~"$instance"}` | — |
| `restarts1h` | short | `sum(changes(process_start_time_seconds{job=~"$job", instance=~"$instance"}[1h])) or vector(0)` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job", instance=~"$instance"}` | — |
| `scrapeDuration` | s | `scrape_duration_seconds{job=~"$job", instance=~"$instance"}` | — |
| `scrapeSamples` | short | `scrape_samples_scraped{job=~"$job", instance=~"$instance"}` | — |
| `targetTable` | short | `max by (job, instance) (up{job=~"$job", instance=~"$instance"})` | — |
| `threads` | short | `process_threads{job=~"$job", instance=~"$instance"}` | — |
| `up` | short | `sum(up{job=~"$job", instance=~"$instance"})` | — |
| `uptime` | s | `time() - process_start_time_seconds{job=~"$job", instance=~"$instance"}` | — |
| `vsz` | bytes | `process_virtual_memory_bytes{job=~"$job", instance=~"$instance"}` | — |

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
