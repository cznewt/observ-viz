# Signals -> exporters/collectors

Which exporter/collector(s) can supply each observ-lib signal (multiple = cross-OS/exporter union).

## alerts

| Signal | Metrics | Exporter/collector |
| --- | --- | --- |
| critical | `ALERTS` | [alerting/alerts](alerting.md) |
| firing | `ALERTS` | [alerting/alerts](alerting.md) |
| info | `ALERTS` | [alerting/alerts](alerting.md) |
| warning | `ALERTS` | [alerting/alerts](alerting.md) |

## kubernetes.cadvisor

| Signal | Metrics | Exporter/collector |
| --- | --- | --- |
| cpuSystem | `container_cpu_system_seconds_total` | [cadvisor/container](cadvisor.md) |
| cpuThrottleRatio | `container_cpu_cfs_periods_total`<br>`container_cpu_cfs_throttled_periods_total` | [cadvisor/container](cadvisor.md) |
| cpuThrottling | `container_cpu_cfs_throttled_periods_total` | [cadvisor/container](cadvisor.md) |
| cpuUsage | `container_cpu_usage_seconds_total` | [cadvisor/container](cadvisor.md) |
| cpuUser | `container_cpu_user_seconds_total` | [cadvisor/container](cadvisor.md) |
| diskReadIops | `container_fs_reads_total` | [cadvisor/container](cadvisor.md) |
| diskReads | `container_fs_reads_bytes_total` | [cadvisor/container](cadvisor.md) |
| diskWriteIops | `container_fs_writes_total` | [cadvisor/container](cadvisor.md) |
| diskWrites | `container_fs_writes_bytes_total` | [cadvisor/container](cadvisor.md) |
| memCache | `container_memory_cache` | [cadvisor/container](cadvisor.md) |
| memRss | `container_memory_rss` | [cadvisor/container](cadvisor.md) |
| memSwap | `container_memory_swap` | [cadvisor/container](cadvisor.md) |
| memUsage | `container_memory_usage_bytes` | [cadvisor/container](cadvisor.md) |
| memWorkingSet | `container_memory_working_set_bytes` | [cadvisor/container](cadvisor.md) |
| specMemLimit | `container_spec_memory_limit_bytes` | [cadvisor/container](cadvisor.md) |

## kubernetes.cluster

| Signal | Metrics | Exporter/collector |
| --- | --- | --- |
| apiserverErrors | `apiserver_request_total` | [apiserver/apiserver](apiserver.md) |
| apiserverInflight | `apiserver_current_inflight_requests` | [apiserver/apiserver](apiserver.md) |
| apiserverRate | `apiserver_request_total` | [apiserver/apiserver](apiserver.md) |
| kubeletErrors | `kubelet_runtime_operations_errors_total` | [kubelet/kubelet](kubelet.md) |
| kubeletPods | `kubelet_running_pods` | [kubelet/kubelet](kubelet.md) |
| workqueueAdds | `workqueue_adds_total` | [apiserver/workqueue](apiserver.md) |
| workqueueDepth | `workqueue_depth` | [apiserver/workqueue](apiserver.md) |

## kubernetes.pod

