# Linux node  (`g.libs.system.linux`)

Dashboard uid `observ-viz-linux` · 43 signals · 26 alerts · 7 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `conntrackMax` | short | `node_nf_conntrack_entries_limit{job=~"$job"}` | — |
| `conntrackUsed` | short | `node_nf_conntrack_entries{job=~"$job"}` | — |
| `contextSwitches` | ops | `rate(node_context_switches_total{job=~"$job"}[$__rate_interval])` | — |
| `cpuBusy` | percentunit | `1 - avg without(cpu,mode)(rate(node_cpu_seconds_total{mode="idle",job=~"$job"}[$__rate_interval]))` | `instance:node_cpu_utilisation:rate5m` |
| `cpuIowait` | percentunit | `avg without(cpu)(rate(node_cpu_seconds_total{mode="iowait",job=~"$job"}[$__rate_interval]))` | — |
| `cpuSteal` | percentunit | `avg without(cpu)(rate(node_cpu_seconds_total{mode="steal",job=~"$job"}[$__rate_interval]))` | — |
| `cpuSystem` | percentunit | `avg without(cpu)(rate(node_cpu_seconds_total{mode="system",job=~"$job"}[$__rate_interval]))` | — |
| `cpuUser` | percentunit | `avg without(cpu)(rate(node_cpu_seconds_total{mode="user",job=~"$job"}[$__rate_interval]))` | — |
| `diskIo` | percentunit | `rate(node_disk_io_time_seconds_total{device!="",job=~"$job"}[$__rate_interval])` | `instance_device:node_disk_io_time_seconds:rate5m` |
| `diskIoLatency` | s | `rate(node_disk_io_time_weighted_seconds_total{job=~"$job"}[$__rate_interval])` | — |
| `diskReadBps` | Bps | `rate(node_disk_read_bytes_total{job=~"$job"}[$__rate_interval])` | — |
| `diskReadIops` | iops | `rate(node_disk_reads_completed_total{job=~"$job"}[$__rate_interval])` | — |
| `diskWriteBps` | Bps | `rate(node_disk_written_bytes_total{job=~"$job"}[$__rate_interval])` | — |
| `diskWriteIops` | iops | `rate(node_disk_writes_completed_total{job=~"$job"}[$__rate_interval])` | — |
| `fdMax` | short | `node_filefd_maximum{job=~"$job"}` | — |
| `fdUsed` | short | `node_filefd_allocated{job=~"$job"}` | — |
| `fsAvail` | bytes | `node_filesystem_avail_bytes{fstype!="",job=~"$job"}` | — |
| `fsSize` | bytes | `node_filesystem_size_bytes{fstype!="",job=~"$job"}` | — |
| `fsUsed` | percentunit | `1 - node_filesystem_avail_bytes{fstype!="",job=~"$job"} / node_filesystem_size_bytes{fstype!="",job=~"$job"}` | — |
| `inodesUsed` | percentunit | `1 - node_filesystem_files_free{fstype!="",job=~"$job"} / node_filesystem_files{fstype!="",job=~"$job"}` | — |
| `load1` | short | `node_load1{job=~"$job"}` | — |
| `load15` | short | `node_load15{job=~"$job"}` | — |
| `load5` | short | `node_load5{job=~"$job"}` | — |
| `loadPerCpu` | short | `node_load1{job=~"$job"} / count without (cpu, mode) (node_cpu_seconds_total{mode="idle",job=~"$job"})` | `instance:node_load1_per_cpu:ratio` |
| `memAvailable` | bytes | `node_memory_MemAvailable_bytes{job=~"$job"}` | — |
| `memBuffers` | bytes | `node_memory_Buffers_bytes{job=~"$job"}` | — |
| `memCached` | bytes | `node_memory_Cached_bytes{job=~"$job"}` | — |
| `memFree` | bytes | `node_memory_MemFree_bytes{job=~"$job"}` | — |
| `memUsed` | bytes | `node_memory_MemTotal_bytes{job=~"$job"} - node_memory_MemAvailable_bytes{job=~"$job"}` | — |
| `memUsedRatio` | percentunit | `1 - node_memory_MemAvailable_bytes{job=~"$job"} / node_memory_MemTotal_bytes{job=~"$job"}` | `instance:node_memory_utilisation:ratio` |
| `netRx` | Bps | `rate(node_network_receive_bytes_total{job=~"$job"}[$__rate_interval])` | — |
| `netRxDrop` | pps | `rate(node_network_receive_drop_total{job=~"$job"}[$__rate_interval])` | — |
| `netRxErrs` | pps | `rate(node_network_receive_errs_total{job=~"$job"}[$__rate_interval])` | — |
| `netRxExclLo` | Bps | `sum without (device) (rate(node_network_receive_bytes_total{device!="lo",job=~"$job"}[$__rate_interval]))` | `instance:node_network_receive_bytes_excluding_lo:rate5m` |
| `netTx` | Bps | `rate(node_network_transmit_bytes_total{job=~"$job"}[$__rate_interval])` | — |
| `netTxDrop` | pps | `rate(node_network_transmit_drop_total{job=~"$job"}[$__rate_interval])` | — |
| `netTxErrs` | pps | `rate(node_network_transmit_errs_total{job=~"$job"}[$__rate_interval])` | — |
| `netTxExclLo` | Bps | `sum without (device) (rate(node_network_transmit_bytes_total{device!="lo",job=~"$job"}[$__rate_interval]))` | `instance:node_network_transmit_bytes_excluding_lo:rate5m` |
| `swapIoPages` | short | `rate(node_vmstat_pgpgin{job=~"$job"}[$__rate_interval]) + rate(node_vmstat_pgpgout{job=~"$job"}[$__rate_interval])` | `instance:node_memory_swap_io_pages:rate5m` |
| `swapUsed` | bytes | `node_memory_SwapTotal_bytes{job=~"$job"} - node_memory_SwapFree_bytes{job=~"$job"}` | — |
| `tempCelsius` | celsius | `node_hwmon_temp_celsius{job=~"$job"}` | — |
| `thermalZone` | celsius | `node_thermal_zone_temp{job=~"$job"}` | — |
| `uptime` | s | `time() - node_boot_time_seconds{job=~"$job"}` | — |

