# Pangolin  (`g.libs.networking.pangolin`)

Dashboard uid `observ-viz-pangolin` · 31 signals · 2 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `authFailed` | short | `sum by (cluster, namespace) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Failed to connect:` [$__auto]))` | — |
| `connErrors` | short | `sum by (cluster, error_type) (rate(newt_connection_errors_total{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `connecting` | short | `sum by (cluster, namespace) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Connecting to endpoint` [$__auto]))` | — |
| `connects` | short | `sum by (cluster, namespace) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Tunnel connection to server established` [$__auto]))` | — |
| `connectsRange` | short | `sum(count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Tunnel connection to server established` [$__range])) or vector(0)` | — |
| `cpu` | short | `sum by (cluster, namespace, pod) (rate(container_cpu_usage_seconds_total{job=~".*cadvisor", cluster=~"$cluster", namespace=~"$namespace", container=~"newt"}[$__rate_interval]))` | — |
| `exits` | short | `sum by (cluster, namespace) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Exiting\.\.\.` [$__auto]))` | — |
| `failingTargets` | short | `topk(20, sum by (cluster, target) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|= `Error connecting to target` \| regexp `dial tcp (?P<target>[^:]+:[0-9]+)` \| target != "" [$__range])))` | — |
| `healthFailed` | short | `sum by (cluster, namespace) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `health check failed` [$__auto]))` | — |
| `logs` | short | `{cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} !~ `Started tcp proxy to\|[╔╚║╠]\|Ping attempt [0-9]+ failed\|Initial reliable ping failed\|Failed to remove health file`` | — |
| `lost` | short | `sum by (cluster, namespace) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Connection to server lost` [$__auto]))` | — |
| `lostRange` | short | `sum(count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Connection to server lost\|Failed to connect:` [$__range])) or vector(0)` | — |
| `memory` | bytes | `sum by (cluster, namespace, pod) (container_memory_working_set_bytes{job=~".*cadvisor", cluster=~"$cluster", namespace=~"$namespace", container=~"newt"})` | — |
| `notReady` | short | `count(kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} == 0) or vector(0)` | — |
| `problems` | short | `sum by (cluster, namespace) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `^(ERROR\|FATAL)` [$__auto]))` | — |
| `proxyConns` | short | `sum by (cluster, protocol) (newt_proxy_active_connections{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `proxyDrops` | short | `sum by (cluster, protocol) (rate(newt_proxy_drops_total{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `ready` | short | `max by (cluster, namespace, pod) (kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"newt"})` | — |
| `readyPerCluster` | short | `sum by (cluster) (kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"newt"})` | — |
| `readyTotal` | short | `sum(kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"newt"})` | — |
| `restarts` | short | `sum by (cluster, namespace, pod) (increase(kube_pod_container_status_restarts_total{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"newt"}[1h]))` | — |
| `restartsRange` | short | `sum(increase(kube_pod_container_status_restarts_total{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"newt"}[$__range]))` | — |
| `targetErrors` | short | `sum by (cluster, namespace) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Error connecting to target\|Error accepting TCP connection` [$__auto]))` | — |
| `targetErrorsRange` | short | `sum(count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Error connecting to target\|Error accepting TCP connection` [$__range])) or vector(0)` | — |
| `tunnelBytes` | Bps | `sum by (cluster, direction) (rate(newt_tunnel_bytes_total{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `tunnelLatency` | s | `histogram_quantile(0.95, sum by (cluster, le) (rate(newt_tunnel_latency_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])))` | — |
| `tunnelLogs` | short | `{cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Tunnel connection to server established\|Websocket connected\|Connection to server lost\|Failed to connect:\|Exiting\.\.\.\|Newt version`` | — |
| `tunnelSessions` | short | `sum by (cluster, namespace, pod) (newt_tunnel_sessions{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `websocket` | short | `sum by (cluster, namespace) (count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"newt"} \|~ `Websocket connected` [$__auto]))` | — |
| `wsConnected` | short | `max by (cluster, namespace, pod) (newt_websocket_connected{cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `wsReconnects` | short | `sum by (cluster, reason) (rate(newt_websocket_reconnects_total{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]) + rate(newt_tunnel_reconnects_total{cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |

## Dashboard

- **Status** — `s1_ready`, `s2_notready`, `s3_restarts`, `s4_connects`, `s5_lost`, `s6_targets`
- **Clusters** — `c1_perCluster`, `c2_pods`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `PangolinNewtDown` | critical | 5m | — |
| `PangolinNewtCrashLooping` | warning | 10m | — |
