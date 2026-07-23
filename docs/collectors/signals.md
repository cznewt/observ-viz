# Signals -> collectors

Which collector(s) can supply each observ-lib signal (multiple collectors = cross-OS/exporter union).

## alerts

| Signal | Metrics | Collectors |
| --- | --- | --- |
| critical | `ALERTS` | [alerts](alerts.md) |
| firing | `ALERTS` | [alerts](alerts.md) |
| info | `ALERTS` | [alerts](alerts.md) |
| warning | `ALERTS` | [alerts](alerts.md) |

## kubernetes.cadvisor

| Signal | Metrics | Collectors |
| --- | --- | --- |
| cpuSystem | `container_cpu_system_seconds_total` | [cadvisor](cadvisor.md) |
| cpuThrottleRatio | `container_cpu_cfs_periods_total`<br>`container_cpu_cfs_throttled_periods_total` | [cadvisor](cadvisor.md) |
| cpuThrottling | `container_cpu_cfs_throttled_periods_total` | [cadvisor](cadvisor.md) |
| cpuUsage | `container_cpu_usage_seconds_total` | [cadvisor](cadvisor.md) |
| cpuUser | `container_cpu_user_seconds_total` | [cadvisor](cadvisor.md) |
| diskReadIops | `container_fs_reads_total` | [cadvisor](cadvisor.md) |
| diskReads | `container_fs_reads_bytes_total` | [cadvisor](cadvisor.md) |
| diskWriteIops | `container_fs_writes_total` | [cadvisor](cadvisor.md) |
| diskWrites | `container_fs_writes_bytes_total` | [cadvisor](cadvisor.md) |
| memCache | `container_memory_cache` | [cadvisor](cadvisor.md) |
| memRss | `container_memory_rss` | [cadvisor](cadvisor.md) |
| memSwap | `container_memory_swap` | [cadvisor](cadvisor.md) |
| memUsage | `container_memory_usage_bytes` | [cadvisor](cadvisor.md) |
| memWorkingSet | `container_memory_working_set_bytes` | [cadvisor](cadvisor.md) |
| specMemLimit | `container_spec_memory_limit_bytes` | [cadvisor](cadvisor.md) |

## kubernetes.cluster

| Signal | Metrics | Collectors |
| --- | --- | --- |
| apiserverErrors | `apiserver_request_total` | [apiserver](apiserver.md) |
| apiserverInflight | `apiserver_current_inflight_requests` | [apiserver](apiserver.md) |
| apiserverRate | `apiserver_request_total` | [apiserver](apiserver.md) |
| kubeletErrors | `kubelet_runtime_operations_errors_total` | [kubelet](kubelet.md) |
| kubeletPods | `kubelet_running_pods` | [kubelet](kubelet.md) |
| workqueueAdds | `workqueue_adds_total` | [apiserver](apiserver.md) |
| workqueueDepth | `workqueue_depth` | [apiserver](apiserver.md) |

## kubernetes.pod

