# Kubernetes pod  (`g.libs.kubernetes.pod`)

Dashboard uid `observ-viz-kube-pod` · 6 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `cpuRequests` | short | `sum by (pod)(kube_pod_container_resource_requests{namespace=~"$namespace",resource="cpu"})` |
| `cpuUsage` | short | `sum by (pod)(rate(container_cpu_usage_seconds_total{namespace=~"$namespace",container!=""}[$__rate_interval]))` |
| `memLimits` | bytes | `sum by (pod)(kube_pod_container_resource_limits{namespace=~"$namespace",resource="memory"})` |
| `memWorkingSet` | bytes | `sum by (pod)(container_memory_working_set_bytes{namespace=~"$namespace",container!=""})` |
| `phase` | short | `sum by (pod,phase)(kube_pod_status_phase{namespace=~"$namespace"})` |
| `restarts` | short | `sum by (pod)(kube_pod_container_status_restarts_total{namespace=~"$namespace"})` |

## Dashboard

- **CPU** — `cpuRequests`, `cpuUsage`
- **Memory** — `memLimits`, `memWorkingSet`
- **Health** — `phase`, `restarts`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `KubePodNotReady` | critical | 15m | — |
| `KubePodCrashLooping` | warning | 15m | — |
| `KubePodCpuOverRequest` | warning | 15m | — |
| `KubePodMemoryNearLimit` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `namespace_pod:container_cpu_usage:rate5m` | `sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))` |
| `namespace_pod:container_memory_working_set_bytes:sum` | `sum by (namespace, pod) (container_memory_working_set_bytes{container!=""})` |
