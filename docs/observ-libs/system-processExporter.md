# Process groups  (`g.libs.system.processExporter`)

Dashboard uid `observ-viz-process-exporter` · 15 signals · 3 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"}[$__rate_interval]))` | — |
| `ctxSwitches` | ops | `sum by (instance, groupname, ctxswitchtype) (rate(namedprocess_namegroup_context_switches_total{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"}[$__rate_interval]))` | — |
| `fdRatio` | percentunit | `max by (instance, groupname) (namedprocess_namegroup_worst_fd_ratio{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"})` | — |
| `fds` | short | `sum by (instance, groupname) (namedprocess_namegroup_open_filedesc{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"})` | — |
| `ioRead` | Bps | `sum by (instance, groupname) (rate(namedprocess_namegroup_read_bytes_total{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"}[$__rate_interval]))` | — |
| `ioWrite` | Bps | `sum by (instance, groupname) (rate(namedprocess_namegroup_write_bytes_total{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"}[$__rate_interval]))` | — |
| `majFaults` | short | `sum by (instance, groupname) (rate(namedprocess_namegroup_major_page_faults_total{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"}[$__rate_interval]))` | — |
| `procs` | short | `sum by (instance, groupname) (namedprocess_namegroup_num_procs{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"})` | — |
| `rss` | bytes | `sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{groupname=~".*", memtype="resident", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"})` | — |
| `scrapeErrors` | short | `sum by (instance) (rate(namedprocess_scrape_errors{cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) + rate(namedprocess_scrape_partial_errors{cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) + rate(namedprocess_scrape_procread_errors{cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `states` | short | `sum by (instance, groupname, state) (namedprocess_namegroup_states{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"})` | — |
| `threads` | short | `sum by (instance, groupname) (namedprocess_namegroup_num_threads{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"})` | — |
| `topCpu` | short | `topk(10, sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total{cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])))` | — |
| `topRss` | bytes | `topk(10, sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{memtype="resident", cluster=~"$cluster", instance=~"$instance"}))` | — |
| `uptime` | dtdurations | `time() - min by (instance, groupname) (namedprocess_namegroup_oldest_start_time_seconds{groupname=~".*", cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"})` | — |

## Dashboard

- **Overview** — `h01_procs`, `h02_threads`, `h03_fds`, `h04_fdRatio`, `h05_uptime`
- **Usage** — `h11_cpu`, `h12_rss`, `h13_io`, `h14_majFaults`, `h15_ctx`, `h16_states`
- **Hosts** — `t01_topCpu`, `t02_topRss`, `t03_scrapeErrors`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `ProcessGroupFdRatioHigh` | warning | 15m | — |
| `ProcessGroupGone` | warning | 10m | — |
| `ProcessExporterScrapeErrors` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance_groupname:namedprocess_cpu:rate5m` | `sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total[5m]))` |
| `instance_groupname:namedprocess_rss:sum` | `sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{memtype="resident"})` |
