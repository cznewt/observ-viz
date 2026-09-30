# Traefik  (`g.libs.networking.traefik`)

Dashboard uid `observ-viz-traefik` · 28 signals · 5 alerts · 3 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `certExpiry` | dtdurations | `min by (cn, sans) (traefik_tls_certs_not_after{cluster=~"$cluster", job=~"$job", instance=~"$instance"}) - time()` | — |
| `certMinExpiry` | dtdurations | `min(traefik_tls_certs_not_after{cluster=~"$cluster", job=~"$job", instance=~"$instance"}) - time()` | — |
| `certs` | short | `count(count by (cn, sans) (traefik_tls_certs_not_after{cluster=~"$cluster", job=~"$job", instance=~"$instance"}))` | — |
| `configReloadOk` | short | `min by (instance) (traefik_config_last_reload_success{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `configReloads` | short | `sum by (instance) (increase(traefik_config_reloads_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `epByCode` | reqps | `sum by (code) (rate(traefik_entrypoint_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `epBytesIn` | Bps | `sum by (entrypoint) (rate(traefik_entrypoint_requests_bytes_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `epBytesOut` | Bps | `sum by (entrypoint) (rate(traefik_entrypoint_responses_bytes_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `epConnections` | short | `sum by (entrypoint, protocol) (traefik_open_connections{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `epErrorRatio` | percentunit | `sum by (entrypoint) (rate(traefik_entrypoint_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", code=~"5.."}[$__rate_interval])) / clamp_min(sum by (entrypoint) (rate(traefik_entrypoint_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])), 1e-9)` | — |
| `epP95` | s | `histogram_quantile(0.95, sum by (le, entrypoint) (rate(traefik_entrypoint_request_duration_seconds_bucket{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `epP99` | s | `histogram_quantile(0.99, sum by (le, entrypoint) (rate(traefik_entrypoint_request_duration_seconds_bucket{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `epRequests` | reqps | `sum by (entrypoint) (rate(traefik_entrypoint_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `epTls` | reqps | `sum by (tls_version) (rate(traefik_entrypoint_requests_tls_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `errorRatio` | percentunit | `sum by (instance) (rate(traefik_entrypoint_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", code=~"5.."}[$__rate_interval])) / clamp_min(sum by (instance) (rate(traefik_entrypoint_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])), 1e-9)` | — |
| `openConnections` | short | `sum by (instance) (traefik_open_connections{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `p95` | s | `histogram_quantile(0.95, sum by (le, instance) (rate(traefik_entrypoint_request_duration_seconds_bucket{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `requests` | reqps | `sum by (instance) (rate(traefik_entrypoint_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `routerErrors` | reqps | `topk(10, sum by (router) (rate(traefik_router_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", code=~"5.."}[$__rate_interval])))` | — |
| `routerP95` | s | `topk(10, histogram_quantile(0.95, sum by (le, router) (rate(traefik_router_request_duration_seconds_bucket{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))))` | — |
| `routerRequests` | reqps | `topk(10, sum by (router) (rate(traefik_router_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `routerTable` | reqps | `sum by (router, service, code) (rate(traefik_router_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `serverTable` | short | `max by (service, url) (traefik_service_server_up{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `serversDown` | short | `count(traefik_service_server_up{cluster=~"$cluster", job=~"$job", instance=~"$instance"} == 0) or vector(0)` | — |
| `svcErrorRatio` | percentunit | `topk(10, sum by (service) (rate(traefik_service_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance", code=~"5.."}[$__rate_interval])) / clamp_min(sum by (service) (rate(traefik_service_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])), 1e-9))` | — |
| `svcP95` | s | `topk(10, histogram_quantile(0.95, sum by (le, service) (rate(traefik_service_request_duration_seconds_bucket{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))))` | — |
| `svcRequests` | reqps | `topk(10, sum by (service) (rate(traefik_service_requests_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `svcRetries` | ops | `sum by (service) (rate(traefik_service_retries_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |

## Dashboard

- **Overview** — `ov1_requests`, `ov2_errorRatio`, `ov3_p95`, `ov4_openConnections`, `ov5_configReloadOk`, `ov6_serversDown`
- **Entrypoints** — `configReloads`, `epByCode`, `epBytes`, `epConnections`, `epErrorRatio`, `epLatency`, `epRequests`, `epTls`
- **Routers** — `routerErrors`, `routerP95`, `routerRequests`, `routerTable`
- **Services** — `serverTable`, `svcErrorRatio`, `svcP95`, `svcRequests`, `svcRetries`
- **TLS certificates** — `certExpiry`, `certMinExpiry`, `certs`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `TraefikTLSCertificatesExpiring` | critical | 5m | — |
| `TraefikTLSCertificatesExpiringSoon` | warning | 5m | — |
| `TraefikHighHttp5xxErrorRate` | warning | 5m | — |
| `TraefikBackendServerDown` | warning | 5m | — |
| `TraefikConfigReloadFailed` | warning | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job:traefik_entrypoint_requests:rate5m` | `sum by (cluster, job, entrypoint) (rate(traefik_entrypoint_requests_total[5m]))` |
| `job:traefik_service_requests_5xx:ratio_rate5m` | `sum by (cluster, job, service) (rate(traefik_service_requests_total{code=~"5.."}[5m])) / sum by (cluster, job, service) (rate(traefik_service_requests_total[5m]))` |
| `job:traefik_entrypoint_request_duration_seconds:p95_5m` | `histogram_quantile(0.95, sum by (le, cluster, job, entrypoint) (rate(traefik_entrypoint_request_duration_seconds_bucket[5m])))` |
