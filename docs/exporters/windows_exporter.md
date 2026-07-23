# windows_exporter

- **source**: alloy prometheus.exporter.windows (embedded)

## cpu

- **patterns**: `windows_cpu_.*`
- **consuming signals**: system.windows.cpuBusy, system.windows.cpuByMode, system.windows.cpuCState, system.windows.cpuCores, system.windows.cpuDpcs, system.windows.cpuFreq, system.windows.cpuInterrupts

### Live metrics (14)

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

## logical_disk

- **patterns**: `windows_logical_disk_.*`
- **consuming signals**: system.windows.diskActive, system.windows.diskFree, system.windows.diskQueue, system.windows.diskReadBytes, system.windows.diskReadIops, system.windows.diskReadLatency, system.windows.diskSize, system.windows.diskUsedRatio, system.windows.diskWriteBytes, system.windows.diskWriteIops, system.windows.diskWriteLatency

### Live metrics (17)

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

## memory

- **patterns**: `windows_memory_.*`
- **consuming signals**: system.windows.memAvailable, system.windows.memCache, system.windows.memCommitLimit, system.windows.memCommitted, system.windows.memFree, system.windows.memPageFaults, system.windows.memPoolNonpaged, system.windows.memPoolPaged, system.windows.memSwapOps, system.windows.memTotal, system.windows.memUsed, system.windows.memUsedRatio

### Live metrics (35)

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

## net

- **patterns**: `windows_net_.*`
- **consuming signals**: system.windows.netBandwidth, system.windows.netDiscards, system.windows.netErrors, system.windows.netPacketsRecv, system.windows.netPacketsSent, system.windows.netQueue, system.windows.netRecv, system.windows.netSent, system.windows.netUtil

### Live metrics (16)

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

## os

- **patterns**: `windows_os_.*`
- **consuming signals**: system.windows.osInfo

### Live metrics (2)

- `windows_os_hostname`
- `windows_os_info`

## other

- **notes**: unclassified windows_exporter families (catch-all).
- **patterns**: `windows_.*`
- **consuming signals**: system.windows.collectorDuration, system.windows.collectorSuccess, system.windows.scrapeDuration, system.windows.tempBySensor, system.windows.tempMax

### Live metrics (5)

- `windows_exporter_build_info`
- `windows_exporter_collector_duration_seconds`
- `windows_exporter_collector_success`
- `windows_exporter_collector_timeout`
- `windows_exporter_scrape_duration_seconds`

## service

- **patterns**: `windows_service_.*`
- **consuming signals**: system.windows.serviceState, system.windows.servicesRunning, system.windows.servicesStopped

### Live metrics (4)

- `windows_service_info`
- `windows_service_process`
- `windows_service_start_mode`
- `windows_service_state`

## system

- **patterns**: `windows_system_.*`
- **consuming signals**: system.windows.contextSwitches, system.windows.exceptions, system.windows.procQueue, system.windows.processes, system.windows.systemCalls, system.windows.threads, system.windows.uptime

### Live metrics (8)

- `windows_system_boot_time_timestamp`
- `windows_system_context_switches_total`
- `windows_system_exception_dispatches_total`
- `windows_system_processes`
- `windows_system_processes_limit`
- `windows_system_processor_queue_length`
- `windows_system_system_calls_total`
- `windows_system_threads`

## textfile-device

- **notes**: device.prom in C:\apps\alloy\textfile — one-shot Win32_ComputerSystemProduct write per box (vendor/product/model).
- **patterns**: `windows_device_info`, `windows_textfile_.*`

### Live metrics (2)

- `windows_device_info`
- `windows_textfile_mtime_seconds`

## time

- **patterns**: `windows_time_.*`
- **consuming signals**: system.windows.ntpRoundTrip, system.windows.timeOffset

### Live metrics (10)

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

