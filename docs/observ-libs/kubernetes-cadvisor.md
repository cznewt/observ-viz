# Container resources  (`g.libs.kubernetes.cadvisor`)

Dashboard uid `observ-viz-cadvisor` · 16 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpuSystem` | short | `sum by (pod,container)(rate(container_cpu_system_seconds_total{namespace=~"$namespace",container!=""}[$__rate_interval]))` | — |
| `cpuThrottleRatio` | percentunit | `sum by (pod)(rate(container_cpu_cfs_throttled_periods_total{namespace=~"$namespace"}[$__rate_interval])) / sum by (pod)(rate(container_cpu_cfs_periods_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `cpuThrottling` | short | `sum by (pod)(rate(container_cpu_cfs_throttled_periods_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `cpuUsage` | short | `sum by (pod,container)(rate(container_cpu_usage_seconds_total{namespace=~"$namespace",container!=""}[$__rate_interval]))` | — |
| `cpuUser` | short | `sum by (pod,container)(rate(container_cpu_user_seconds_total{namespace=~"$namespace",container!=""}[$__rate_interval]))` | — |
| `diskReadIops` | iops | `sum by (pod)(rate(container_fs_reads_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `diskReads` | Bps | `sum by (pod)(rate(container_fs_reads_bytes_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `diskWriteIops` | iops | `sum by (pod)(rate(container_fs_writes_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `diskWrites` | Bps | `sum by (pod)(rate(container_fs_writes_bytes_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `memCache` | bytes | `sum by (pod,container)(container_memory_cache{namespace=~"$namespace",container!=""})` | — |
| `memRss` | bytes | `sum by (pod,container)(container_memory_rss{namespace=~"$namespace",container!=""})` | — |
| `memSwap` | bytes | `sum by (pod,container)(container_memory_swap{namespace=~"$namespace",container!=""})` | — |
| `memUsage` | bytes | `sum by (pod,container)(container_memory_usage_bytes{namespace=~"$namespace",container!=""})` | — |
| `memWorkingSet` | bytes | `sum by (pod,container)(container_memory_working_set_bytes{namespace=~"$namespace",container!=""})` | — |
| `oomEvents` | short | `sum by (pod)(rate(container_oom_events_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `specMemLimit` | bytes | `sum by (pod,container)(container_spec_memory_limit_bytes{namespace=~"$namespace",container!=""})` | — |

## Dashboard

- **CPU** — `cpuSystem`, `cpuThrottleRatio`, `cpuThrottling`, `cpuUsage`, `cpuUser`
- **Memory** — `memCache`, `memRss`, `memSwap`, `memUsage`, `memWorkingSet`, `oomEvents`, `specMemLimit`
- **Disk** — `diskReadIops`, `diskReads`, `diskWriteIops`, `diskWrites`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `ContainerCpuThrottlingHigh` | warning | 15m | — |
| `ContainerHighMemory` | warning | 15m | — |
| `ContainerHighCpu` | warning | 15m | — |
| `ContainerNetworkUnavailable` | critical | 5m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `pod:container_cpu_usage:rate5m` | `sum by (pod, container) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))` |
| `pod:container_memory_working_set:sum` | `sum by (pod, container) (container_memory_working_set_bytes{container!=""})` |
