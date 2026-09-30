# Envoy  (`g.libs.networking.envoy`)

Dashboard uid `observ-viz-envoy` · 30 signals · 4 alerts · 3 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `activeConnections` | short | `sum by (instance) (envoy_http_downstream_cx_active{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"})` | — |
| `certExpiryDays` | d | `min by (instance) (envoy_server_days_until_first_cert_expiring{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `clustersNoHealthy` | short | `count(max by (envoy_cluster_name) (envoy_cluster_membership_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}) > 0 and max by (envoy_cluster_name) (envoy_cluster_membership_healthy{cluster=~"$cluster", job=~"$job", instance=~"$instance"}) == 0) or vector(0)` | — |
| `concurrency` | short | `max by (instance) (envoy_server_concurrency{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `dsActiveRq` | short | `sum by (envoy_http_conn_manager_prefix) (envoy_http_downstream_rq_active{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"})` | — |
| `dsByClass` | reqps | `sum by (envoy_response_code_class) (rate(envoy_http_downstream_rq_xx{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"}[$__rate_interval]))` | — |
| `dsByHcm` | reqps | `sum by (envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"}[$__rate_interval]))` | — |
| `dsErrorRatio` | percentunit | `sum by (envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_xx{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin", envoy_response_code_class="5"}[$__rate_interval])) / clamp_min(sum by (envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"}[$__rate_interval])), 1e-9)` | — |
| `dsP95` | ms | `histogram_quantile(0.95, sum by (le, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_time_bucket{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"}[$__rate_interval])))` | — |
| `dsP99` | ms | `histogram_quantile(0.99, sum by (le, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_time_bucket{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"}[$__rate_interval])))` | — |
| `errorRatio` | percentunit | `sum by (instance) (rate(envoy_http_downstream_rq_xx{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin", envoy_response_code_class="5"}[$__rate_interval])) / clamp_min(sum by (instance) (rate(envoy_http_downstream_rq_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"}[$__rate_interval])), 1e-9)` | — |
| `healthyRatio` | percentunit | `bottomk(10, max by (envoy_cluster_name) (envoy_cluster_membership_healthy{cluster=~"$cluster", job=~"$job", instance=~"$instance"}) / max by (envoy_cluster_name) (envoy_cluster_membership_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"} > 0))` | — |
| `listenerCx` | short | `sum by (envoy_listener_address) (envoy_listener_downstream_cx_active{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `live` | short | `min by (instance) (envoy_server_live{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `membersHealthy` | short | `sum(envoy_cluster_membership_healthy{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `membersUnhealthy` | short | `sum(envoy_cluster_membership_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}) - sum(envoy_cluster_membership_healthy{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `membershipTable` | short | `max by (envoy_cluster_name) (envoy_cluster_membership_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}) - max by (envoy_cluster_name) (envoy_cluster_membership_healthy{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `memoryAllocated` | bytes | `max by (instance) (envoy_server_memory_allocated{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `memoryHeap` | bytes | `max by (instance) (envoy_server_memory_heap_size{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `p95` | ms | `histogram_quantile(0.95, sum by (le, instance) (rate(envoy_http_downstream_rq_time_bucket{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"}[$__rate_interval])))` | — |
| `requests` | reqps | `sum by (instance) (rate(envoy_http_downstream_rq_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_http_conn_manager_prefix!="admin"}[$__rate_interval]))` | — |
| `totalConnections` | short | `max by (instance) (envoy_server_total_connections{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `uptime` | s | `max by (instance) (envoy_server_uptime{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `usConnectFail` | ops | `sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_cx_connect_fail{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])) > 0` | — |
| `usCxActive` | short | `topk(10, sum by (envoy_cluster_name) (envoy_cluster_upstream_cx_active{cluster=~"$cluster", job=~"$job", instance=~"$instance"}))` | — |
| `usErrorRatio` | percentunit | `topk(10, sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_xx{cluster=~"$cluster", job=~"$job", instance=~"$instance", envoy_response_code_class="5"}[$__rate_interval])) / clamp_min(sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])), 1e-9))` | — |
| `usP95` | ms | `topk(10, histogram_quantile(0.95, sum by (le, envoy_cluster_name) (rate(envoy_cluster_upstream_rq_time_bucket{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))))` | — |
| `usRequests` | reqps | `topk(10, sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `usRetries` | ops | `sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_retry{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])) > 0` | — |
| `usTimeouts` | ops | `sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_timeout{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])) > 0` | — |

## Dashboard

- **Overview** — `ov1_live`, `ov2_requests`, `ov3_errorRatio`, `ov4_p95`, `ov5_activeConnections`, `ov6_clustersNoHealthy`
- **Downstream** — `dsActiveRq`, `dsByClass`, `dsByHcm`, `dsErrorRatio`, `dsLatency`, `listenerCx`
- **Upstream clusters** — `usConnectFail`, `usCxActive`, `usErrorRatio`, `usP95`, `usRequests`, `usRetries`, `usTimeouts`
- **Health** — `healthyRatio`, `membersHealthy`, `membersUnhealthy`, `membershipTable`
- **Server** — `certExpiryDays`, `concurrency`, `memory`, `totalConnections`, `uptime`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `EnvoyHigh5xxRatio` | warning | 10m | — |
| `EnvoyUpstreamClusterUnhealthyMembers` | warning | 15m | — |
| `EnvoyUpstreamClusterNoHealthyMembers` | critical | 5m | — |
| `EnvoyDown` | critical | 5m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job:envoy_http_downstream_rq:rate5m` | `sum by (cluster, job, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_total{envoy_http_conn_manager_prefix!="admin"}[5m]))` |
| `job:envoy_http_downstream_rq_5xx:ratio_rate5m` | `sum by (cluster, job, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_xx{envoy_response_code_class="5", envoy_http_conn_manager_prefix!="admin"}[5m])) / sum by (cluster, job, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_total{envoy_http_conn_manager_prefix!="admin"}[5m]))` |
| `job:envoy_cluster_upstream_rq_time:p95_5m` | `histogram_quantile(0.95, sum by (le, cluster, job, envoy_cluster_name) (rate(envoy_cluster_upstream_rq_time_bucket[5m])))` |
