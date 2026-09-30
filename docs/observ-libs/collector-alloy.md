# Alloy  (`g.libs.collector.alloy`)

Dashboard uid `observ-viz-alloy` · 10 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `appended` | short | `sum(rate(prometheus_remote_write_wal_samples_appended_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `controllerQueue` | short | `sum(alloy_component_controller_evaluating{job=~"$job", instance=~"$instance"})` | — |
| `cpu` | short | `rate(alloy_resources_process_cpu_seconds_total{job=~"$job", instance=~"$instance"}[$__rate_interval])` | `instance:alloy_cpu_usage:rate5m` |
| `evalP99` | s | `histogram_quantile(0.99, sum by (le)(rate(alloy_component_evaluation_seconds_bucket{job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `evalRate` | ops | `sum(rate(alloy_component_evaluation_seconds_count{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `pending` | short | `sum(prometheus_remote_storage_samples_pending{job=~"$job", instance=~"$instance"})` | — |
| `rss` | bytes | `alloy_resources_process_resident_memory_bytes{job=~"$job", instance=~"$instance"}` | — |
| `running` | short | `sum(alloy_component_controller_running_components{job=~"$job", instance=~"$instance"})` | — |
| `sendFailed` | short | `sum(rate(prometheus_remote_storage_samples_failed_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `uptime` | s | `time() - alloy_resources_process_start_time_seconds{job=~"$job", instance=~"$instance"}` | — |

## Dashboard

- **Components** — `controllerQueue`, `evalP99`, `evalRate`, `running`
- **Remote write** — `appended`, `pending`, `sendFailed`
- **Resources** — `cpu`, `rss`, `uptime`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `AlloyNoRunningComponents` | critical | 5m | — |
| `AlloyRemoteWriteFailing` | warning | 15m | — |
| `AlloyRemoteWriteBacklog` | warning | 15m | — |
| `AlloyControllerQueueHigh` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:alloy_cpu_usage:rate5m` | `rate(alloy_resources_process_cpu_seconds_total[5m])` |
| `instance:alloy_samples_appended:rate5m` | `rate(prometheus_remote_write_wal_samples_appended_total[5m])` |
