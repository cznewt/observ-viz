# Windows host  (`g.libs.system.windows`)

Dashboard uid `observ-viz-windows` · 7 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `cpuBusy` | percentunit | `1 - avg without(core)(rate(windows_cpu_time_total{mode="idle",job=~"$job"}[$__rate_interval]))` |
| `diskFree` | bytes | `windows_logical_disk_free_bytes{job=~"$job"}` |
| `memCommitted` | bytes | `windows_memory_committed_bytes{job=~"$job"}` |
| `memFree` | bytes | `windows_os_physical_memory_free_bytes{job=~"$job"}` |
| `netRecv` | Bps | `rate(windows_net_bytes_received_total{job=~"$job"}[$__rate_interval])` |
| `netSent` | Bps | `rate(windows_net_bytes_sent_total{job=~"$job"}[$__rate_interval])` |
| `serviceState` | short | `windows_service_state{job=~"$job"}` |

## Dashboard

- **CPU** — `cpuBusy`
- **Memory** — `memCommitted`, `memFree`
- **Disk** — `diskFree`, `serviceState`
- **Network** — `netRecv`, `netSent`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `WindowsHostDown` | critical | 5m | — |
| `WindowsHighCpu` | warning | 15m | — |
| `WindowsHighCommittedMemory` | warning | 15m | — |
| `WindowsLowDiskSpace` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:windows_cpu_utilisation:rate5m` | `1 - avg without (core) (rate(windows_cpu_time_total{mode="idle"}[5m]))` |
| `instance:windows_logical_disk_free_bytes:sum` | `sum without (volume) (windows_logical_disk_free_bytes)` |
