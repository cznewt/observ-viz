# Rails  (`g.libs.frameworks.rails`)

Dashboard uid `observ-viz-rails` · 11 signals · 3 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `actionTable` | reqps | `topk(20, sum by (controller, action, status) (rate(rails_requests_total{job=~"$job"}[$__rate_interval])))` | — |
| `byAction` | reqps | `topk(10, sum by (controller, action) (rate(rails_requests_total{job=~"$job"}[$__rate_interval])))` | — |
| `byStatus` | reqps | `sum by (status) (rate(rails_requests_total{job=~"$job"}[$__rate_interval]))` | — |
| `dbRuntime` | s | `histogram_quantile(0.95, sum by (le) (rate(rails_db_runtime_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `errorRate` | percentunit | `sum(rate(rails_requests_total{job=~"$job", status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(rails_requests_total{job=~"$job"}[$__rate_interval])), 0.001)` | — |
| `extRuntime` | s | `histogram_quantile(0.95, sum by (le) (rate(rails_ext_service_runtime_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `p95` | s | `histogram_quantile(0.95, sum by (le) (rate(rails_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `p95ByAction` | s | `topk(10, histogram_quantile(0.95, sum by (le, controller, action) (rate(rails_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval]))))` | — |
| `p99` | s | `histogram_quantile(0.99, sum by (le) (rate(rails_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `requests` | reqps | `sum(rate(rails_requests_total{job=~"$job"}[$__rate_interval]))` | — |
| `viewRuntime` | s | `histogram_quantile(0.95, sum by (le) (rate(rails_view_runtime_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |

## Dashboard

- **Overview** — `ov1_requests`, `ov2_errors`, `ov3_p95`, `ov4_db`
- **Requests** — `actionTable`, `byAction`, `byStatus`, `duration`, `p95ByAction`
- **Where the time goes** — `breakdown`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `RailsErrorRateHigh` | critical | 10m | — |
| `RailsLatencyHigh` | warning | 15m | — |
| `RailsDatabaseTimeHigh` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job:rails_requests:rate5m` | `sum by (job) (rate(rails_requests_total[5m]))` |
| `job:rails_request_duration_seconds:p95_5m` | `histogram_quantile(0.95, sum by (le, job) (rate(rails_request_duration_seconds_bucket[5m])))` |
