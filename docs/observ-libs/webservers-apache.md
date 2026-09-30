# Apache HTTP Server  (`g.libs.webservers.apache`)

Dashboard uid `observ-viz-apache` · 15 signals · 2 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `avgDuration` | ms | `sum by (instance) (rate(apache_duration_ms_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])) / clamp_min(sum by (instance) (rate(apache_accesses_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])), 1e-9)` | — |
| `busyWorkers` | short | `sum by (instance) (apache_workers{cluster=~"$cluster", job=~"$job", instance=~"$instance", state="busy"})` | — |
| `bytesPerRequest` | bytes | `sum by (instance) (rate(apache_sent_kilobytes_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])) * 1024 / clamp_min(sum by (instance) (rate(apache_accesses_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])), 1e-9)` | — |
| `connections` | short | `sum by (state) (apache_connections{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `connectionsTotal` | short | `sum by (instance) (apache_connections{cluster=~"$cluster", job=~"$job", instance=~"$instance", state="total"})` | — |
| `cpuLoad` | percent | `max by (instance) (apache_cpuload{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `idleWorkers` | short | `sum by (instance) (apache_workers{cluster=~"$cluster", job=~"$job", instance=~"$instance", state="idle"})` | — |
| `openSlots` | short | `sum by (instance) (apache_scoreboard{cluster=~"$cluster", job=~"$job", instance=~"$instance", state="open_slot"})` | — |
| `processes` | short | `sum by (state) (apache_processes{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `requests` | reqps | `sum by (instance) (rate(apache_accesses_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `scoreboard` | short | `sum by (state) (apache_scoreboard{cluster=~"$cluster", job=~"$job", instance=~"$instance", state!="open_slot"})` | — |
| `traffic` | Bps | `sum by (instance) (rate(apache_sent_kilobytes_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])) * 1024` | — |
| `up` | short | `min by (instance) (apache_up{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `uptime` | s | `max by (instance) (apache_uptime_seconds_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `workerSaturation` | percentunit | `sum by (instance) (apache_workers{cluster=~"$cluster", job=~"$job", instance=~"$instance", state="busy"}) / clamp_min(sum by (instance) (apache_workers{cluster=~"$cluster", job=~"$job", instance=~"$instance", state="busy"}) + sum by (instance) (apache_workers{cluster=~"$cluster", job=~"$job", instance=~"$instance", state="idle"}), 1)` | — |

## Dashboard

- **Overview** — `ov1_up`, `ov2_requests`, `ov3_traffic`, `ov4_avgDuration`, `ov5_workerSaturation`, `ov6_uptime`
- **Requests & traffic** — `avgDuration`, `bytesPerRequest`, `cpuLoad`, `requests`, `traffic`
- **Workers** — `openSlots`, `processes`, `scoreboard`, `workerSaturation`, `workers`
- **Connections** — `connections`, `connectionsTotal`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `ApacheDown` | critical | 5m | — |
| `ApacheWorkersSaturated` | warning | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:apache_accesses:rate5m` | `sum by (cluster, job, instance) (rate(apache_accesses_total[5m]))` |
| `instance:apache_workers_busy:ratio` | `sum by (cluster, job, instance) (apache_workers{state="busy"}) / clamp_min(sum by (cluster, job, instance) (apache_workers{state=~"busy\|idle"}), 1)` |
