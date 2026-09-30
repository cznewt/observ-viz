# CoreDNS  (`g.libs.kubernetes.coredns`)

Dashboard uid `observ-viz-coredns` · 24 signals · 5 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cacheEntries` | short | `sum by (type) (coredns_cache_entries{job=~"$job", cluster=~"$cluster", pod=~"$pod"})` | — |
| `cacheHitRatio` | percentunit | `sum(rate(coredns_cache_hits_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])) / sum(rate(coredns_cache_requests_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `cacheHits` | ops | `sum by (type) (rate(coredns_cache_hits_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `cacheMisses` | ops | `sum(rate(coredns_cache_misses_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `forwardBroken` | short | `sum by (pod) (increase(coredns_forward_healthcheck_broken_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `healthLatency` | s | `histogram_quantile(0.99, sum by (le, pod) (rate(coredns_health_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])))` | — |
| `latencyP50` | s | `histogram_quantile(0.50, sum by (le) (rate(coredns_dns_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])))` | — |
| `latencyP90` | s | `histogram_quantile(0.90, sum by (le) (rate(coredns_dns_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])))` | — |
| `latencyP99` | s | `histogram_quantile(0.99, sum by (le) (rate(coredns_dns_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])))` | — |
| `maxConcurrentRejects` | ops | `sum by (pod) (rate(coredns_forward_max_concurrent_rejects_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `nxdomainRatio` | percentunit | `sum(rate(coredns_dns_responses_total{rcode="NXDOMAIN", job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])) / sum(rate(coredns_dns_responses_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `p99` | s | `histogram_quantile(0.99, sum by (le) (rate(coredns_dns_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])))` | — |
| `panics` | short | `sum by (pod) (increase(coredns_panics_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `pods` | short | `count(coredns_build_info{job=~"$job", cluster=~"$cluster", pod=~"$pod"})` | — |
| `programming` | s | `histogram_quantile(0.99, sum by (le) (rate(coredns_kubernetes_dns_programming_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])))` | — |
| `reloadFailed` | short | `sum by (pod) (increase(coredns_reload_failed_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `requestsByPod` | reqps | `sum by (pod) (rate(coredns_dns_requests_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `requestsByProto` | reqps | `sum by (proto) (rate(coredns_dns_requests_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `requestsByType` | reqps | `sum by (type) (rate(coredns_dns_requests_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `requestsByZone` | reqps | `sum by (zone) (rate(coredns_dns_requests_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `responseSize` | bytes | `histogram_quantile(0.90, sum by (le, proto) (rate(coredns_dns_response_size_bytes_bucket{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])))` | — |
| `responsesByRcode` | reqps | `sum by (rcode) (rate(coredns_dns_responses_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `rps` | reqps | `sum(rate(coredns_dns_requests_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |
| `servfailRatio` | percentunit | `sum(rate(coredns_dns_responses_total{rcode="SERVFAIL", job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval])) / sum(rate(coredns_dns_responses_total{job=~"$job", cluster=~"$cluster", pod=~"$pod"}[$__rate_interval]))` | — |

## Dashboard

- **Overview** — `a_pods`, `b_rps`, `c_servfail`, `d_nxdomain`, `e_p99`, `f_cache`
- **Requests** — `a_type`, `b_zone`, `c_proto`, `d_pod`
- **Responses** — `a_rcode`, `b_latency`, `c_size`
- **Cache** — `a_hits`, `b_ratio`, `c_entries`
- **Server health** — `a_forward`, `b_panics`, `c_health`, `d_programming`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `CoreDNSDown` | critical | 15m | — |
| `CoreDNSLatencyHigh` | critical | 10m | — |
| `CoreDNSErrorsHigh` | critical | 10m | — |
| `CoreDNSErrorsElevated` | warning | 10m | — |
| `CoreDNSForwardHealthcheckBrokenCount` | warning | 10m | — |
