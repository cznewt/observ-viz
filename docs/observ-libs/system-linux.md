# Linux Server  (`g.libs.system.linux`)

Dashboard uid `compute-linux-overview` · 86 signals · 26 alerts · 7 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `batoceraOs` | short | `node_os_info{id=~"batocera", instance=~"$instance"}` | — |
| `batoceraTemp` | celsius | `node_hwmon_temp_celsius{instance=~"$instance"} and on (instance) node_os_info{id=~"batocera"}` | — |
| `batteryCapacity` | percent | `node_power_supply_capacity{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `batteryOnline` | short | `node_power_supply_online{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `batteryPower` | watt | `node_power_supply_power_watt{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `batteryVoltage` | volt | `node_power_supply_voltage_volt{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `conntrackMax` | short | `node_nf_conntrack_entries_limit{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `conntrackUsed` | short | `node_nf_conntrack_entries{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `contextSwitches` | ops | `rate(node_context_switches_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `cpuBusy` | percentunit | `1 - avg without(cpu,mode)(rate(node_cpu_seconds_total{mode="idle",job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | `instance:node_cpu_utilisation:rate5m` |
| `cpuFreq` | hertz | `avg without (cpu) (node_cpu_scaling_frequency_hertz{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `cpuMode` | percentunit | `avg without(cpu)(rate(node_cpu_seconds_total{mode!="idle",job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `diskIo` | percentunit | `rate(node_disk_io_time_seconds_total{device!="",job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | `instance_device:node_disk_io_time_seconds:rate5m` |
| `diskIoLatency` | s | `rate(node_disk_io_time_weighted_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskReadBps` | Bps | `rate(node_disk_read_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskReadIops` | iops | `rate(node_disk_reads_completed_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskWriteBps` | Bps | `rate(node_disk_written_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `diskWriteIops` | iops | `rate(node_disk_writes_completed_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `dockerContainers` | short | `count(container_last_seen{instance=~"$instance", container!=""})` | — |
| `dockerCpu` | short | `sum by (pod) (rate(container_cpu_usage_seconds_total{instance=~"$instance", container!=""}[$__rate_interval]))` | — |
| `dockerMem` | bytes | `sum by (pod) (container_memory_usage_bytes{instance=~"$instance", container!=""})` | — |
| `entropy` | short | `node_entropy_available_bits{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `fdMax` | short | `node_filefd_maximum{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `fdUsed` | short | `node_filefd_allocated{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `fsAvail` | bytes | `node_filesystem_avail_bytes{fstype!="",job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `fsSize` | bytes | `node_filesystem_size_bytes{fstype!="",job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `fsUsed` | percentunit | `1 - node_filesystem_avail_bytes{fstype!="",job=~"$job", cluster=~"$cluster", instance=~"$instance"} / node_filesystem_size_bytes{fstype!="",job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `inodesUsed` | percentunit | `1 - node_filesystem_files_free{fstype!="",job=~"$job", cluster=~"$cluster", instance=~"$instance"} / node_filesystem_files{fstype!="",job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `load1` | short | `node_load1{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `load15` | short | `node_load15{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `load5` | short | `node_load5{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `loadPerCpu` | short | `node_load1{job=~"$job", cluster=~"$cluster", instance=~"$instance"} / count without (cpu, mode) (node_cpu_seconds_total{mode="idle",job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | `instance:node_load1_per_cpu:ratio` |
| `memAvailable` | bytes | `node_memory_MemAvailable_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memBuffers` | bytes | `node_memory_Buffers_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memCached` | bytes | `node_memory_Cached_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memFree` | bytes | `node_memory_MemFree_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memUsed` | bytes | `node_memory_MemTotal_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} - node_memory_MemAvailable_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memUsedRatio` | percentunit | `1 - node_memory_MemAvailable_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} / node_memory_MemTotal_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | `instance:node_memory_utilisation:ratio` |
| `netRx` | Bps | `rate(node_network_receive_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netRxDrop` | pps | `rate(node_network_receive_drop_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netRxErrs` | pps | `rate(node_network_receive_errs_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netRxExclLo` | Bps | `sum without (device) (rate(node_network_receive_bytes_total{device!="lo",job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | `instance:node_network_receive_bytes_excluding_lo:rate5m` |
| `netTx` | Bps | `rate(node_network_transmit_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netTxDrop` | pps | `rate(node_network_transmit_drop_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netTxErrs` | pps | `rate(node_network_transmit_errs_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `netTxExclLo` | Bps | `sum without (device) (rate(node_network_transmit_bytes_total{device!="lo",job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | `instance:node_network_transmit_bytes_excluding_lo:rate5m` |
| `nfsRetransmissions` | short | `rate(node_nfs_rpc_retransmissions_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `nfsRpcs` | short | `rate(node_nfs_rpcs_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `nodeLogs` | short | `{instance=~"$instance"}` | — |
| `pgFaults` | short | `rate(node_vmstat_pgfault{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `pgMajFaults` | short | `rate(node_vmstat_pgmajfault{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `procsBlocked` | short | `node_procs_blocked{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `procsRunning` | short | `node_procs_running{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `psiCpu` | percentunit | `rate(node_pressure_cpu_waiting_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `psiIo` | percentunit | `rate(node_pressure_io_waiting_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `psiIoFull` | percentunit | `rate(node_pressure_io_stalled_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `psiMem` | percentunit | `rate(node_pressure_memory_waiting_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `psiMemFull` | percentunit | `rate(node_pressure_memory_stalled_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `pveCpusAllocated` | short | `proxmox_node_cpus_allocated{node=~"$instance"}` | — |
| `pveMemAllocated` | bytes | `proxmox_node_memory_allocated_bytes{node=~"$instance"}` | — |
| `pveUp` | short | `proxmox_node_up{node=~"$instance"}` | — |
| `raplPower` | watt | `sum without (index, path) (rate(node_rapl_package_joules_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `schedWait` | s | `sum without (cpu) (rate(node_schedstat_waiting_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `servicesActive` | short | `sum(node_systemd_unit_state{state="active",job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `servicesFailed` | short | `node_systemd_unit_state{state="failed",job=~"$job", cluster=~"$cluster", instance=~"$instance"} == 1` | — |
| `socketsMem` | bytes | `node_sockstat_TCP_mem_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `socketsTcp` | short | `node_sockstat_TCP_inuse{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `softnetDropped` | short | `sum without (cpu) (rate(node_softnet_dropped_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `softnetSqueezed` | short | `sum without (cpu) (rate(node_softnet_times_squeezed_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `swapIn` | short | `rate(node_vmstat_pswpin{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `swapIoPages` | short | `rate(node_vmstat_pgpgin{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) + rate(node_vmstat_pgpgout{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | `instance:node_memory_swap_io_pages:rate5m` |
| `swapOut` | short | `rate(node_vmstat_pswpout{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `swapUsed` | bytes | `node_memory_SwapTotal_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"} - node_memory_SwapFree_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `tcpActiveOpens` | short | `rate(node_netstat_Tcp_ActiveOpens{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `tcpEstablished` | short | `node_netstat_Tcp_CurrEstab{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `tcpInErrs` | short | `rate(node_netstat_Tcp_InErrs{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `tcpRetrans` | short | `rate(node_netstat_TcpExt_TCPSynRetrans{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `tempCelsius` | celsius | `node_hwmon_temp_celsius{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `thermalZone` | celsius | `node_thermal_zone_temp{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `udpQueues` | bytes | `node_udp_queues{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `uptime` | s | `time() - node_boot_time_seconds{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `zfsArcCMax` | bytes | `node_zfs_arc_c_max{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `zfsArcHitRatio` | percentunit | `rate(node_zfs_arc_hits{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) / clamp_min(rate(node_zfs_arc_hits{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]) + rate(node_zfs_arc_misses{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]), 1)` | — |
| `zfsArcHits` | short | `rate(node_zfs_arc_hits{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `zfsArcMisses` | short | `rate(node_zfs_arc_misses{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `zfsArcSize` | bytes | `node_zfs_arc_size{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |

## Dashboard

- **System** — `conntrackUsed`, `contextSwitches`, `entropy`, `fdUsed`, `procsBlocked`, `procsRunning`, `uptime`
- **CPU / Load** — `cpuBusy`, `cpuFreq`, `cpuMode`, `load1`, `load15`, `load5`, `loadPerCpu`, `schedWait`
- **Memory** — `memAvailable`, `memBuffers`, `memCached`, `memFree`, `memUsed`, `memUsedRatio`, `pgFaults`, `pgMajFaults`, `swapIn`, `swapOut`, `swapUsed`
- **Disk space** — `fsAvail`, `fsSize`, `fsUsed`, `inodesUsed`
- **Disk IO** — `diskIo`, `diskIoLatency`, `diskReadBps`, `diskReadIops`, `diskWriteBps`, `diskWriteIops`
- **Network** — `netRx`, `netRxDrop`, `netRxErrs`, `netTx`, `netTxDrop`, `netTxErrs`, `socketsMem`, `socketsTcp`, `softnetDropped`, `softnetSqueezed`, `tcpActiveOpens`, `tcpEstablished`, `tcpInErrs`, `tcpRetrans`, `udpQueues`
- **Temperature / power** — `raplPower`, `tempCelsius`, `thermalZone`
- **Pressure (PSI)** — `psiCpu`, `psiIo`, `psiIoFull`, `psiMem`, `psiMemFull`

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
