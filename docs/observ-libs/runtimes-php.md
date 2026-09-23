# PHP runtime  (`g.libs.runtimes.php`)

Dashboard uid `observ-viz-php` · 13 signals · 4 alerts · 1 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `accepted` | reqps | `rate(phpfpm_accepted_connections{job=~"$job"}[$__rate_interval])` | — |
| `active` | short | `phpfpm_active_processes{job=~"$job"}` | — |
| `idle` | short | `phpfpm_idle_processes{job=~"$job"}` | — |
| `listenQueue` | short | `phpfpm_listen_queue{job=~"$job"}` | — |
| `listenQueueLen` | short | `phpfpm_listen_queue_length{job=~"$job"}` | — |
| `maxActive` | short | `phpfpm_max_active_processes{job=~"$job"}` | — |
| `maxChildren` | short | `increase(phpfpm_max_children_reached{job=~"$job"}[$__rate_interval])` | — |
| `maxListenQueue` | short | `phpfpm_max_listen_queue{job=~"$job"}` | — |
| `poolUtil` | percent | `100 * phpfpm_active_processes{job=~"$job"} / clamp_min(phpfpm_total_processes{job=~"$job"}, 1)` | — |
| `slowRequests` | short | `increase(phpfpm_slow_requests{job=~"$job"}[$__rate_interval])` | — |
| `total` | short | `phpfpm_total_processes{job=~"$job"}` | — |
| `up` | short | `sum(phpfpm_up{job=~"$job"})` | — |
| `uptime` | s | `phpfpm_start_since{job=~"$job"}` | — |

## Dashboard

- **Overview** — `ov1_up`, `ov2_active`, `ov3_util`, `ov4_queue`, `ov5_slow`, `ov6_uptime`
- **Worker pool** — `accepted`, `maxChildren`, `poolUtil`, `processes`
- **Queue and slow requests** — `listenQueue`, `slowRequests`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `PhpFpmDown` | critical | 5m | — |
| `PhpFpmMaxChildrenReached` | warning | 5m | — |
| `PhpFpmListenQueueBacklog` | warning | 10m | — |
| `PhpFpmSlowRequests` | info | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:phpfpm_pool_usage:ratio` | `phpfpm_active_processes / clamp_min(phpfpm_total_processes, 1)` |