| Signal | Metrics | Collectors |
| --- | --- | --- |
| containersReady | `kube_pod_container_status_ready` | [kube-state-metrics](kube-state-metrics.md) |
| containersWaiting | `kube_pod_container_status_waiting` | [kube-state-metrics](kube-state-metrics.md) |
| cpuLimits | `kube_pod_container_resource_limits` | [kube-state-metrics](kube-state-metrics.md) |
| cpuRequests | `kube_pod_container_resource_requests` | [kube-state-metrics](kube-state-metrics.md) |
| cpuThrottled | `container_cpu_cfs_periods_total`<br>`container_cpu_cfs_throttled_periods_total` | [cadvisor](cadvisor.md) |
| cpuUsage | `container_cpu_usage_seconds_total` | [cadvisor](cadvisor.md) |
| cronjobActive | `kube_cronjob_status_active` | [kube-state-metrics](kube-state-metrics.md) |
| deployAvailable | `kube_deployment_status_replicas_available` | [kube-state-metrics](kube-state-metrics.md) |
| deployDesired | `kube_deployment_spec_replicas` | [kube-state-metrics](kube-state-metrics.md) |
| deployUnavailable | `kube_deployment_status_replicas_unavailable` | [kube-state-metrics](kube-state-metrics.md) |
| dsDesired | `kube_daemonset_status_desired_number_scheduled` | [kube-state-metrics](kube-state-metrics.md) |
| dsReady | `kube_daemonset_status_number_ready` | [kube-state-metrics](kube-state-metrics.md) |
| dsUnavailable | `kube_daemonset_status_number_unavailable` | [kube-state-metrics](kube-state-metrics.md) |
| fsReads | `container_fs_reads_bytes_total` | [cadvisor](cadvisor.md) |
| fsWrites | `container_fs_writes_bytes_total` | [cadvisor](cadvisor.md) |
| jobActive | `kube_job_status_active` | [kube-state-metrics](kube-state-metrics.md) |
| jobFailed | `kube_job_status_failed` | [kube-state-metrics](kube-state-metrics.md) |
| jobSucceeded | `kube_job_status_succeeded` | [kube-state-metrics](kube-state-metrics.md) |
| memCache | `container_memory_cache` | [cadvisor](cadvisor.md) |
| memLimits | `kube_pod_container_resource_limits` | [kube-state-metrics](kube-state-metrics.md) |
| memRequests | `kube_pod_container_resource_requests` | [kube-state-metrics](kube-state-metrics.md) |
| memRss | `container_memory_rss` | [cadvisor](cadvisor.md) |
| memWorkingSet | `container_memory_working_set_bytes` | [cadvisor](cadvisor.md) |
| phase | `kube_pod_status_phase` | [kube-state-metrics](kube-state-metrics.md) |
| pvcCapacity | `kube_persistentvolumeclaim_resource_requests_storage_bytes` | [kube-state-metrics](kube-state-metrics.md) |
| pvcPhase | `kube_persistentvolumeclaim_status_phase` | [kube-state-metrics](kube-state-metrics.md) |
| restarts | `kube_pod_container_status_restarts_total` | [kube-state-metrics](kube-state-metrics.md) |
| stsReady | `kube_statefulset_status_replicas_ready` | [kube-state-metrics](kube-state-metrics.md) |
| stsReplicas | `kube_statefulset_status_replicas` | [kube-state-metrics](kube-state-metrics.md) |

## system.docker

| Signal | Metrics | Collectors |
| --- | --- | --- |
| cpu | `container_cpu_usage_seconds_total` | [cadvisor](cadvisor.md) |
| diskRead | `container_fs_reads_bytes_total` | [cadvisor](cadvisor.md) |
| diskWrite | `container_fs_writes_bytes_total` | [cadvisor](cadvisor.md) |
| memUsage | `container_memory_usage_bytes` | [cadvisor](cadvisor.md) |
| memWorkingSet | `container_memory_working_set_bytes` | [cadvisor](cadvisor.md) |
| netRx | `container_network_receive_bytes_total` | [cadvisor](cadvisor.md) |
| netTx | `container_network_transmit_bytes_total` | [cadvisor](cadvisor.md) |

## system.linux