| Signal | Metrics | Exporter/collector |
| --- | --- | --- |
| containersReady | `kube_pod_container_status_ready` | [kube-state-metrics/kube](kube-state-metrics.md) |
| containersWaiting | `kube_pod_container_status_waiting` | [kube-state-metrics/kube](kube-state-metrics.md) |
| cpuLimits | `kube_pod_container_resource_limits` | [kube-state-metrics/kube](kube-state-metrics.md) |
| cpuRequests | `kube_pod_container_resource_requests` | [kube-state-metrics/kube](kube-state-metrics.md) |
| cpuThrottled | `container_cpu_cfs_periods_total`<br>`container_cpu_cfs_throttled_periods_total` | [cadvisor/container](cadvisor.md) |
| cpuUsage | `container_cpu_usage_seconds_total` | [cadvisor/container](cadvisor.md) |
| cronjobActive | `kube_cronjob_status_active` | [kube-state-metrics/kube](kube-state-metrics.md) |
| deployAvailable | `kube_deployment_status_replicas_available` | [kube-state-metrics/kube](kube-state-metrics.md) |
| deployDesired | `kube_deployment_spec_replicas` | [kube-state-metrics/kube](kube-state-metrics.md) |
| deployUnavailable | `kube_deployment_status_replicas_unavailable` | [kube-state-metrics/kube](kube-state-metrics.md) |
| dsDesired | `kube_daemonset_status_desired_number_scheduled` | [kube-state-metrics/kube](kube-state-metrics.md) |
| dsReady | `kube_daemonset_status_number_ready` | [kube-state-metrics/kube](kube-state-metrics.md) |
| dsUnavailable | `kube_daemonset_status_number_unavailable` | [kube-state-metrics/kube](kube-state-metrics.md) |
| fsReads | `container_fs_reads_bytes_total` | [cadvisor/container](cadvisor.md) |
| fsWrites | `container_fs_writes_bytes_total` | [cadvisor/container](cadvisor.md) |
| jobActive | `kube_job_status_active` | [kube-state-metrics/kube](kube-state-metrics.md) |
| jobFailed | `kube_job_status_failed` | [kube-state-metrics/kube](kube-state-metrics.md) |
| jobSucceeded | `kube_job_status_succeeded` | [kube-state-metrics/kube](kube-state-metrics.md) |
| memCache | `container_memory_cache` | [cadvisor/container](cadvisor.md) |
| memLimits | `kube_pod_container_resource_limits` | [kube-state-metrics/kube](kube-state-metrics.md) |
| memRequests | `kube_pod_container_resource_requests` | [kube-state-metrics/kube](kube-state-metrics.md) |
| memRss | `container_memory_rss` | [cadvisor/container](cadvisor.md) |
| memWorkingSet | `container_memory_working_set_bytes` | [cadvisor/container](cadvisor.md) |
| phase | `kube_pod_status_phase` | [kube-state-metrics/kube](kube-state-metrics.md) |
| pvcCapacity | `kube_persistentvolumeclaim_resource_requests_storage_bytes` | [kube-state-metrics/kube](kube-state-metrics.md) |
| pvcPhase | `kube_persistentvolumeclaim_status_phase` | [kube-state-metrics/kube](kube-state-metrics.md) |
| restarts | `kube_pod_container_status_restarts_total` | [kube-state-metrics/kube](kube-state-metrics.md) |
| stsReady | `kube_statefulset_status_replicas_ready` | [kube-state-metrics/kube](kube-state-metrics.md) |
| stsReplicas | `kube_statefulset_status_replicas` | [kube-state-metrics/kube](kube-state-metrics.md) |

## system.docker

| Signal | Metrics | Exporter/collector |
| --- | --- | --- |
| cpu | `container_cpu_usage_seconds_total` | [cadvisor/container](cadvisor.md) |
| diskRead | `container_fs_reads_bytes_total` | [cadvisor/container](cadvisor.md) |
| diskWrite | `container_fs_writes_bytes_total` | [cadvisor/container](cadvisor.md) |
| memUsage | `container_memory_usage_bytes` | [cadvisor/container](cadvisor.md) |
| memWorkingSet | `container_memory_working_set_bytes` | [cadvisor/container](cadvisor.md) |
| netRx | `container_network_receive_bytes_total` | [cadvisor/container](cadvisor.md) |
| netTx | `container_network_transmit_bytes_total` | [cadvisor/container](cadvisor.md) |

## system.linux

