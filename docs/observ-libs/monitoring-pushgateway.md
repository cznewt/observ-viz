# Pushgateway  (`g.libs.monitoring.pushgateway`)

Dashboard uid `observ-viz-pushgateway` · 23 signals · 3 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `sum by (instance) (rate(process_cpu_seconds_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `failingGroups` | short | `count(push_failure_time_seconds{cluster=~"$cluster", job=~"$pushed_job"} > push_time_seconds{cluster=~"$cluster", job=~"$pushed_job"}) or vector(0)` | — |
| `fds` | short | `max by (instance) (process_open_fds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `gcDuration` | s | `max by (instance) (go_gc_duration_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance", quantile="1"})` | — |
| `goroutines` | short | `max by (instance) (go_goroutines{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `groupAge` | s | `time() - push_time_seconds{cluster=~"$cluster", job=~"$pushed_job"}` | `group:push_time_seconds:age_seconds` |
| `groupFailureAge` | s | `time() - (push_failure_time_seconds{cluster=~"$cluster", job=~"$pushed_job"} > 0)` | — |
| `groups` | short | `count(push_time_seconds{cluster=~"$cluster", job=~"$pushed_job"})` | — |
| `heap` | bytes | `max by (instance) (go_memstats_heap_inuse_bytes{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `memory` | bytes | `max by (instance) (process_resident_memory_bytes{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `oldestPush` | s | `max(time() - push_time_seconds{cluster=~"$cluster", job=~"$pushed_job"})` | — |
| `pushByMethod` | reqps | `sum by (method) (rate(pushgateway_http_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", handler="push"}[$__rate_interval]))` | — |
| `pushDuration` | s | `max by (method, quantile) (pushgateway_http_push_duration_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `pushDurationP90` | s | `max by (instance) (pushgateway_http_push_duration_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance", quantile="0.9"})` | — |
| `pushErrors` | reqps | `sum by (instance) (rate(pushgateway_http_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", handler="push", code!~"2.."}[$__rate_interval])) or vector(0)` | — |
| `pushRate` | reqps | `sum by (instance) (rate(pushgateway_http_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", handler="push"}[$__rate_interval]))` | — |
| `pushSize` | bytes | `max by (method, quantile) (pushgateway_http_push_size_bytes{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `pushThroughput` | Bps | `sum by (method) (rate(pushgateway_http_push_size_bytes_sum{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `requestsByCode` | reqps | `sum by (handler, code) (rate(pushgateway_http_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `rss` | bytes | `max by (instance) (process_resident_memory_bytes{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `staleGroups` | short | `count((time() - push_time_seconds{cluster=~"$cluster", job=~"$pushed_job"}) > 3600) or vector(0)` | — |
| `staleTable` | s | `(time() - push_time_seconds{cluster=~"$cluster", job=~"$pushed_job"}) > 3600` | — |
| `version` | short | `max by (instance, version) (pushgateway_build_info{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |

## Dashboard

- **Overview** — `ov1_groups`, `ov2_stale`, `ov3_failing`, `ov4_oldest`, `ov5_pushRate`, `ov6_pushErrors`
- **Freshness** — `fr1_groups`, `fr2_groupAge`, `fr3_stale`, `fr4_failureAge`
- **Pushes** — `pushByMethod`, `pushDuration`, `pushErrors`, `pushRate`, `pushSize`, `pushThroughput`, `requestsByCode`
- **Process** — `cpu`, `fds`, `gcDuration`, `goroutines`, `heap`, `rss`, `version`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `PushgatewayDown` | warning | 5m | — |
| `PushgatewayGroupStale` | warning | 5m | — |
| `PushgatewayPushFailures` | warning | 5m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `group:push_time_seconds:age_seconds` | `time() - push_time_seconds` |
| `job:pushgateway_http_push_requests:rate5m` | `sum by (cluster, job, instance, code) (rate(pushgateway_http_requests_total{handler="push"}[5m]))` |
