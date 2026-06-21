# Container resources  (`g.libs.kubernetes.cadvisor`)

Dashboard uid `observ-viz-cadvisor` · 8 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpuThrottling` | short | `sum by (pod)(rate(container_cpu_cfs_throttled_periods_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `cpuUsage` | short | `sum by (pod,container)(rate(container_cpu_usage_seconds_total{namespace=~"$namespace",container!=""}[$__rate_interval]))` | — |
| `diskReads` | Bps | `sum by (pod)(rate(container_fs_reads_bytes_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `diskWrites` | Bps | `sum by (pod)(rate(container_fs_writes_bytes_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `memRss` | bytes | `sum by (pod,container)(container_memory_rss{namespace=~"$namespace",container!=""})` | — |
| `memWorkingSet` | bytes | `sum by (pod,container)(container_memory_working_set_bytes{namespace=~"$namespace",container!=""})` | — |
| `netReceive` | Bps | `sum by (pod)(rate(container_network_receive_bytes_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `netTransmit` | Bps | `sum by (pod)(rate(container_network_transmit_bytes_total{namespace=~"$namespace"}[$__rate_interval]))` | — |

## Dashboard

- **CPU** — `cpuThrottling`, `cpuUsage`
- **Memory** — `memRss`, `memWorkingSet`
- **Network** — `netReceive`, `netTransmit`
- **Disk** — `diskReads`, `diskWrites`

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
