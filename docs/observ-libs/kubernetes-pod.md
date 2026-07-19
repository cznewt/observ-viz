# Kubernetes pod  (`g.libs.kubernetes.pod`)

Dashboard uid `observ-viz-kube-pod` · 29 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `containersReady` | short | `sum by (pod)(kube_pod_container_status_ready{namespace=~"$namespace"})` | — |
| `containersWaiting` | short | `sum by (pod)(kube_pod_container_status_waiting{namespace=~"$namespace"})` | — |
| `cpuLimits` | short | `sum by (pod)(kube_pod_container_resource_limits{namespace=~"$namespace",resource="cpu"})` | — |
| `cpuRequests` | short | `sum by (pod)(kube_pod_container_resource_requests{namespace=~"$namespace",resource="cpu"})` | — |
| `cpuThrottled` | percentunit | `sum by (pod)(rate(container_cpu_cfs_throttled_periods_total{namespace=~"$namespace",container!=""}[$__rate_interval])) / sum by (pod)(rate(container_cpu_cfs_periods_total{namespace=~"$namespace",container!=""}[$__rate_interval]))` | — |
| `cpuUsage` | short | `sum by (pod)(rate(container_cpu_usage_seconds_total{namespace=~"$namespace",container!=""}[$__rate_interval]))` | — |
| `cronjobActive` | short | `sum by (cronjob)(kube_cronjob_status_active{namespace=~"$namespace"})` | — |
| `deployAvailable` | short | `kube_deployment_status_replicas_available{namespace=~"$namespace"}` | — |
| `deployDesired` | short | `kube_deployment_spec_replicas{namespace=~"$namespace"}` | — |
| `deployUnavailable` | short | `kube_deployment_status_replicas_unavailable{namespace=~"$namespace"}` | — |
| `dsDesired` | short | `kube_daemonset_status_desired_number_scheduled{namespace=~"$namespace"}` | — |
| `dsReady` | short | `kube_daemonset_status_number_ready{namespace=~"$namespace"}` | — |
| `dsUnavailable` | short | `kube_daemonset_status_number_unavailable{namespace=~"$namespace"}` | — |
| `fsReads` | Bps | `sum by (pod)(rate(container_fs_reads_bytes_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `fsWrites` | Bps | `sum by (pod)(rate(container_fs_writes_bytes_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `jobActive` | short | `sum(kube_job_status_active{namespace=~"$namespace"})` | — |
| `jobFailed` | short | `sum(kube_job_status_failed{namespace=~"$namespace"})` | — |
| `jobSucceeded` | short | `sum(kube_job_status_succeeded{namespace=~"$namespace"})` | — |
| `memCache` | bytes | `sum by (pod)(container_memory_cache{namespace=~"$namespace",container!=""})` | — |
| `memLimits` | bytes | `sum by (pod)(kube_pod_container_resource_limits{namespace=~"$namespace",resource="memory"})` | — |
| `memRequests` | bytes | `sum by (pod)(kube_pod_container_resource_requests{namespace=~"$namespace",resource="memory"})` | — |
| `memRss` | bytes | `sum by (pod)(container_memory_rss{namespace=~"$namespace",container!=""})` | — |
| `memWorkingSet` | bytes | `sum by (pod)(container_memory_working_set_bytes{namespace=~"$namespace",container!=""})` | — |
| `phase` | short | `sum by (phase)(kube_pod_status_phase{namespace=~"$namespace"})` | — |
| `pvcCapacity` | bytes | `kube_persistentvolumeclaim_resource_requests_storage_bytes{namespace=~"$namespace"}` | — |
| `pvcPhase` | short | `kube_persistentvolumeclaim_status_phase{namespace=~"$namespace"} == 1` | — |
| `restarts` | short | `sum by (pod)(kube_pod_container_status_restarts_total{namespace=~"$namespace"})` | — |
| `stsReady` | short | `kube_statefulset_status_replicas_ready{namespace=~"$namespace"}` | — |
| `stsReplicas` | short | `kube_statefulset_status_replicas{namespace=~"$namespace"}` | — |

## Dashboard

- **Pod resources** — `cpuLimits`, `cpuRequests`, `cpuThrottled`, `cpuUsage`, `memCache`, `memLimits`, `memRequests`, `memRss`, `memWorkingSet`
- **Pod disk IO** — `fsReads`, `fsWrites`
- **Pod health** — `containersReady`, `containersWaiting`, `phase`, `restarts`
- **Workloads** — `deployAvailable`, `deployDesired`, `deployUnavailable`, `dsDesired`, `dsReady`, `dsUnavailable`, `stsReady`, `stsReplicas`
- **Jobs & storage** — `cronjobActive`, `jobActive`, `jobFailed`, `jobSucceeded`, `pvcCapacity`, `pvcPhase`

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
