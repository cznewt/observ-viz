# HTTP server  (`g.libs.instrumentation.httpServer`)

Dashboard uid `observ-viz-http-server` · 13 signals · 3 alerts · 3 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `apdexTable` | reqps | `(topk(20, sum by (http_route, http_response_status_code) (rate(http_server_request_duration_seconds_count{job=~"$job"}[$__rate_interval])))) or (topk(20, sum by (handler, code) (rate(http_requests_total{job=~"$job"}[$__rate_interval]))))` | — |
| `byRoute` | reqps | `(topk(10, sum by (http_route) (rate(http_server_request_duration_seconds_count{job=~"$job"}[$__rate_interval])))) or (topk(10, sum by (handler) (rate(http_requests_total{job=~"$job"}[$__rate_interval]))))` | — |
| `clientErrorRate` | percentunit | `(sum(rate(http_server_request_duration_seconds_count{job=~"$job", http_response_status_code=~"4.."}[$__rate_interval])) / clamp_min(sum(rate(http_server_request_duration_seconds_count{job=~"$job"}[$__rate_interval])), 0.001)) or (sum(rate(http_requests_total{job=~"$job", code=~"4.."}[$__rate_interval])) / clamp_min(sum(rate(http_requests_total{job=~"$job"}[$__rate_interval])), 0.001))` | — |
| `errorRate` | percentunit | `(sum(rate(http_server_request_duration_seconds_count{job=~"$job", http_response_status_code=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(http_server_request_duration_seconds_count{job=~"$job"}[$__rate_interval])), 0.001)) or (sum(rate(http_requests_total{job=~"$job", code=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(http_requests_total{job=~"$job"}[$__rate_interval])), 0.001))` | — |
| `inFlight` | short | `(sum(http_server_active_requests{job=~"$job"})) or (sum(http_requests_in_flight{job=~"$job"}))` | — |
| `p50` | s | `(histogram_quantile(0.50, sum by (le) (rate(http_server_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))) or (histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval]))))` | — |
| `p95` | s | `(histogram_quantile(0.95, sum by (le) (rate(http_server_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))) or (histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval]))))` | — |
| `p99` | s | `(histogram_quantile(0.99, sum by (le) (rate(http_server_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))) or (histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval]))))` | — |
| `requestSize` | Bps | `sum(rate(http_server_request_body_size_bytes_sum{job=~"$job"}[$__rate_interval]))` | — |
| `responseSize` | Bps | `sum(rate(http_server_response_body_size_bytes_sum{job=~"$job"}[$__rate_interval]))` | — |
| `rps` | reqps | `(sum(rate(http_server_request_duration_seconds_count{job=~"$job"}[$__rate_interval]))) or (sum(rate(http_requests_total{job=~"$job"}[$__rate_interval])))` | — |
| `rpsByStatus` | reqps | `(sum by (http_response_status_code) (rate(http_server_request_duration_seconds_count{job=~"$job"}[$__rate_interval]))) or (sum by (code) (rate(http_requests_total{job=~"$job"}[$__rate_interval])))` | — |
| `slowestRoutes` | s | `(topk(10, histogram_quantile(0.95, sum by (le, http_route) (rate(http_server_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval]))))) or (topk(10, histogram_quantile(0.95, sum by (le, handler) (rate(http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))))` | — |

## Dashboard

- **Overview** — `ov1_rps`, `ov2_errors`, `ov3_clientErrors`, `ov4_p50`, `ov5_p95`, `ov6_inFlight`
- **Rate, errors, duration** — `duration`, `errors`, `inFlight`, `rpsByStatus`
- **Routes** — `apdexTable`, `byRoute`, `payloads`, `slowestRoutes`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `HttpServerErrorRateHigh` | critical | 10m | — |
| `HttpServerLatencyHigh` | warning | 15m | — |
| `HttpServerNoTraffic` | info | 30m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job:http_server_requests:rate5m` | `sum by (job) (rate(http_server_request_duration_seconds_count[5m]))` |
| `job:http_server_errors:ratio5m` | `sum by (job) (rate(http_server_request_duration_seconds_count{http_response_status_code=~"5.."}[5m])) / clamp_min(sum by (job) (rate(http_server_request_duration_seconds_count[5m])), 0.001)` |
| `job:http_server_duration_seconds:p95_5m` | `histogram_quantile(0.95, sum by (le, job) (rate(http_server_request_duration_seconds_bucket[5m])))` |