| Signal | Metrics | Collectors |
| --- | --- | --- |
| batoceraOs | `node_os_info` | [unix.os-uname-dmi](unix-os-uname-dmi.md) |
| batoceraTemp | `node_hwmon_temp_celsius`<br>`node_os_info` | [unix.hwmon](unix-hwmon.md), [unix.os-uname-dmi](unix-os-uname-dmi.md) |
| batteryCapacity | `node_power_supply_capacity` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| batteryOnline | `node_power_supply_online` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| batteryPower | `node_power_supply_power_watt` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| batteryVoltage | `node_power_supply_voltage_volt` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| conntrackMax | `node_nf_conntrack_entries_limit` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| conntrackUsed | `node_nf_conntrack_entries` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| contextSwitches | `node_context_switches_total` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| cpuBusy | `node_cpu_seconds_total` | [unix.cpu](unix-cpu.md) |
| cpuFreq | `node_cpu_scaling_frequency_hertz` | [unix.cpu](unix-cpu.md) |
| cpuMode | `node_cpu_seconds_total` | [unix.cpu](unix-cpu.md) |
| diskIo | `node_disk_io_time_seconds_total` | [unix.diskstats](unix-diskstats.md) |
| diskIoLatency | `node_disk_io_time_weighted_seconds_total` | [unix.diskstats](unix-diskstats.md) |
| diskReadBps | `node_disk_read_bytes_total` | [unix.diskstats](unix-diskstats.md) |
| diskReadIops | `node_disk_reads_completed_total` | [unix.diskstats](unix-diskstats.md) |
| diskWriteBps | `node_disk_written_bytes_total` | [unix.diskstats](unix-diskstats.md) |
| diskWriteIops | `node_disk_writes_completed_total` | [unix.diskstats](unix-diskstats.md) |
| dockerContainers | `container_last_seen` | [cadvisor](cadvisor.md) |
| dockerCpu | `container_cpu_usage_seconds_total` | [cadvisor](cadvisor.md) |
| dockerMem | `container_memory_usage_bytes` | [cadvisor](cadvisor.md) |
| entropy | `node_entropy_available_bits` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| fdMax | `node_filefd_maximum` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| fdUsed | `node_filefd_allocated` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| fsAvail | `node_filesystem_avail_bytes` | [unix.filesystem](unix-filesystem.md) |
| fsSize | `node_filesystem_size_bytes` | [unix.filesystem](unix-filesystem.md) |
| fsUsed | `node_filesystem_avail_bytes`<br>`node_filesystem_size_bytes` | [unix.filesystem](unix-filesystem.md) |
| inodesUsed | `node_filesystem_files`<br>`node_filesystem_files_free` | [unix.filesystem](unix-filesystem.md) |
| load1 | `node_load1` | [unix.loadavg](unix-loadavg.md) |
| load15 | `node_load15` | [unix.loadavg](unix-loadavg.md) |
| load5 | `node_load5` | [unix.loadavg](unix-loadavg.md) |
| loadPerCpu | `node_cpu_seconds_total`<br>`node_load1` | [unix.cpu](unix-cpu.md), [unix.loadavg](unix-loadavg.md) |
| memAvailable | `node_memory_MemAvailable_bytes` | [unix.meminfo](unix-meminfo.md) |
| memBuffers | `node_memory_Buffers_bytes` | [unix.meminfo](unix-meminfo.md) |
| memCached | `node_memory_Cached_bytes` | [unix.meminfo](unix-meminfo.md) |
| memFree | `node_memory_MemFree_bytes` | [unix.meminfo](unix-meminfo.md) |
| memUsed | `node_memory_MemAvailable_bytes`<br>`node_memory_MemTotal_bytes` | [unix.meminfo](unix-meminfo.md) |
| memUsedRatio | `node_memory_MemAvailable_bytes`<br>`node_memory_MemTotal_bytes` | [unix.meminfo](unix-meminfo.md) |
| netRx | `node_network_receive_bytes_total` | [unix.netdev](unix-netdev.md) |
| netRxDrop | `node_network_receive_drop_total` | [unix.netdev](unix-netdev.md) |
| netRxErrs | `node_network_receive_errs_total` | [unix.netdev](unix-netdev.md) |
| netRxExclLo | `node_network_receive_bytes_total` | [unix.netdev](unix-netdev.md) |
| netTx | `node_network_transmit_bytes_total` | [unix.netdev](unix-netdev.md) |
| netTxDrop | `node_network_transmit_drop_total` | [unix.netdev](unix-netdev.md) |
| netTxErrs | `node_network_transmit_errs_total` | [unix.netdev](unix-netdev.md) |
| netTxExclLo | `node_network_transmit_bytes_total` | [unix.netdev](unix-netdev.md) |
| nfsRetransmissions | `node_nfs_rpc_retransmissions_total` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| nfsRpcs | `node_nfs_rpcs_total` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| pgFaults | `node_vmstat_pgfault` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| pgMajFaults | `node_vmstat_pgmajfault` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| procsBlocked | `node_procs_blocked` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| procsRunning | `node_procs_running` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| psiCpu | `node_pressure_cpu_waiting_seconds_total` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| psiIo | `node_pressure_io_waiting_seconds_total` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| psiIoFull | `node_pressure_io_stalled_seconds_total` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| psiMem | `node_pressure_memory_waiting_seconds_total` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| psiMemFull | `node_pressure_memory_stalled_seconds_total` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| raplPower | `node_rapl_package_joules_total` | [unix.other](unix-other.md) |
| schedWait | `node_schedstat_waiting_seconds_total` | [unix.cpu](unix-cpu.md) |
| servicesActive | `node_systemd_unit_state` | [unix.systemd](unix-systemd.md) |
| servicesFailed | `node_systemd_unit_state` | [unix.systemd](unix-systemd.md) |
| socketsMem | `node_sockstat_TCP_mem_bytes` | [unix.other](unix-other.md) |
| socketsTcp | `node_sockstat_TCP_inuse` | [unix.other](unix-other.md) |
| softnetDropped | `node_softnet_dropped_total` | [unix.other](unix-other.md) |
| softnetSqueezed | `node_softnet_times_squeezed_total` | [unix.other](unix-other.md) |
| swapIn | `node_vmstat_pswpin` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| swapIoPages | `node_vmstat_pgpgin`<br>`node_vmstat_pgpgout` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| swapOut | `node_vmstat_pswpout` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| swapUsed | `node_memory_SwapFree_bytes`<br>`node_memory_SwapTotal_bytes` | [unix.meminfo](unix-meminfo.md) |
| tcpActiveOpens | `node_netstat_Tcp_ActiveOpens` | [unix.other](unix-other.md) |
| tcpEstablished | `node_netstat_Tcp_CurrEstab` | [unix.other](unix-other.md) |
| tcpInErrs | `node_netstat_Tcp_InErrs` | [unix.other](unix-other.md) |
| tcpRetrans | `node_netstat_TcpExt_TCPSynRetrans` | [unix.other](unix-other.md) |
| tempCelsius | `node_hwmon_temp_celsius` | [unix.hwmon](unix-hwmon.md) |
| thermalZone | `node_thermal_zone_temp` | [unix.other](unix-other.md) |
| udpQueues | `node_udp_queues` | [unix.other](unix-other.md) |
| uptime | `node_boot_time_seconds` | [unix.os-uname-dmi](unix-os-uname-dmi.md) |
| zfsArcCMax | `node_zfs_arc_c_max` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| zfsArcHitRatio | `node_zfs_arc_hits`<br>`node_zfs_arc_misses` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| zfsArcHits | `node_zfs_arc_hits` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| zfsArcMisses | `node_zfs_arc_misses` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |
| zfsArcSize | `node_zfs_arc_size` | [unix.pressure-vmstat-misc](unix-pressure-vmstat-misc.md) |

