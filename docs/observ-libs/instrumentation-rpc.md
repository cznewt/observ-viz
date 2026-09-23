# gRPC  (`g.libs.instrumentation.rpc`)

Dashboard uid `observ-viz-rpc` · 14 signals · 3 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `byCode` | reqps | `sum by (grpc_code) (rate(grpc_server_handled_total{job=~"$job"}[$__rate_interval]))` | — |
| `byMethod` | reqps | `topk(10, sum by (grpc_service, grpc_method) (rate(grpc_server_started_total{job=~"$job"}[$__rate_interval])))` | — |
| `clientHandled` | reqps | `sum by (grpc_code) (rate(grpc_client_handled_total{job=~"$job"}[$__rate_interval]))` | — |
| `clientP95` | s | `histogram_quantile(0.95, sum by (le) (rate(grpc_client_handling_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `codeTable` | reqps | `topk(20, sum by (grpc_service, grpc_method, grpc_code) (rate(grpc_server_handled_total{job=~"$job"}[$__rate_interval])))` | — |
| `errorRate` | percentunit | `sum(rate(grpc_server_handled_total{job=~"$job", grpc_code!="OK"}[$__rate_interval])) / clamp_min(sum(rate(grpc_server_handled_total{job=~"$job"}[$__rate_interval])), 0.001)` | — |
| `handled` | reqps | `sum(rate(grpc_server_handled_total{job=~"$job"}[$__rate_interval]))` | — |
| `inFlight` | short | `sum(rate(grpc_server_started_total{job=~"$job"}[$__rate_interval])) - sum(rate(grpc_server_handled_total{job=~"$job"}[$__rate_interval]))` | — |
| `msgReceived` | ops | `sum(rate(grpc_server_msg_received_total{job=~"$job"}[$__rate_interval]))` | — |
| `msgSent` | ops | `sum(rate(grpc_server_msg_sent_total{job=~"$job"}[$__rate_interval]))` | — |
| `p95` | s | `histogram_quantile(0.95, sum by (le) (rate(grpc_server_handling_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `p95ByMethod` | s | `topk(10, histogram_quantile(0.95, sum by (le, grpc_service, grpc_method) (rate(grpc_server_handling_seconds_bucket{job=~"$job"}[$__rate_interval]))))` | — |
| `p99` | s | `histogram_quantile(0.99, sum by (le) (rate(grpc_server_handling_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `started` | reqps | `sum(rate(grpc_server_started_total{job=~"$job"}[$__rate_interval]))` | — |

## Dashboard

- **Overview** — `ov1_started`, `ov2_errors`, `ov3_p95`, `ov4_inFlight`
- **Server** — `byCode`, `byMethod`, `codeTable`, `duration`, `p95ByMethod`, `throughput`
- **Streams and clients** — `clientHandled`, `clientP95`, `messages`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `GrpcErrorRateHigh` | warning | 10m | — |
| `GrpcLatencyHigh` | warning | 15m | — |
| `GrpcCallsUnfinished` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job_service:grpc_server_calls:rate5m` | `sum by (job, grpc_service) (rate(grpc_server_handled_total[5m]))` |
| `job_service:grpc_server_errors:ratio5m` | `sum by (job, grpc_service) (rate(grpc_server_handled_total{grpc_code!="OK"}[5m])) / clamp_min(sum by (job, grpc_service) (rate(grpc_server_handled_total[5m])), 0.001)` |
