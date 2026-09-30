# kube-state-metrics  (`g.libs.monitoring.kubeStateMetrics`)

Dashboard uid `observ-viz-kube-state-metrics` · 9 signals · 4 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `sum by (cluster, pod) (rate(process_cpu_seconds_total{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |
| `errorsByResource` | ops | `sum by (resource) (rate(kube_state_metrics_list_total{result="error", job=~"$job", cluster=~"$cluster"}[$__rate_interval])) + sum by (resource) (rate(kube_state_metrics_watch_total{result="error", job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |
| `instances` | short | `count(kube_state_metrics_build_info{job=~"$job", cluster=~"$cluster"})` | — |
| `listByResult` | ops | `sum by (result) (rate(kube_state_metrics_list_total{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |
| `listErrorRatio` | percentunit | `(sum(rate(kube_state_metrics_list_total{result="error", job=~"$job", cluster=~"$cluster"}[$__rate_interval])) or vector(0)) / sum(rate(kube_state_metrics_list_total{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |
| `memory` | bytes | `sum by (cluster, pod) (process_resident_memory_bytes{job=~"$job", cluster=~"$cluster"})` | — |
| `shards` | short | `max(kube_state_metrics_total_shards{job=~"$job", cluster=~"$cluster"})` | — |
| `watchByResult` | ops | `sum by (result) (rate(kube_state_metrics_watch_total{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |
| `watchErrorRatio` | percentunit | `(sum(rate(kube_state_metrics_watch_total{result="error", job=~"$job", cluster=~"$cluster"}[$__rate_interval])) or vector(0)) / sum(rate(kube_state_metrics_watch_total{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |

## Dashboard

- **Overview** — `a_instances`, `b_shards`, `c_list`, `d_watch`
- **List & watch** — `a_list`, `b_watch`, `c_errors`
- **Process** — `a_memory`, `b_cpu`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `KubeStateMetricsListErrors` | critical | 15m | — |
| `KubeStateMetricsWatchErrors` | critical | 15m | — |
| `KubeStateMetricsShardingMismatch` | critical | 15m | — |
| `KubeStateMetricsShardsMissing` | critical | 15m | — |