| Signal | Metrics | Exporter/collector |
| --- | --- | --- |
| batoceraOs | `node_os_info` | [node_exporter/os-uname-dmi](node_exporter.md) |
| batoceraTemp | `node_hwmon_temp_celsius`<br>`node_os_info` | [node_exporter/hwmon](node_exporter.md), [node_exporter/os-uname-dmi](node_exporter.md) |
| batteryCapacity | `node_power_supply_capacity` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| batteryOnline | `node_power_supply_online` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| batteryPower | `node_power_supply_power_watt` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| batteryVoltage | `node_power_supply_voltage_volt` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| conntrackMax | `node_nf_conntrack_entries_limit` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| conntrackUsed | `node_nf_conntrack_entries` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| contextSwitches | `node_context_switches_total` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| cpuBusy | `node_cpu_seconds_total` | [node_exporter/cpu](node_exporter.md) |
| cpuFreq | `node_cpu_scaling_frequency_hertz` | [node_exporter/cpu](node_exporter.md) |
| cpuMode | `node_cpu_seconds_total` | [node_exporter/cpu](node_exporter.md) |
| diskIo | `node_disk_io_time_seconds_total` | [node_exporter/diskstats](node_exporter.md) |
| diskIoLatency | `node_disk_io_time_weighted_seconds_total` | [node_exporter/diskstats](node_exporter.md) |
| diskReadBps | `node_disk_read_bytes_total` | [node_exporter/diskstats](node_exporter.md) |
| diskReadIops | `node_disk_reads_completed_total` | [node_exporter/diskstats](node_exporter.md) |
| diskWriteBps | `node_disk_written_bytes_total` | [node_exporter/diskstats](node_exporter.md) |
| diskWriteIops | `node_disk_writes_completed_total` | [node_exporter/diskstats](node_exporter.md) |
| dockerContainers | `container_last_seen` | [cadvisor/container](cadvisor.md) |
| dockerCpu | `container_cpu_usage_seconds_total` | [cadvisor/container](cadvisor.md) |
| dockerMem | `container_memory_usage_bytes` | [cadvisor/container](cadvisor.md) |
| entropy | `node_entropy_available_bits` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| fdMax | `node_filefd_maximum` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| fdUsed | `node_filefd_allocated` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| fsAvail | `node_filesystem_avail_bytes` | [node_exporter/filesystem](node_exporter.md) |
| fsSize | `node_filesystem_size_bytes` | [node_exporter/filesystem](node_exporter.md) |
| fsUsed | `node_filesystem_avail_bytes`<br>`node_filesystem_size_bytes` | [node_exporter/filesystem](node_exporter.md) |
| inodesUsed | `node_filesystem_files`<br>`node_filesystem_files_free` | [node_exporter/filesystem](node_exporter.md) |
| load1 | `node_load1` | [node_exporter/loadavg](node_exporter.md) |
| load15 | `node_load15` | [node_exporter/loadavg](node_exporter.md) |
| load5 | `node_load5` | [node_exporter/loadavg](node_exporter.md) |
| loadPerCpu | `node_cpu_seconds_total`<br>`node_load1` | [node_exporter/cpu](node_exporter.md), [node_exporter/loadavg](node_exporter.md) |
| memAvailable | `node_memory_MemAvailable_bytes` | [node_exporter/meminfo](node_exporter.md) |
| memBuffers | `node_memory_Buffers_bytes` | [node_exporter/meminfo](node_exporter.md) |
| memCached | `node_memory_Cached_bytes` | [node_exporter/meminfo](node_exporter.md) |
| memFree | `node_memory_MemFree_bytes` | [node_exporter/meminfo](node_exporter.md) |
| memUsed | `node_memory_MemAvailable_bytes`<br>`node_memory_MemTotal_bytes` | [node_exporter/meminfo](node_exporter.md) |
| memUsedRatio | `node_memory_MemAvailable_bytes`<br>`node_memory_MemTotal_bytes` | [node_exporter/meminfo](node_exporter.md) |
| netRx | `node_network_receive_bytes_total` | [node_exporter/netdev](node_exporter.md) |
| netRxDrop | `node_network_receive_drop_total` | [node_exporter/netdev](node_exporter.md) |
| netRxErrs | `node_network_receive_errs_total` | [node_exporter/netdev](node_exporter.md) |
| netRxExclLo | `node_network_receive_bytes_total` | [node_exporter/netdev](node_exporter.md) |
| netTx | `node_network_transmit_bytes_total` | [node_exporter/netdev](node_exporter.md) |
| netTxDrop | `node_network_transmit_drop_total` | [node_exporter/netdev](node_exporter.md) |
| netTxErrs | `node_network_transmit_errs_total` | [node_exporter/netdev](node_exporter.md) |
| netTxExclLo | `node_network_transmit_bytes_total` | [node_exporter/netdev](node_exporter.md) |
| nfsRetransmissions | `node_nfs_rpc_retransmissions_total` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| nfsRpcs | `node_nfs_rpcs_total` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| pgFaults | `node_vmstat_pgfault` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| pgMajFaults | `node_vmstat_pgmajfault` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| procsBlocked | `node_procs_blocked` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| procsRunning | `node_procs_running` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| psiCpu | `node_pressure_cpu_waiting_seconds_total` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| psiIo | `node_pressure_io_waiting_seconds_total` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| psiIoFull | `node_pressure_io_stalled_seconds_total` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| psiMem | `node_pressure_memory_waiting_seconds_total` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| psiMemFull | `node_pressure_memory_stalled_seconds_total` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| raplPower | `node_rapl_package_joules_total` | [node_exporter/other](node_exporter.md) |
| schedWait | `node_schedstat_waiting_seconds_total` | [node_exporter/cpu](node_exporter.md) |
| servicesActive | `node_systemd_unit_state` | [node_exporter/systemd](node_exporter.md) |
| servicesFailed | `node_systemd_unit_state` | [node_exporter/systemd](node_exporter.md) |
| socketsMem | `node_sockstat_TCP_mem_bytes` | [node_exporter/other](node_exporter.md) |
| socketsTcp | `node_sockstat_TCP_inuse` | [node_exporter/other](node_exporter.md) |
| softnetDropped | `node_softnet_dropped_total` | [node_exporter/other](node_exporter.md) |
| softnetSqueezed | `node_softnet_times_squeezed_total` | [node_exporter/other](node_exporter.md) |
| swapIn | `node_vmstat_pswpin` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| swapIoPages | `node_vmstat_pgpgin`<br>`node_vmstat_pgpgout` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| swapOut | `node_vmstat_pswpout` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| swapUsed | `node_memory_SwapFree_bytes`<br>`node_memory_SwapTotal_bytes` | [node_exporter/meminfo](node_exporter.md) |
| tcpActiveOpens | `node_netstat_Tcp_ActiveOpens` | [node_exporter/other](node_exporter.md) |
| tcpEstablished | `node_netstat_Tcp_CurrEstab` | [node_exporter/other](node_exporter.md) |
| tcpInErrs | `node_netstat_Tcp_InErrs` | [node_exporter/other](node_exporter.md) |
| tcpRetrans | `node_netstat_TcpExt_TCPSynRetrans` | [node_exporter/other](node_exporter.md) |
| tempCelsius | `node_hwmon_temp_celsius` | [node_exporter/hwmon](node_exporter.md) |
| thermalZone | `node_thermal_zone_temp` | [node_exporter/other](node_exporter.md) |
| udpQueues | `node_udp_queues` | [node_exporter/other](node_exporter.md) |
| uptime | `node_boot_time_seconds` | [node_exporter/os-uname-dmi](node_exporter.md) |
| zfsArcCMax | `node_zfs_arc_c_max` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| zfsArcHitRatio | `node_zfs_arc_hits`<br>`node_zfs_arc_misses` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| zfsArcHits | `node_zfs_arc_hits` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| zfsArcMisses | `node_zfs_arc_misses` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |
| zfsArcSize | `node_zfs_arc_size` | [node_exporter/pressure-vmstat-misc](node_exporter.md) |

