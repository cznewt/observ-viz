# cadvisor

- **source**: k8s-monitoring cAdvisor scrape

## container

- **notes**: Scrape allowlist: only ~20 container_* families carry pod/namespace labels here; container_network_* is unlabeled.
- **patterns**: `container_cpu_.*`, `container_memory_.*`, `container_fs_.*`, `container_last_seen`, `container_network_.*`, `container_spec_.*`
- **consuming signals**: kubernetes.cadvisor.cpuSystem, kubernetes.cadvisor.cpuThrottleRatio, kubernetes.cadvisor.cpuThrottling, kubernetes.cadvisor.cpuUsage, kubernetes.cadvisor.cpuUser, kubernetes.cadvisor.diskReadIops, kubernetes.cadvisor.diskReads, kubernetes.cadvisor.diskWriteIops, kubernetes.cadvisor.diskWrites, kubernetes.cadvisor.memCache, kubernetes.cadvisor.memRss, kubernetes.cadvisor.memSwap, kubernetes.cadvisor.memUsage, kubernetes.cadvisor.memWorkingSet, kubernetes.cadvisor.specMemLimit, kubernetes.pod.cpuThrottled, kubernetes.pod.cpuUsage, kubernetes.pod.fsReads, kubernetes.pod.fsWrites, kubernetes.pod.memCache, kubernetes.pod.memRss, kubernetes.pod.memWorkingSet, system.docker.cpu, system.docker.diskRead, system.docker.diskWrite, system.docker.memUsage, system.docker.memWorkingSet, system.docker.netRx, system.docker.netTx, system.linux.dockerContainers, system.linux.dockerCpu, system.linux.dockerMem

### Live metrics (47)

- `container_cpu_cfs_periods_total`
- `container_cpu_cfs_throttled_periods_total`
- `container_cpu_load_average_10s`
- `container_cpu_system_seconds_total`
- `container_cpu_usage_seconds_total`
- `container_cpu_user_seconds_total`
- `container_fs_inodes_free`
- `container_fs_inodes_total`
- `container_fs_io_current`
- `container_fs_io_time_seconds_total`
- `container_fs_io_time_weighted_seconds_total`
- `container_fs_limit_bytes`
- `container_fs_read_seconds_total`
- `container_fs_reads_bytes_total`
- `container_fs_reads_merged_total`
- `container_fs_reads_total`
- `container_fs_sector_reads_total`
- `container_fs_sector_writes_total`
- `container_fs_usage_bytes`
- `container_fs_write_seconds_total`
- `container_fs_writes_bytes_total`
- `container_fs_writes_merged_total`
- `container_fs_writes_total`
- `container_last_seen`
- `container_memory_cache`
- `container_memory_failcnt`
- `container_memory_failures_total`
- `container_memory_kernel_usage`
- `container_memory_mapped_file`
- `container_memory_max_usage_bytes`
- `container_memory_rss`
- `container_memory_swap`
- `container_memory_usage_bytes`
- `container_memory_working_set_bytes`
- `container_network_receive_bytes_total`
- `container_network_receive_errors_total`
- `container_network_receive_packets_dropped_total`
- `container_network_receive_packets_total`
- `container_network_transmit_bytes_total`
- `container_network_transmit_errors_total`
- `container_network_transmit_packets_dropped_total`
- `container_network_transmit_packets_total`
- `container_spec_cpu_period`
- `container_spec_cpu_shares`
- `container_spec_memory_limit_bytes`
- `container_spec_memory_reservation_limit_bytes`
- `container_spec_memory_swap_limit_bytes`

