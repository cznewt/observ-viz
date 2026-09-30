# NGINX  (`g.libs.webservers.nginx`)

Dashboard uid `observ-viz-nginx` · 45 signals · 7 alerts · 4 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `ctl_certExpiry` | dtdurations | `min by (host) (nginx_ingress_controller_ssl_expire_time_seconds{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) - time()` | — |
| `ctl_connActive` | short | `sum by (state) (nginx_ingress_controller_nginx_process_connections{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `ctl_connRate` | short | `sum by (state) (rate(nginx_ingress_controller_nginx_process_connections_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `ctl_controllers` | short | `count(nginx_ingress_controller_build_info{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `ctl_cpu` | short | `sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_cpu_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `ctl_nginxRequests` | reqps | `sum(rate(nginx_ingress_controller_nginx_process_requests_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `ctl_reloadAge` | dtdurations | `time() - max(nginx_ingress_controller_config_last_reload_successful_timestamp_seconds{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `ctl_reloadOk` | short | `min(nginx_ingress_controller_config_last_reload_successful{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `ctl_rss` | bytes | `sum by (controller_pod) (nginx_ingress_controller_nginx_process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `ctl_workers` | short | `sum by (controller_pod) (nginx_ingress_controller_nginx_process_num_procs{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `ing_byHost` | reqps | `sum by (host) (rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `ing_byIngress` | reqps | `sum by (namespace, ingress) (rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `ing_byMethod` | reqps | `sum by (method) (rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `ing_byPath` | reqps | `topk(10, sum by (host, path) (rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |
| `ing_byStatus` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `ing_bytesIn` | Bps | `sum(rate(nginx_ingress_controller_request_size_sum{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `ing_bytesOut` | Bps | `sum(rate(nginx_ingress_controller_response_size_sum{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `ing_err4xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress", status=~"4.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `ing_err5xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress", status=~"5.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `ing_hosts` | short | `count(count by (host) (nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}))` | — |
| `ing_ingresses` | short | `count(count by (namespace, ingress) (nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}))` | — |
| `ing_p50` | s | `histogram_quantile(0.50, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |
| `ing_p95` | s | `histogram_quantile(0.95, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |
| `ing_p99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |
| `ing_rate` | reqps | `sum(rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `ing_upstreamErrors` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress", status=~"502\|503\|504"}[$__rate_interval]))` | — |
| `ing_upstreamP99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_response_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |
| `ov_active` | short | `label_replace(label_replace(sum by (instance) (nginx_connections_active{job=~"$job", cluster=~"$cluster", instance=~"$instance"}), "target", "$1", "instance", "(.*)"), "kind", "server", "", "") or label_replace(label_replace(sum by (controller_pod) (nginx_ingress_controller_nginx_process_connections{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="active"}), "target", "$1", "controller_pod", "(.*)"), "kind", "ingress controller", "", "")` | — |
| `ov_err5xx` | percentunit | `label_replace(label_replace((sum by (controller_pod) (rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance", status=~"5.."}[$__rate_interval])) or 0 * sum by (controller_pod) (rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))) / clamp_min(sum by (controller_pod) (rate(nginx_ingress_controller_requests{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])), 1e-9), "target", "$1", "controller_pod", "(.*)"), "kind", "ingress controller", "", "")` | — |
| `ov_p95` | s | `label_replace(label_replace(histogram_quantile(0.95, sum by (le, controller_pod) (rate(nginx_ingress_controller_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))), "target", "$1", "controller_pod", "(.*)"), "kind", "ingress controller", "", "")` | — |
| `ov_requests` | reqps | `label_replace(label_replace(sum by (instance) (rate(nginx_http_requests_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])), "target", "$1", "instance", "(.*)"), "kind", "server", "", "") or label_replace(label_replace(sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_requests_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])), "target", "$1", "controller_pod", "(.*)"), "kind", "ingress controller", "", "")` | — |
| `ov_up` | short | `label_replace(label_replace(max by (instance) (nginx_up{job=~"$job", cluster=~"$cluster", instance=~"$instance"}), "target", "$1", "instance", "(.*)"), "kind", "server", "", "") or label_replace(label_replace(max by (controller_pod) (nginx_ingress_controller_build_info{job=~"$job", cluster=~"$cluster", instance=~"$instance"}), "target", "$1", "controller_pod", "(.*)"), "kind", "ingress controller", "", "")` | — |
| `srv_accepted` | ops | `(sum by (instance) (rate(nginx_connections_accepted{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))) or label_replace(sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_connections_total{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="accepted"}[$__rate_interval])), "instance", "$1", "controller_pod", "(.*)")` | — |
| `srv_active` | short | `(sum by (instance) (nginx_connections_active{job=~"$job", cluster=~"$cluster", instance=~"$instance"})) or label_replace(sum by (controller_pod) (nginx_ingress_controller_nginx_process_connections{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="active"}), "instance", "$1", "controller_pod", "(.*)")` | — |
| `srv_activeTotal` | short | `sum((sum by (instance) (nginx_connections_active{job=~"$job", cluster=~"$cluster", instance=~"$instance"})) or label_replace(sum by (controller_pod) (nginx_ingress_controller_nginx_process_connections{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="active"}), "instance", "$1", "controller_pod", "(.*)"))` | — |
| `srv_dropped` | ops | `(sum by (instance) (rate(nginx_connections_accepted{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) - sum by (instance) (rate(nginx_connections_handled{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))) or label_replace(sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_connections_total{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="accepted"}[$__rate_interval])) - sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_connections_total{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="handled"}[$__rate_interval])), "instance", "$1", "controller_pod", "(.*)")` | — |
| `srv_droppedTotal` | ops | `sum((sum by (instance) (rate(nginx_connections_accepted{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) - sum by (instance) (rate(nginx_connections_handled{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))) or label_replace(sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_connections_total{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="accepted"}[$__rate_interval])) - sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_connections_total{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="handled"}[$__rate_interval])), "instance", "$1", "controller_pod", "(.*)"))` | — |
| `srv_handled` | ops | `(sum by (instance) (rate(nginx_connections_handled{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))) or label_replace(sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_connections_total{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="handled"}[$__rate_interval])), "instance", "$1", "controller_pod", "(.*)")` | — |
| `srv_reading` | short | `(sum by (instance) (nginx_connections_reading{job=~"$job", cluster=~"$cluster", instance=~"$instance"})) or label_replace(sum by (controller_pod) (nginx_ingress_controller_nginx_process_connections{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="reading"}), "instance", "$1", "controller_pod", "(.*)")` | — |
| `srv_requests` | reqps | `(sum by (instance) (rate(nginx_http_requests_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))) or label_replace(sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_requests_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])), "instance", "$1", "controller_pod", "(.*)")` | — |
| `srv_requestsPerConnection` | short | `(sum by (instance) (rate(nginx_http_requests_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / clamp_min(sum by (instance) (rate(nginx_connections_handled{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])), 0.001)) or label_replace(sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_requests_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / clamp_min(sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_connections_total{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="handled"}[$__rate_interval])), 0.001), "instance", "$1", "controller_pod", "(.*)")` | — |
| `srv_requestsTotal` | reqps | `sum((sum by (instance) (rate(nginx_http_requests_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))) or label_replace(sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_requests_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])), "instance", "$1", "controller_pod", "(.*)"))` | — |
| `srv_up` | short | `(sum(nginx_up{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) or vector(0)) + (count(nginx_ingress_controller_build_info{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) or vector(0))` | — |
| `srv_waiting` | short | `(sum by (instance) (nginx_connections_waiting{job=~"$job", cluster=~"$cluster", instance=~"$instance"})) or label_replace(sum by (controller_pod) (nginx_ingress_controller_nginx_process_connections{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="waiting"}), "instance", "$1", "controller_pod", "(.*)")` | — |
| `srv_writing` | short | `(sum by (instance) (nginx_connections_writing{job=~"$job", cluster=~"$cluster", instance=~"$instance"})) or label_replace(sum by (controller_pod) (nginx_ingress_controller_nginx_process_connections{job=~"$job", cluster=~"$cluster", instance=~"$instance", state="writing"}), "instance", "$1", "controller_pod", "(.*)")` | — |

## Dashboard

- **Overview** — `ov1_up`, `ov2_requests`, `ov3_active`, `ov4_dropped`, `ov5_err5xx`, `ov6_reload`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `NginxDown` | critical | 5m | — |
| `NginxDroppingConnections` | warning | 10m | — |
| `IngressNginxHigh5xxRatio` | warning | 10m | — |
| `IngressNginxHighLatency` | warning | 15m | — |
| `IngressNginxUpstreamErrors` | warning | 10m | — |
| `IngressNginxConfigReloadFailed` | critical | 5m | — |
| `IngressNginxCertificateExpiringSoon` | warning | 1h | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:nginx_http_requests:rate5m` | `rate(nginx_http_requests_total[5m])` |
| `ingress:nginx_ingress_controller_requests:rate5m` | `sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests[5m]))` |
| `ingress:nginx_ingress_controller_5xx:ratio_rate5m` | `sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{status=~"5.."}[5m])) / sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests[5m]))` |
| `ingress:nginx_ingress_controller_request_duration_seconds:p99_5m` | `histogram_quantile(0.99, sum by (le, cluster, namespace, ingress) (rate(nginx_ingress_controller_request_duration_seconds_bucket[5m])))` |
