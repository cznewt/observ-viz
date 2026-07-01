# Windows Server  (`g.libs.system.windows`)

Dashboard uid `compute-windows-overview` · 16 signals · 4 alerts · 3 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpuBusy` | percentunit | `1 - avg without (core) (rate(windows_cpu_time_total{mode="idle",job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | `instance:windows_cpu_utilisation:rate5m` |
| `diskFree` | bytes | `windows_logical_disk_free_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `diskUsedRatio` | percentunit | `1 - windows_logical_disk_free_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} / windows_logical_disk_size_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memAvailable` | bytes | `windows_memory_available_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memCommitted` | bytes | `windows_memory_committed_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memFree` | bytes | `windows_memory_physical_free_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memTotal` | bytes | `windows_memory_physical_total_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memUsed` | bytes | `windows_memory_physical_total_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} - windows_memory_available_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memUsedRatio` | percentunit | `1 - windows_memory_available_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} / windows_memory_physical_total_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | `instance:windows_memory_utilisation:ratio` |
| `netRecv` | Bps | `rate(windows_net_bytes_received_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netSent` | Bps | `rate(windows_net_bytes_sent_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `processes` | short | `windows_system_processes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `serviceState` | short | `windows_service_state{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `servicesRunning` | short | `count(windows_service_state{state="running",job=~"$job", cluster=~"$cluster", instance=~"$instance"} == 1)` | — |
| `uptime` | s | `time() - windows_system_boot_time_timestamp{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `winLogs` | short | `{instance=~"$instance"}` | — |

## Dashboard

- **System** — `cpu`, `memRatio`, `uptime`
- **CPU** — `cpuBusy`
- **Memory** — `memAvailable`, `memCommitted`, `memFree`, `memTotal`, `memUsed`
- **Disk** — `diskFree`, `diskUsedRatio`
- **Network** — `netRecv`, `netSent`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `WindowsHostDown` | critical | 5m | — |
| `WindowsHighCpu` | warning | 15m | — |
| `WindowsHighMemory` | warning | 15m | — |
| `WindowsLowDiskSpace` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:windows_cpu_utilisation:rate5m` | `1 - avg without (core) (rate(windows_cpu_time_total{mode="idle"}[5m]))` |
| `instance:windows_memory_utilisation:ratio` | `1 - windows_memory_available_bytes / windows_memory_physical_total_bytes` |
| `instance:windows_logical_disk_free_bytes:sum` | `sum without (volume) (windows_logical_disk_free_bytes)` |
