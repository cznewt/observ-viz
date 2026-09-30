# Online store (demo app)  (`g.libs.demos.demoApp`)

Dashboard uid `observ-viz-demo-app` · 21 signals · 6 alerts · 8 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `active` | short | `sum by (namespace) (http_server_active_requests{job=~"$job", namespace=~"$namespace"})` | — |
| `byRoute` | reqps | `sum by (http_route) (rate(http_server_request_duration_seconds_count{job=~"$job", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `byStatus` | reqps | `sum by (http_response_status_code) (rate(http_server_request_duration_seconds_count{job=~"$job", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `checkoutByMethod` | ops | `sum by (payment_method) (rate(checkout_transactions_total{job=~"$job", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `checkoutRate` | ops | `sum by (status) (rate(checkout_transactions_total{job=~"$job", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `declineRatio` | percentunit | `sum by (namespace) (rate(checkout_transactions_total{job=~"$job", namespace=~"$namespace", status="declined"}[$__rate_interval])) / clamp_min(sum by (namespace) (rate(checkout_transactions_total{job=~"$job", namespace=~"$namespace"}[$__rate_interval])), 0.001)` | — |
| `errorRatio` | percentunit | `sum by (namespace) (rate(http_server_request_duration_seconds_count{job=~"$job", namespace=~"$namespace", http_response_status_code=~"5.."}[$__rate_interval])) / clamp_min(sum by (namespace) (rate(http_server_request_duration_seconds_count{job=~"$job", namespace=~"$namespace"}[$__rate_interval])), 0.001)` | — |
| `errorRatioMedian` | percentunit | `quantile_over_time(0.5, (sum by (namespace) (rate(http_server_request_duration_seconds_count{job=~"$job", namespace=~"$namespace", http_response_status_code=~"5.."}[$__rate_interval])) / clamp_min(sum by (namespace) (rate(http_server_request_duration_seconds_count{job=~"$job", namespace=~"$namespace"}[$__rate_interval])), 0.001))[1h:1m])` | — |
| `inventoryRate` | ops | `sum by (warehouse, operation) (rate(inventory_updates_total{job=~"$job", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `p50` | s | `histogram_quantile(0.50, sum by (namespace, le) (rate(http_server_request_duration_seconds_bucket{job=~"$job", namespace=~"$namespace"}[$__rate_interval])))` | — |
| `p95` | s | `histogram_quantile(0.95, sum by (namespace, le) (rate(http_server_request_duration_seconds_bucket{job=~"$job", namespace=~"$namespace"}[$__rate_interval])))` | `namespace:demo_http_request_duration_seconds:p95_rate5m` |
| `p95ByRoute` | s | `histogram_quantile(0.95, sum by (http_route, le) (rate(http_server_request_duration_seconds_bucket{job=~"$job", namespace=~"$namespace"}[$__rate_interval])))` | — |
| `p99` | s | `histogram_quantile(0.99, sum by (namespace, le) (rate(http_server_request_duration_seconds_bucket{job=~"$job", namespace=~"$namespace"}[$__rate_interval])))` | — |
| `paymentP50` | s | `histogram_quantile(0.50, sum by (le) (rate(checkout_payment_duration_seconds_bucket{job=~"$job", namespace=~"$namespace"}[$__rate_interval])))` | — |
| `paymentP95` | s | `histogram_quantile(0.95, sum by (payment_method, le) (rate(checkout_payment_duration_seconds_bucket{job=~"$job", namespace=~"$namespace"}[$__rate_interval])))` | — |
| `pendingShipments` | short | `sum by (namespace) (inventory_pending_shipments{job=~"$job", namespace=~"$namespace"})` | — |
| `queueDepth` | short | `sum by (namespace) (checkout_queue_depth{job=~"$job", namespace=~"$namespace"})` | — |
| `reservationP95` | s | `histogram_quantile(0.95, sum by (namespace, le) (rate(inventory_reservation_duration_seconds_bucket{job=~"$job", namespace=~"$namespace"}[$__rate_interval])))` | `namespace:inventory_reservation_duration_seconds:p95_rate5m` |
| `reserveFailRatio` | percentunit | `sum by (namespace) (rate(inventory_updates_total{job=~"$job", namespace=~"$namespace", operation="reserve_failed"}[$__rate_interval])) / clamp_min(sum by (namespace) (rate(inventory_updates_total{job=~"$job", namespace=~"$namespace"}[$__rate_interval])), 0.001)` | — |
| `rps` | reqps | `sum by (namespace) (rate(http_server_request_duration_seconds_count{job=~"$job", namespace=~"$namespace"}[$__rate_interval]))` | `namespace:demo_http_requests:rate5m` |
| `stockLevel` | short | `sum by (namespace) (inventory_stock_level{job=~"$job", namespace=~"$namespace"})` | — |

## Dashboard

- **Overview** — `a_rps`, `b_errors`, `c_p95`, `d_active`
- **Rate, errors, duration** — `a_status`, `b_errors`, `c_duration`, `d_active`
- **Routes** — `a_routes`, `b_routes`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `DemoAppDown` | critical | 2m | — |
| `DemoAppErrorRatioHigh` | critical | 2m | — |
| `DemoAppLatencyHigh` | warning | 2m | — |
| `DemoAppErrorRatioAnomalous` | warning | 2m | — |
| `DemoCheckoutDeclineRatioHigh` | warning | 15m | — |
| `DemoInventoryReservationFailuresHigh` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `namespace:demo_http_requests:rate5m` | `sum by (namespace) (rate(http_server_request_duration_seconds_count[5m]))` |
| `namespace:demo_http_errors:ratio_rate5m` | `sum by (namespace) (rate(http_server_request_duration_seconds_count{http_response_status_code=~"5.."}[5m])) / sum by (namespace) (rate(http_server_request_duration_seconds_count[5m]))` |
| `namespace:demo_http_errors_ratio_rate5m:median1h` | `quantile_over_time(0.5, namespace:demo_http_errors:ratio_rate5m[1h])` |
| `namespace:demo_http_request_duration_seconds:p95_rate5m` | `histogram_quantile(0.95, sum by (namespace, le) (rate(http_server_request_duration_seconds_bucket[5m])))` |
| `namespace:checkout_transactions_declined:ratio_rate5m` | `sum by (namespace) (rate(checkout_transactions_total{status="declined"}[5m])) / sum by (namespace) (rate(checkout_transactions_total[5m]))` |
| `namespace:checkout_payment_duration_seconds:p95_rate5m` | `histogram_quantile(0.95, sum by (namespace, le) (rate(checkout_payment_duration_seconds_bucket[5m])))` |
| `namespace:inventory_reservations_failed:ratio_rate5m` | `sum by (namespace) (rate(inventory_updates_total{operation="reserve_failed"}[5m])) / sum by (namespace) (rate(inventory_updates_total[5m]))` |
| `namespace:inventory_reservation_duration_seconds:p95_rate5m` | `histogram_quantile(0.95, sum by (namespace, le) (rate(inventory_reservation_duration_seconds_bucket[5m])))` |
