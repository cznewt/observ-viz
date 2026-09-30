# WordPress  (`g.libs.frameworks.wordpress`)

Dashboard uid `observ-viz-wordpress` · 36 signals · 3 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `apacheBusy` | short | `sum(apache_workers{cluster=~"$cluster", namespace=~"$namespace", state="busy"})` | — |
| `apacheRequests` | reqps | `sum(rate(apache_accesses_total{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `comments` | short | `max by (exported_instance) (wordpress_comment_count{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `commentsGrowth` | short | `sum by (exported_instance) (delta(wordpress_comment_count{cluster=~"$cluster", namespace=~"$namespace"}[1h]))` | — |
| `containersReady` | short | `sum(max by (pod, container) (kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"$container"}))` | — |
| `cpu` | short | `sum by (container) (rate(container_cpu_usage_seconds_total{job=~".*cadvisor", cluster=~"$cluster", namespace=~"$namespace", container=~"$container"}[$__rate_interval]))` | — |
| `dbBufferPool` | bytes | `mysql_global_status_innodb_buffer_pool_bytes_data{cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `dbConnected` | short | `mysql_global_status_threads_connected{cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `dbQps` | ops | `rate(mysql_global_status_queries{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])` | — |
| `dbRunning` | short | `mysql_global_status_threads_running{cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `dbSlow` | ops | `rate(mysql_global_status_slow_queries{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])` | — |
| `errorRatio` | percentunit | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])), 0.001)` | — |
| `fpmAccepted` | reqps | `rate(phpfpm_accepted_connections{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])` | — |
| `fpmActive` | short | `phpfpm_active_processes{cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `fpmIdle` | short | `phpfpm_idle_processes{cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `fpmListenQueue` | short | `phpfpm_listen_queue{cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `fpmMaxChildren` | short | `increase(phpfpm_max_children_reached{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])` | — |
| `fpmPoolUtil` | percent | `100 * phpfpm_active_processes{cluster=~"$cluster", namespace=~"$namespace"} / clamp_min(phpfpm_total_processes{cluster=~"$cluster", namespace=~"$namespace"}, 1)` | — |
| `fpmSlow` | short | `increase(phpfpm_slow_requests{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])` | — |
| `fpmTotal` | short | `phpfpm_total_processes{cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `fpmUp` | short | `sum(phpfpm_up{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `ingressByStatus` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `ingressP95` | s | `histogram_quantile(0.95, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])))` | — |
| `logErrors` | short | `sum(count_over_time({namespace=~"$namespace", container=~"$container"} \|~ "PHP (Fatal\|Parse\|Warning)\|\\[error\\]" [$__auto]))` | — |
| `logs` | short | `{namespace=~"$namespace", container=~"$container"}` | — |
| `media` | short | `max by (exported_instance) (wordpress_media_count{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `memory` | bytes | `sum by (container) (container_memory_working_set_bytes{job=~".*cadvisor", cluster=~"$cluster", namespace=~"$namespace", container=~"$container"})` | — |
| `nginxConnections` | short | `sum(nginx_connections_active{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `nginxRequests` | reqps | `sum(rate(nginx_http_requests_total{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `pages` | short | `max by (exported_instance) (wordpress_page_count{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `plugins` | short | `max by (exported_instance) (wordpress_plugin_count{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `posts` | short | `max by (exported_instance) (wordpress_post_count{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `restarts` | short | `sum by (container) (increase(kube_pod_container_status_restarts_total{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"$container"}[1h]))` | — |
| `restartsRange` | short | `sum(increase(kube_pod_container_status_restarts_total{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"$container"}[$__range]))` | — |
| `themes` | short | `max by (exported_instance) (wordpress_theme_count{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `users` | short | `max by (exported_instance) (wordpress_user_count{cluster=~"$cluster", namespace=~"$namespace"})` | — |

## Dashboard

- **Overview** — `ov1_ready`, `ov2_fpm`, `ov3_pool`, `ov4_errors`, `ov5_p95`, `ov6_restarts`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `WordPressSiteDown` | critical | 5m | — |
| `WordPressPhpFpmMaxChildrenReached` | warning | 5m | — |
| `WordPressErrorRateHigh` | critical | 10m | — |
