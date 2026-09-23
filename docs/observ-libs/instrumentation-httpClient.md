# HTTP client  (`g.libs.instrumentation.httpClient`)

Dashboard uid `observ-viz-http-client` · 13 signals · 2 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `active` | short | `sum(http_client_active_requests{job=~"$job"})` | — |
| `byPeer` | reqps | `sum by (server_address) (rate(http_client_request_duration_seconds_count{job=~"$job"}[$__rate_interval]))` | — |
| `connectionDuration` | s | `histogram_quantile(0.95, sum by (le) (rate(http_client_connection_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `errorRate` | percentunit | `sum(rate(http_client_request_duration_seconds_count{job=~"$job", http_response_status_code=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(http_client_request_duration_seconds_count{job=~"$job"}[$__rate_interval])), 0.001)` | — |
| `errorsByPeer` | reqps | `sum by (server_address) (rate(http_client_request_duration_seconds_count{job=~"$job", http_response_status_code=~"5.."}[$__rate_interval]))` | — |
| `openConnections` | short | `sum by (server_address) (http_client_open_connections{job=~"$job"})` | — |
| `p95` | s | `histogram_quantile(0.95, sum by (le) (rate(http_client_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `p95ByPeer` | s | `histogram_quantile(0.95, sum by (le, server_address) (rate(http_client_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `p99` | s | `histogram_quantile(0.99, sum by (le) (rate(http_client_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `peerTable` | reqps | `topk(20, sum by (server_address, http_response_status_code) (rate(http_client_request_duration_seconds_count{job=~"$job"}[$__rate_interval])))` | — |
| `requestSize` | Bps | `sum(rate(http_client_request_body_size_bytes_sum{job=~"$job"}[$__rate_interval]))` | — |
| `responseSize` | Bps | `sum(rate(http_client_response_body_size_bytes_sum{job=~"$job"}[$__rate_interval]))` | — |
| `rps` | reqps | `sum(rate(http_client_request_duration_seconds_count{job=~"$job"}[$__rate_interval]))` | — |

## Dashboard

- **Overview** — `ov1_rps`, `ov2_errors`, `ov3_p95`, `ov4_active`
- **Calls** — `byPeer`, `duration`, `errorsByPeer`, `p95ByPeer`
- **Connections** — `connectionDuration`, `openConnections`, `payloads`, `peerTable`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `HttpClientErrorRateHigh` | warning | 10m | — |
| `HttpClientLatencyHigh` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job_peer:http_client_requests:rate5m` | `sum by (job, server_address) (rate(http_client_request_duration_seconds_count[5m]))` |
| `job_peer:http_client_duration_seconds:p95_5m` | `histogram_quantile(0.95, sum by (le, job, server_address) (rate(http_client_request_duration_seconds_bucket[5m])))` |