## system.windows

| Signal | Metrics | Exporter/collector |
| --- | --- | --- |
| collectorDuration | `windows_exporter_collector_duration_seconds` | [windows_exporter/other](windows_exporter.md) |
| collectorSuccess | `windows_exporter_collector_success` | [windows_exporter/other](windows_exporter.md) |
| contextSwitches | `windows_system_context_switches_total` | [windows_exporter/system](windows_exporter.md) |
| cpuBusy | `windows_cpu_time_total` | [windows_exporter/cpu](windows_exporter.md) |
| cpuByMode | `windows_cpu_time_total` | [windows_exporter/cpu](windows_exporter.md) |
| cpuCState | `windows_cpu_cstate_seconds_total` | [windows_exporter/cpu](windows_exporter.md) |
| cpuCores | `windows_cpu_time_total` | [windows_exporter/cpu](windows_exporter.md) |
| cpuDpcs | `windows_cpu_dpcs_total` | [windows_exporter/cpu](windows_exporter.md) |
| cpuFreq | `windows_cpu_core_frequency_mhz` | [windows_exporter/cpu](windows_exporter.md) |
| cpuInterrupts | `windows_cpu_interrupts_total` | [windows_exporter/cpu](windows_exporter.md) |
| diskActive | `windows_logical_disk_idle_seconds_total` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskFree | `windows_logical_disk_free_bytes` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskQueue | `windows_logical_disk_requests_queued` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskReadBytes | `windows_logical_disk_read_bytes_total` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskReadIops | `windows_logical_disk_reads_total` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskReadLatency | `windows_logical_disk_read_latency_seconds_total`<br>`windows_logical_disk_reads_total` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskSize | `windows_logical_disk_size_bytes` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskUsedRatio | `windows_logical_disk_free_bytes`<br>`windows_logical_disk_size_bytes` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskWriteBytes | `windows_logical_disk_write_bytes_total` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskWriteIops | `windows_logical_disk_writes_total` | [windows_exporter/logical_disk](windows_exporter.md) |
| diskWriteLatency | `windows_logical_disk_write_latency_seconds_total`<br>`windows_logical_disk_writes_total` | [windows_exporter/logical_disk](windows_exporter.md) |
| exceptions | `windows_system_exception_dispatches_total` | [windows_exporter/system](windows_exporter.md) |
| memAvailable | `windows_memory_available_bytes` | [windows_exporter/memory](windows_exporter.md) |
| memCache | `windows_memory_cache_bytes` | [windows_exporter/memory](windows_exporter.md) |
| memCommitLimit | `windows_memory_commit_limit` | [windows_exporter/memory](windows_exporter.md) |
| memCommitted | `windows_memory_committed_bytes` | [windows_exporter/memory](windows_exporter.md) |
| memFree | `windows_memory_physical_free_bytes` | [windows_exporter/memory](windows_exporter.md) |
| memPageFaults | `windows_memory_page_faults_total` | [windows_exporter/memory](windows_exporter.md) |
| memPoolNonpaged | `windows_memory_pool_nonpaged_bytes` | [windows_exporter/memory](windows_exporter.md) |
| memPoolPaged | `windows_memory_pool_paged_bytes` | [windows_exporter/memory](windows_exporter.md) |
| memSwapOps | `windows_memory_swap_page_operations_total` | [windows_exporter/memory](windows_exporter.md) |
| memTotal | `windows_memory_physical_total_bytes` | [windows_exporter/memory](windows_exporter.md) |
| memUsed | `windows_memory_available_bytes`<br>`windows_memory_physical_total_bytes` | [windows_exporter/memory](windows_exporter.md) |
| memUsedRatio | `windows_memory_available_bytes`<br>`windows_memory_physical_total_bytes` | [windows_exporter/memory](windows_exporter.md) |
| netBandwidth | `windows_net_current_bandwidth_bytes` | [windows_exporter/net](windows_exporter.md) |
| netDiscards | `windows_net_packets_outbound_discarded_total`<br>`windows_net_packets_received_discarded_total` | [windows_exporter/net](windows_exporter.md) |
| netErrors | `windows_net_packets_outbound_errors_total`<br>`windows_net_packets_received_errors_total` | [windows_exporter/net](windows_exporter.md) |
| netPacketsRecv | `windows_net_packets_received_total` | [windows_exporter/net](windows_exporter.md) |
| netPacketsSent | `windows_net_packets_sent_total` | [windows_exporter/net](windows_exporter.md) |
| netQueue | `windows_net_output_queue_length_packets` | [windows_exporter/net](windows_exporter.md) |
| netRecv | `windows_net_bytes_received_total` | [windows_exporter/net](windows_exporter.md) |
| netSent | `windows_net_bytes_sent_total` | [windows_exporter/net](windows_exporter.md) |
| netUtil | `windows_net_bytes_total`<br>`windows_net_current_bandwidth_bytes` | [windows_exporter/net](windows_exporter.md) |
| ntpRoundTrip | `windows_time_ntp_round_trip_delay_seconds` | [windows_exporter/time](windows_exporter.md) |
| osInfo | `windows_os_info` | [windows_exporter/os](windows_exporter.md) |
| procQueue | `windows_system_processor_queue_length` | [windows_exporter/system](windows_exporter.md) |
| processes | `windows_system_processes` | [windows_exporter/system](windows_exporter.md) |
| scrapeDuration | `windows_exporter_scrape_duration_seconds` | [windows_exporter/other](windows_exporter.md) |
| serviceState | `windows_service_state` | [windows_exporter/service](windows_exporter.md) |
| servicesRunning | `windows_service_state` | [windows_exporter/service](windows_exporter.md) |
| servicesStopped | `windows_service_state` | [windows_exporter/service](windows_exporter.md) |
| systemCalls | `windows_system_system_calls_total` | [windows_exporter/system](windows_exporter.md) |
| tempBySensor | `ohm_`<br>`windows_thermalzone_temperature_celsius` | [ohmgraphite/other](ohmgraphite.md), [windows_exporter/other](windows_exporter.md) |
| tempMax | `ohm_`<br>`windows_thermalzone_temperature_celsius` | [ohmgraphite/other](ohmgraphite.md), [windows_exporter/other](windows_exporter.md) |
| threads | `windows_system_threads` | [windows_exporter/system](windows_exporter.md) |
| timeOffset | `windows_time_computed_time_offset_seconds` | [windows_exporter/time](windows_exporter.md) |
| uptime | `windows_system_boot_time_timestamp` | [windows_exporter/system](windows_exporter.md) |

