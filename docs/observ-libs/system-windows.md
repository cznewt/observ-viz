# Windows Server  (`g.libs.system.windows`)

Dashboard uid `compute-windows-overview` · 58 signals · 6 alerts · 4 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `collectorDuration` | s | `windows_exporter_collector_duration_seconds{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `collectorSuccess` | short | `windows_exporter_collector_success{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `contextSwitches` | short | `rate(windows_system_context_switches_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `cpuBusy` | percentunit | `1 - avg without (core) (rate(windows_cpu_time_total{mode="idle",job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | `instance:windows_cpu_utilisation:rate5m` |
| `cpuByMode` | percentunit | `avg without (core) (rate(windows_cpu_time_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `cpuCState` | percentunit | `avg without (core) (rate(windows_cpu_cstate_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `cpuCores` | short | `count without (core) (windows_cpu_time_total{mode="idle",job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `cpuDpcs` | short | `sum without (core) (rate(windows_cpu_dpcs_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `cpuFreq` | hertz | `avg without (core) (windows_cpu_core_frequency_mhz{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) * 1e6` | — |
| `cpuInterrupts` | short | `sum without (core) (rate(windows_cpu_interrupts_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `diskActive` | percentunit | `1 - rate(windows_logical_disk_idle_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskFree` | bytes | `windows_logical_disk_free_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `diskQueue` | short | `windows_logical_disk_requests_queued{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `diskReadBytes` | Bps | `rate(windows_logical_disk_read_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskReadIops` | iops | `rate(windows_logical_disk_reads_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskReadLatency` | s | `rate(windows_logical_disk_read_latency_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) / rate(windows_logical_disk_reads_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskSize` | bytes | `windows_logical_disk_size_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `diskUsedRatio` | percentunit | `1 - windows_logical_disk_free_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} / windows_logical_disk_size_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `diskWriteBytes` | Bps | `rate(windows_logical_disk_write_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskWriteIops` | iops | `rate(windows_logical_disk_writes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskWriteLatency` | s | `rate(windows_logical_disk_write_latency_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) / rate(windows_logical_disk_writes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `exceptions` | short | `rate(windows_system_exception_dispatches_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `memAvailable` | bytes | `windows_memory_available_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memCache` | bytes | `windows_memory_cache_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memCommitLimit` | bytes | `windows_memory_commit_limit{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memCommitted` | bytes | `windows_memory_committed_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memFree` | bytes | `windows_memory_physical_free_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memPageFaults` | short | `rate(windows_memory_page_faults_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `memPoolNonpaged` | bytes | `windows_memory_pool_nonpaged_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memPoolPaged` | bytes | `windows_memory_pool_paged_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memSwapOps` | short | `rate(windows_memory_swap_page_operations_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `memTotal` | bytes | `windows_memory_physical_total_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memUsed` | bytes | `windows_memory_physical_total_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} - windows_memory_available_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memUsedRatio` | percentunit | `1 - windows_memory_available_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} / windows_memory_physical_total_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | `instance:windows_memory_utilisation:ratio` |
| `netBandwidth` | bps | `windows_net_current_bandwidth_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} * 8` | — |
| `netDiscards` | short | `rate(windows_net_packets_received_discarded_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) + rate(windows_net_packets_outbound_discarded_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netErrors` | short | `rate(windows_net_packets_received_errors_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) + rate(windows_net_packets_outbound_errors_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netPacketsRecv` | pps | `rate(windows_net_packets_received_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netPacketsSent` | pps | `rate(windows_net_packets_sent_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netQueue` | short | `windows_net_output_queue_length_packets{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `netRecv` | Bps | `rate(windows_net_bytes_received_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netSent` | Bps | `rate(windows_net_bytes_sent_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netUtil` | percentunit | `rate(windows_net_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) * 8 / (windows_net_current_bandwidth_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} * 8)` | — |
| `ntpRoundTrip` | s | `windows_time_ntp_round_trip_delay_seconds{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `osInfo` | short | `windows_os_info{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `procQueue` | short | `windows_system_processor_queue_length{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `processes` | short | `windows_system_processes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `scrapeDuration` | s | `windows_exporter_scrape_duration_seconds{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `serviceState` | short | `windows_service_state{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `servicesRunning` | short | `count(windows_service_state{state="running",job=~"$job", cluster=~"$cluster", instance=~"$instance"} == 1)` | — |
| `servicesStopped` | short | `count(windows_service_state{state="stopped",job=~"$job", cluster=~"$cluster", instance=~"$instance"} == 1)` | — |
| `systemCalls` | short | `rate(windows_system_system_calls_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `tempBySensor` | celsius | `({__name__=~"ohm_.+_celsius", cluster=~"$cluster", instance=~"$instance"} or label_replace(windows_thermalzone_temperature_celsius{cluster=~"$cluster", instance=~"$instance"}, "sensor", "$1", "name", "(.+)")) > 0 < 150` | — |
| `tempMax` | celsius | `max by (instance)(({__name__=~"ohm_.+_celsius", cluster=~"$cluster", instance=~"$instance"} or label_replace(windows_thermalzone_temperature_celsius{cluster=~"$cluster", instance=~"$instance"}, "sensor", "$1", "name", "(.+)")) > 0 < 150)` | — |
| `threads` | short | `windows_system_threads{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `timeOffset` | s | `windows_time_computed_time_offset_seconds{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `uptime` | s | `time() - windows_system_boot_time_timestamp{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `winLogs` | short | `{instance=~"$instance"}` | — |

## Dashboard

- **Overview** — `cores`, `cpu`, `memRatio`, `processes`, `threads`, `uptime`
- **CPU** — `cpuBusy`, `cpuByMode`, `cpuCState`, `cpuDpcs`, `cpuFreq`, `cpuInterrupts`
- **Memory** — `memAvailable`, `memCache`, `memCommitLimit`, `memCommitted`, `memPageFaults`, `memPoolNonpaged`, `memPoolPaged`, `memSwapOps`, `memUsed`
- **Disk** — `diskActive`, `diskFree`, `diskQueue`, `diskReadBytes`, `diskReadIops`, `diskReadLatency`, `diskUsedRatio`, `diskWriteBytes`, `diskWriteIops`, `diskWriteLatency`
- **Network** — `netBandwidth`, `netDiscards`, `netErrors`, `netPacketsRecv`, `netPacketsSent`, `netQueue`, `netRecv`, `netSent`, `netUtil`
- **System activity** — `contextSwitches`, `exceptions`, `procQueue`, `systemCalls`
- **Time** — `ntpRoundTrip`, `timeOffset`
- **Scrape health** — `collectorDuration`, `collectorSuccess`, `osInfo`, `scrapeDuration`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `WindowsHostDown` | critical | 5m | — |
| `WindowsHighCpu` | warning | 15m | — |
| `WindowsHighMemory` | warning | 15m | — |
| `WindowsLowDiskSpace` | warning | 15m | — |
| `WindowsHighTemperature` | warning | 10m | — |
| `WindowsCriticalTemperature` | critical | 5m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:windows_cpu_utilisation:rate5m` | `1 - avg without (core) (rate(windows_cpu_time_total{mode="idle"}[5m]))` |
| `instance:windows_memory_utilisation:ratio` | `1 - windows_memory_available_bytes / windows_memory_physical_total_bytes` |
| `instance:windows_logical_disk_free_bytes:sum` | `sum without (volume) (windows_logical_disk_free_bytes)` |
| `instance:temperature_celsius:max` | `max by (instance) (({__name__=~"ohm_.+_celsius"} or label_replace(windows_thermalzone_temperature_celsius, "sensor", "$1", "name", "(.+)")) > 0 < 150)` |
