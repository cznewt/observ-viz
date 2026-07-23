# windows.core

- **source**: windows_exporter (alloy prometheus.exporter.windows)
- **patterns**: `windows_cpu_.*`, `windows_os_.*`, `windows_memory_.*`, `windows_logical_disk_.*`, `windows_net_.*`, `windows_system_.*`, `windows_time_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.windows | contextSwitches | `windows_system_context_switches_total` |
| system.windows | cpuBusy | `windows_cpu_time_total` |
| system.windows | cpuByMode | `windows_cpu_time_total` |
| system.windows | cpuCState | `windows_cpu_cstate_seconds_total` |
| system.windows | cpuCores | `windows_cpu_time_total` |
| system.windows | cpuDpcs | `windows_cpu_dpcs_total` |
| system.windows | cpuFreq | `windows_cpu_core_frequency_mhz` |
| system.windows | cpuInterrupts | `windows_cpu_interrupts_total` |
| system.windows | diskActive | `windows_logical_disk_idle_seconds_total` |
| system.windows | diskFree | `windows_logical_disk_free_bytes` |
| system.windows | diskQueue | `windows_logical_disk_requests_queued` |
| system.windows | diskReadBytes | `windows_logical_disk_read_bytes_total` |
| system.windows | diskReadIops | `windows_logical_disk_reads_total` |
| system.windows | diskReadLatency | `windows_logical_disk_read_latency_seconds_total`<br>`windows_logical_disk_reads_total` |
| system.windows | diskSize | `windows_logical_disk_size_bytes` |
| system.windows | diskUsedRatio | `windows_logical_disk_free_bytes`<br>`windows_logical_disk_size_bytes` |
| system.windows | diskWriteBytes | `windows_logical_disk_write_bytes_total` |
| system.windows | diskWriteIops | `windows_logical_disk_writes_total` |
| system.windows | diskWriteLatency | `windows_logical_disk_write_latency_seconds_total`<br>`windows_logical_disk_writes_total` |
| system.windows | exceptions | `windows_system_exception_dispatches_total` |
| system.windows | memAvailable | `windows_memory_available_bytes` |
| system.windows | memCache | `windows_memory_cache_bytes` |
| system.windows | memCommitLimit | `windows_memory_commit_limit` |
| system.windows | memCommitted | `windows_memory_committed_bytes` |
| system.windows | memFree | `windows_memory_physical_free_bytes` |
| system.windows | memPageFaults | `windows_memory_page_faults_total` |
| system.windows | memPoolNonpaged | `windows_memory_pool_nonpaged_bytes` |
| system.windows | memPoolPaged | `windows_memory_pool_paged_bytes` |
| system.windows | memSwapOps | `windows_memory_swap_page_operations_total` |
| system.windows | memTotal | `windows_memory_physical_total_bytes` |
| system.windows | memUsed | `windows_memory_available_bytes`<br>`windows_memory_physical_total_bytes` |
| system.windows | memUsedRatio | `windows_memory_available_bytes`<br>`windows_memory_physical_total_bytes` |
| system.windows | netBandwidth | `windows_net_current_bandwidth_bytes` |
| system.windows | netDiscards | `windows_net_packets_outbound_discarded_total`<br>`windows_net_packets_received_discarded_total` |
| system.windows | netErrors | `windows_net_packets_outbound_errors_total`<br>`windows_net_packets_received_errors_total` |
| system.windows | netPacketsRecv | `windows_net_packets_received_total` |
| system.windows | netPacketsSent | `windows_net_packets_sent_total` |
| system.windows | netQueue | `windows_net_output_queue_length_packets` |
| system.windows | netRecv | `windows_net_bytes_received_total` |
| system.windows | netSent | `windows_net_bytes_sent_total` |
| system.windows | netUtil | `windows_net_bytes_total`<br>`windows_net_current_bandwidth_bytes` |
| system.windows | ntpRoundTrip | `windows_time_ntp_round_trip_delay_seconds` |
| system.windows | osInfo | `windows_os_info` |
| system.windows | procQueue | `windows_system_processor_queue_length` |
| system.windows | processes | `windows_system_processes` |
| system.windows | systemCalls | `windows_system_system_calls_total` |
| system.windows | threads | `windows_system_threads` |
| system.windows | timeOffset | `windows_time_computed_time_offset_seconds` |
| system.windows | uptime | `windows_system_boot_time_timestamp` |

## Live metrics (102)

- `windows_cpu_clock_interrupts_total`
- `windows_cpu_core_frequency_mhz`
- `windows_cpu_cstate_seconds_total`
- `windows_cpu_dpcs_total`
- `windows_cpu_idle_break_events_total`
- `windows_cpu_interrupts_total`
- `windows_cpu_logical_processor`
- `windows_cpu_parking_status`
- `windows_cpu_processor_mperf_total`
- `windows_cpu_processor_performance_total`
- `windows_cpu_processor_privileged_utility_total`
- `windows_cpu_processor_rtc_total`
- `windows_cpu_processor_utility_total`
- `windows_cpu_time_total`
- `windows_logical_disk_avg_read_requests_queued`
- `windows_logical_disk_avg_write_requests_queued`
- `windows_logical_disk_free_bytes`
- `windows_logical_disk_idle_seconds_total`
- `windows_logical_disk_info`
- `windows_logical_disk_read_bytes_total`
- `windows_logical_disk_read_latency_seconds_total`
- `windows_logical_disk_read_seconds_total`
- `windows_logical_disk_read_write_latency_seconds_total`
- `windows_logical_disk_reads_total`
- `windows_logical_disk_requests_queued`
- `windows_logical_disk_size_bytes`
- `windows_logical_disk_split_ios_total`
- `windows_logical_disk_write_bytes_total`
- `windows_logical_disk_write_latency_seconds_total`
- `windows_logical_disk_write_seconds_total`
- `windows_logical_disk_writes_total`
- `windows_memory_available_bytes`
- `windows_memory_cache_bytes`
- `windows_memory_cache_bytes_peak`
- `windows_memory_cache_faults_total`
- `windows_memory_commit_limit`
- `windows_memory_committed_bytes`
- `windows_memory_demand_zero_faults_total`
- `windows_memory_free_and_zero_page_list_bytes`
- `windows_memory_free_system_page_table_entries`
- `windows_memory_modified_page_list_bytes`
- `windows_memory_page_faults_total`
- `windows_memory_physical_free_bytes`
- `windows_memory_physical_total_bytes`
- `windows_memory_pool_nonpaged_allocs_total`
- `windows_memory_pool_nonpaged_bytes`
- `windows_memory_pool_paged_allocs_total`
- `windows_memory_pool_paged_bytes`
- `windows_memory_pool_paged_resident_bytes`
- `windows_memory_process_memory_limit_bytes`
- `windows_memory_standby_cache_core_bytes`
- `windows_memory_standby_cache_normal_priority_bytes`
- `windows_memory_standby_cache_reserve_bytes`
- `windows_memory_swap_page_operations_total`
- `windows_memory_swap_page_reads_total`
- `windows_memory_swap_page_writes_total`
- `windows_memory_swap_pages_read_total`
- `windows_memory_swap_pages_written_total`
- `windows_memory_system_cache_resident_bytes`
- `windows_memory_system_code_resident_bytes`
- `windows_memory_system_code_total_bytes`
- `windows_memory_system_driver_resident_bytes`
- `windows_memory_system_driver_total_bytes`
- `windows_memory_transition_faults_total`
- `windows_memory_transition_pages_repurposed_total`
- `windows_memory_write_copies_total`
- `windows_net_bytes_received_total`
- `windows_net_bytes_sent_total`
- `windows_net_bytes_total`
- `windows_net_current_bandwidth_bytes`
- `windows_net_nic_address_info`
- `windows_net_nic_info`
- `windows_net_nic_operation_status`
- `windows_net_output_queue_length_packets`
- `windows_net_packets_outbound_discarded_total`
- `windows_net_packets_outbound_errors_total`
- `windows_net_packets_received_discarded_total`
- `windows_net_packets_received_errors_total`
- `windows_net_packets_received_total`
- `windows_net_packets_received_unknown_total`
- `windows_net_packets_sent_total`
- `windows_net_packets_total`
- `windows_os_hostname`
- `windows_os_info`
- `windows_system_boot_time_timestamp`
- `windows_system_context_switches_total`
- `windows_system_exception_dispatches_total`
- `windows_system_processes`
- `windows_system_processes_limit`
- `windows_system_processor_queue_length`
- `windows_system_system_calls_total`
- `windows_system_threads`
- `windows_time_clock_frequency_adjustment`
- `windows_time_clock_frequency_adjustment_ppb`
- `windows_time_clock_sync_source`
- `windows_time_computed_time_offset_seconds`
- `windows_time_current_timestamp_seconds`
- `windows_time_ntp_client_time_sources`
- `windows_time_ntp_round_trip_delay_seconds`
- `windows_time_ntp_server_incoming_requests_total`
- `windows_time_ntp_server_outgoing_responses_total`
- `windows_time_timezone`
