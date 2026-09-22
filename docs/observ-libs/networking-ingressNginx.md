# Ingress NGINX  (`g.libs.networking.ingressNginx`)

Dashboard uid `observ-viz-ingress-nginx` · 27 signals · 5 alerts · 3 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `byHost` | reqps | `sum by (host) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `byIngress` | reqps | `sum by (namespace, ingress) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `byMethod` | reqps | `sum by (method) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `byPath` | reqps | `topk(10, sum by (host, path) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |
| `byStatus` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `bytesIn` | Bps | `sum(rate(nginx_ingress_controller_request_size_sum{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `bytesOut` | Bps | `sum(rate(nginx_ingress_controller_response_size_sum{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `controller_certExpiry` | dtdurations | `min by (host) (nginx_ingress_controller_ssl_expire_time_seconds{cluster=~"$cluster"}) - time()` | — |
| `controller_connActive` | short | `sum by (state) (nginx_ingress_controller_nginx_process_connections{cluster=~"$cluster"})` | — |
| `controller_connRate` | short | `sum by (state) (rate(nginx_ingress_controller_nginx_process_connections_total{cluster=~"$cluster"}[$__rate_interval]))` | — |
| `controller_controllers` | short | `count(nginx_ingress_controller_build_info{cluster=~"$cluster"})` | — |
| `controller_cpu` | short | `sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_cpu_seconds_total{cluster=~"$cluster"}[$__rate_interval]))` | — |
| `controller_nginxRequests` | reqps | `sum(rate(nginx_ingress_controller_nginx_process_requests_total{cluster=~"$cluster"}[$__rate_interval]))` | — |
| `controller_reloadAge` | dtdurations | `time() - max(nginx_ingress_controller_config_last_reload_successful_timestamp_seconds{cluster=~"$cluster"})` | — |
| `controller_reloadOk` | short | `min(nginx_ingress_controller_config_last_reload_successful{cluster=~"$cluster"})` | — |
| `controller_rss` | bytes | `sum by (controller_pod) (nginx_ingress_controller_nginx_process_resident_memory_bytes{cluster=~"$cluster"})` | — |
| `controller_workers` | short | `sum by (controller_pod) (nginx_ingress_controller_nginx_process_num_procs{cluster=~"$cluster"})` | — |
| `err4xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress", status=~"4.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `err5xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress", status=~"5.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `hosts` | short | `count(count by (host) (nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}))` | — |
| `ingresses` | short | `count(count by (namespace, ingress) (nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}))` | — |
| `p50` | s | `histogram_quantile(0.50, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |
| `p95` | s | `histogram_quantile(0.95, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |
| `p99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |
| `rate` | reqps | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval]))` | — |
| `upstreamErrors` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress", status=~"502\|503\|504"}[$__rate_interval]))` | — |
| `upstreamP99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_response_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"}[$__rate_interval])))` | — |

## Dashboard

- **Overview** — `i01_rate`, `i02_err5xx`, `i03_err4xx`, `i04_p99`, `i05_hosts`, `i06_ingresses`, `i07_reloadOk`, `i08_reloadAge`, `i09_controllers`
- **Traffic** — `i10_byIngress`, `i11_byStatus`, `i12_byHost`, `i13_byPath`, `i14_errors`, `i15_latency`, `i16_upstream`, `i17_upstreamErrors`, `i18_bytes`, `i19_byMethod`
- **Controller** — `c01_connections`, `c02_connRate`, `c03_requests`, `c04_cpu`, `c05_rss`, `c06_workers`, `c07_certs`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `IngressNginxHigh5xxRatio` | warning | 10m | — |
| `IngressNginxHighLatency` | warning | 15m | — |
| `IngressNginxUpstreamErrors` | warning | 10m | — |
| `IngressNginxConfigReloadFailed` | critical | 5m | — |
| `IngressNginxCertificateExpiringSoon` | warning | 1h | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `ingress:nginx_ingress_controller_requests:rate5m` | `sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests[5m]))` |
| `ingress:nginx_ingress_controller_5xx:ratio_rate5m` | `sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{status=~"5.."}[5m])) / sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests[5m]))` |
| `ingress:nginx_ingress_controller_request_duration_seconds:p99_5m` | `histogram_quantile(0.99, sum by (le, cluster, namespace, ingress) (rate(nginx_ingress_controller_request_duration_seconds_bucket[5m])))` |