## system.windows

| Signal | Metrics | Collectors |
| --- | --- | --- |
| collectorDuration | `windows_exporter_collector_duration_seconds` | [windows.other](windows-other.md) |
| collectorSuccess | `windows_exporter_collector_success` | [windows.other](windows-other.md) |
| contextSwitches | `windows_system_context_switches_total` | [windows.core](windows-core.md) |
| cpuBusy | `windows_cpu_time_total` | [windows.core](windows-core.md) |
| cpuByMode | `windows_cpu_time_total` | [windows.core](windows-core.md) |
| cpuCState | `windows_cpu_cstate_seconds_total` | [windows.core](windows-core.md) |
| cpuCores | `windows_cpu_time_total` | [windows.core](windows-core.md) |
| cpuDpcs | `windows_cpu_dpcs_total` | [windows.core](windows-core.md) |
| cpuFreq | `windows_cpu_core_frequency_mhz` | [windows.core](windows-core.md) |
| cpuInterrupts | `windows_cpu_interrupts_total` | [windows.core](windows-core.md) |
| diskActive | `windows_logical_disk_idle_seconds_total` | [windows.core](windows-core.md) |
| diskFree | `windows_logical_disk_free_bytes` | [windows.core](windows-core.md) |
| diskQueue | `windows_logical_disk_requests_queued` | [windows.core](windows-core.md) |
| diskReadBytes | `windows_logical_disk_read_bytes_total` | [windows.core](windows-core.md) |
| diskReadIops | `windows_logical_disk_reads_total` | [windows.core](windows-core.md) |
| diskReadLatency | `windows_logical_disk_read_latency_seconds_total`<br>`windows_logical_disk_reads_total` | [windows.core](windows-core.md) |
| diskSize | `windows_logical_disk_size_bytes` | [windows.core](windows-core.md) |
| diskUsedRatio | `windows_logical_disk_free_bytes`<br>`windows_logical_disk_size_bytes` | [windows.core](windows-core.md) |
| diskWriteBytes | `windows_logical_disk_write_bytes_total` | [windows.core](windows-core.md) |
| diskWriteIops | `windows_logical_disk_writes_total` | [windows.core](windows-core.md) |
| diskWriteLatency | `windows_logical_disk_write_latency_seconds_total`<br>`windows_logical_disk_writes_total` | [windows.core](windows-core.md) |
| exceptions | `windows_system_exception_dispatches_total` | [windows.core](windows-core.md) |
| memAvailable | `windows_memory_available_bytes` | [windows.core](windows-core.md) |
| memCache | `windows_memory_cache_bytes` | [windows.core](windows-core.md) |
| memCommitLimit | `windows_memory_commit_limit` | [windows.core](windows-core.md) |
| memCommitted | `windows_memory_committed_bytes` | [windows.core](windows-core.md) |
| memFree | `windows_memory_physical_free_bytes` | [windows.core](windows-core.md) |
| memPageFaults | `windows_memory_page_faults_total` | [windows.core](windows-core.md) |
| memPoolNonpaged | `windows_memory_pool_nonpaged_bytes` | [windows.core](windows-core.md) |
| memPoolPaged | `windows_memory_pool_paged_bytes` | [windows.core](windows-core.md) |
| memSwapOps | `windows_memory_swap_page_operations_total` | [windows.core](windows-core.md) |
| memTotal | `windows_memory_physical_total_bytes` | [windows.core](windows-core.md) |
| memUsed | `windows_memory_available_bytes`<br>`windows_memory_physical_total_bytes` | [windows.core](windows-core.md) |
| memUsedRatio | `windows_memory_available_bytes`<br>`windows_memory_physical_total_bytes` | [windows.core](windows-core.md) |
| netBandwidth | `windows_net_current_bandwidth_bytes` | [windows.core](windows-core.md) |
| netDiscards | `windows_net_packets_outbound_discarded_total`<br>`windows_net_packets_received_discarded_total` | [windows.core](windows-core.md) |
| netErrors | `windows_net_packets_outbound_errors_total`<br>`windows_net_packets_received_errors_total` | [windows.core](windows-core.md) |
| netPacketsRecv | `windows_net_packets_received_total` | [windows.core](windows-core.md) |
| netPacketsSent | `windows_net_packets_sent_total` | [windows.core](windows-core.md) |
| netQueue | `windows_net_output_queue_length_packets` | [windows.core](windows-core.md) |
| netRecv | `windows_net_bytes_received_total` | [windows.core](windows-core.md) |
| netSent | `windows_net_bytes_sent_total` | [windows.core](windows-core.md) |
| netUtil | `windows_net_bytes_total`<br>`windows_net_current_bandwidth_bytes` | [windows.core](windows-core.md) |
| ntpRoundTrip | `windows_time_ntp_round_trip_delay_seconds` | [windows.core](windows-core.md) |
| osInfo | `windows_os_info` | [windows.core](windows-core.md) |
| procQueue | `windows_system_processor_queue_length` | [windows.core](windows-core.md) |
| processes | `windows_system_processes` | [windows.core](windows-core.md) |
| scrapeDuration | `windows_exporter_scrape_duration_seconds` | [windows.other](windows-other.md) |
| serviceState | `windows_service_state` | [windows.service](windows-service.md) |
| servicesRunning | `windows_service_state` | [windows.service](windows-service.md) |
| servicesStopped | `windows_service_state` | [windows.service](windows-service.md) |
| systemCalls | `windows_system_system_calls_total` | [windows.core](windows-core.md) |
| tempBySensor | `ohm_`<br>`windows_thermalzone_temperature_celsius` | [ohm.other](ohm-other.md), [windows.other](windows-other.md) |
| tempMax | `ohm_`<br>`windows_thermalzone_temperature_celsius` | [ohm.other](ohm-other.md), [windows.other](windows-other.md) |
| threads | `windows_system_threads` | [windows.core](windows-core.md) |
| timeOffset | `windows_time_computed_time_offset_seconds` | [windows.core](windows-core.md) |
| uptime | `windows_system_boot_time_timestamp` | [windows.core](windows-core.md) |