## Dashboard

- **CPU / Load** — `cpuBusy`, `cpuIowait`, `cpuSteal`, `cpuSystem`, `cpuUser`, `load1`, `load15`, `load5`
- **Memory** — `memAvailable`, `memBuffers`, `memCached`, `memFree`, `memUsed`, `memUsedRatio`, `swapUsed`
- **Disk space** — `fsAvail`, `fsSize`, `fsUsed`, `inodesUsed`
- **Disk IO** — `diskIo`, `diskIoLatency`, `diskReadBps`, `diskReadIops`, `diskWriteBps`, `diskWriteIops`
- **Network** — `netRx`, `netRxDrop`, `netRxErrs`, `netTx`, `netTxDrop`, `netTxErrs`
- **Temperature** — `tempCelsius`, `thermalZone`
- **System** — `conntrackUsed`, `contextSwitches`, `fdUsed`, `uptime`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `NodeFilesystemSpaceFillingUp` | warning | 1h | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemspacefillingup) |
| `NodeFilesystemAlmostOutOfSpace` | warning | 30m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemalmostoutofspace) |
| `NodeFilesystemFilesFillingUp` | warning | 1h | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemfilesfillingup) |
| `NodeFilesystemAlmostOutOfFiles` | warning | 1h | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemalmostoutoffiles) |
| `NodeNetworkReceiveErrs` | warning | 1h | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodenetworkreceiveerrs) |
| `NodeNetworkTransmitErrs` | warning | 1h | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodenetworktransmiterrs) |
| `NodeHighNumberConntrackEntriesUsed` | warning | 0m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodehighnumberconntrackentriesused) |
| `NodeTextFileCollectorScrapeError` | warning | 0m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodetextfilecollectorscrapeerror) |
| `NodeClockSkewDetected` | warning | 10m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodeclockskewdetected) |
| `NodeClockNotSynchronising` | warning | 10m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodeclocknotsynchronising) |
| `NodeRAIDDegraded` | critical | 15m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/noderaiddegraded) |
| `NodeRAIDDiskFailure` | warning | 0m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/noderaiddiskfailure) |
| `NodeFileDescriptorLimit` | warning | 15m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodefiledescriptorlimit) |
| `NodeCPUHighUsage` | info | 15m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodecpuhighusage) |
| `NodeSystemSaturation` | warning | 15m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodesystemsaturation) |
| `NodeMemoryMajorPagesFaults` | warning | 15m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodememorymajorpagesfaults) |
| `NodeMemoryHighUtilization` | warning | 15m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodememoryhighutilization) |
| `NodeDiskIOSaturation` | warning | 30m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodediskiosaturation) |
| `NodeSystemdServiceFailed` | warning | 5m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodesystemdservicefailed) |
| `NodeSystemdServiceCrashlooping` | warning | 15m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodesystemdservicecrashlooping) |
| `NodeBondingDegraded` | warning | 5m | [runbook](https://runbooks.prometheus-operator.dev/runbooks/node/nodebondingdegraded) |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:node_cpu_utilisation:rate5m` | `1 - avg without(cpu,mode)(rate(node_cpu_seconds_total{mode="idle"}[5m]))` |
| `instance:node_load1_per_cpu:ratio` | `node_load1 / count without (cpu, mode) (node_cpu_seconds_total{mode="idle"})` |
| `instance:node_memory_utilisation:ratio` | `1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes` |
| `instance:node_memory_swap_io_pages:rate5m` | `rate(node_vmstat_pgpgin[5m]) + rate(node_vmstat_pgpgout[5m])` |
| `instance_device:node_disk_io_time_seconds:rate5m` | `rate(node_disk_io_time_seconds_total{device!=""}[5m])` |
| `instance:node_network_receive_bytes_excluding_lo:rate5m` | `sum without (device) (rate(node_network_receive_bytes_total{device!="lo"}[5m]))` |
| `instance:node_network_transmit_bytes_excluding_lo:rate5m` | `sum without (device) (rate(node_network_transmit_bytes_total{device!="lo"}[5m]))` |
