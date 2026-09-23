# Django  (`g.libs.frameworks.django`)

Dashboard uid `observ-viz-django` · 15 signals · 3 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `ajax` | reqps | `sum(rate(django_http_ajax_requests_total{job=~"$job"}[$__rate_interval]))` | — |
| `byMethod` | reqps | `sum by (method) (rate(django_http_requests_total_by_method_total{job=~"$job"}[$__rate_interval]))` | — |
| `byStatus` | reqps | `sum by (status) (rate(django_http_responses_total_by_status_total{job=~"$job"}[$__rate_interval]))` | — |
| `byView` | reqps | `topk(10, sum by (view) (rate(django_http_requests_total_by_view_transport_method_total{job=~"$job"}[$__rate_interval])))` | — |
| `errorRate` | percentunit | `sum(rate(django_http_responses_total_by_status_total{job=~"$job", status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(django_http_responses_total_by_status_total{job=~"$job"}[$__rate_interval])), 0.001)` | — |
| `exceptionsByType` | ops | `sum by (type) (rate(django_http_exceptions_total_by_type_total{job=~"$job"}[$__rate_interval]))` | — |
| `exceptionsByView` | ops | `sum by (view) (rate(django_http_exceptions_total_by_view_total{job=~"$job"}[$__rate_interval]))` | — |
| `middlewareP95` | s | `histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_including_middlewares_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `p95` | s | `histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `p95ByView` | s | `topk(10, histogram_quantile(0.95, sum by (le, view) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job"}[$__rate_interval]))))` | — |
| `p99` | s | `histogram_quantile(0.99, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `requestBodies` | Bps | `sum(rate(django_http_requests_body_total_bytes_sum{job=~"$job"}[$__rate_interval]))` | — |
| `requests` | reqps | `sum(rate(django_http_requests_before_middlewares_total{job=~"$job"}[$__rate_interval]))` | — |
| `responseBodies` | Bps | `sum(rate(django_http_responses_body_total_bytes_sum{job=~"$job"}[$__rate_interval]))` | — |
| `viewTable` | reqps | `topk(20, sum by (view, method) (rate(django_http_requests_total_by_view_transport_method_total{job=~"$job"}[$__rate_interval])))` | — |

## Dashboard

- **Overview** — `ov1_requests`, `ov2_errors`, `ov3_p95`, `ov4_exceptions`
- **Requests** — `byMethod`, `byStatus`, `byView`, `latency`, `p95ByView`, `viewTable`
- **Exceptions and payloads** — `ajax`, `exceptionsByType`, `exceptionsByView`, `payloads`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `DjangoErrorRateHigh` | critical | 10m | — |
| `DjangoExceptions` | warning | 10m | — |
| `DjangoLatencyHigh` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job:django_http_requests:rate5m` | `sum by (job) (rate(django_http_requests_before_middlewares_total[5m]))` |
| `job:django_http_errors:ratio5m` | `sum by (job) (rate(django_http_responses_total_by_status_total{status=~"5.."}[5m])) / clamp_min(sum by (job) (rate(django_http_responses_total_by_status_total[5m])), 0.001)` |
