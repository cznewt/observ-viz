# Caddy  (`g.libs.webservers.caddy`)

Dashboard uid `observ-viz-caddy` · 11 signals · 2 alerts · 1 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `byCode` | reqps | `sum by (code) (rate(caddy_http_requests_total{job=~"$job"}[$__rate_interval]))` | — |
| `byHandler` | reqps | `topk(10, sum by (handler) (rate(caddy_http_requests_total{job=~"$job"}[$__rate_interval])))` | — |
| `errorRate` | percentunit | `sum(rate(caddy_http_requests_total{job=~"$job", code=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(caddy_http_requests_total{job=~"$job"}[$__rate_interval])), 0.001)` | — |
| `handlerErrors` | ops | `sum by (handler) (rate(caddy_http_request_errors_total{job=~"$job"}[$__rate_interval]))` | — |
| `handlerTable` | reqps | `topk(20, sum by (handler, code) (rate(caddy_http_requests_total{job=~"$job"}[$__rate_interval])))` | — |
| `inFlight` | short | `sum(caddy_http_requests_in_flight{job=~"$job"})` | — |
| `p95` | s | `histogram_quantile(0.95, sum by (le) (rate(caddy_http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `p99` | s | `histogram_quantile(0.99, sum by (le) (rate(caddy_http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `requestSize` | Bps | `sum(rate(caddy_http_request_size_bytes_sum{job=~"$job"}[$__rate_interval]))` | — |
| `requests` | reqps | `sum(rate(caddy_http_requests_total{job=~"$job"}[$__rate_interval]))` | — |
| `responseSize` | Bps | `sum(rate(caddy_http_response_size_bytes_sum{job=~"$job"}[$__rate_interval]))` | — |

## Dashboard

- **Overview** — `ov1_requests`, `ov2_errors`, `ov3_p95`, `ov4_inFlight`
- **Traffic** — `byCode`, `byHandler`, `duration`, `handlerErrors`, `handlerTable`, `payloads`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `CaddyErrorRateHigh` | warning | 10m | — |
| `CaddyLatencyHigh` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job:caddy_http_requests:rate5m` | `sum by (job) (rate(caddy_http_requests_total[5m]))` |
