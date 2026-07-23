# cadvisor

- **source**: k8s-monitoring cAdvisor scrape
- **notes**: Scrape allowlist: only ~20 container_* families carry pod/namespace labels here; container_network_* is unlabeled.
- **patterns**: `container_cpu_.*`, `container_memory_.*`, `container_fs_.*`, `container_last_seen`, `container_network_.*`, `container_spec_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| kubernetes.cadvisor | cpuSystem | `container_cpu_system_seconds_total` |
| kubernetes.cadvisor | cpuThrottleRatio | `container_cpu_cfs_periods_total`<br>`container_cpu_cfs_throttled_periods_total` |
| kubernetes.cadvisor | cpuThrottling | `container_cpu_cfs_throttled_periods_total` |
| kubernetes.cadvisor | cpuUsage | `container_cpu_usage_seconds_total` |
| kubernetes.cadvisor | cpuUser | `container_cpu_user_seconds_total` |
| kubernetes.cadvisor | diskReadIops | `container_fs_reads_total` |
| kubernetes.cadvisor | diskReads | `container_fs_reads_bytes_total` |
| kubernetes.cadvisor | diskWriteIops | `container_fs_writes_total` |
| kubernetes.cadvisor | diskWrites | `container_fs_writes_bytes_total` |
| kubernetes.cadvisor | memCache | `container_memory_cache` |
| kubernetes.cadvisor | memRss | `container_memory_rss` |
| kubernetes.cadvisor | memSwap | `container_memory_swap` |
| kubernetes.cadvisor | memUsage | `container_memory_usage_bytes` |
| kubernetes.cadvisor | memWorkingSet | `container_memory_working_set_bytes` |
| kubernetes.cadvisor | specMemLimit | `container_spec_memory_limit_bytes` |
| kubernetes.pod | cpuThrottled | `container_cpu_cfs_periods_total`<br>`container_cpu_cfs_throttled_periods_total` |
| kubernetes.pod | cpuUsage | `container_cpu_usage_seconds_total` |
| kubernetes.pod | fsReads | `container_fs_reads_bytes_total` |
| kubernetes.pod | fsWrites | `container_fs_writes_bytes_total` |
| kubernetes.pod | memCache | `container_memory_cache` |
| kubernetes.pod | memRss | `container_memory_rss` |
| kubernetes.pod | memWorkingSet | `container_memory_working_set_bytes` |
| system.docker | cpu | `container_cpu_usage_seconds_total` |
| system.docker | diskRead | `container_fs_reads_bytes_total` |
| system.docker | diskWrite | `container_fs_writes_bytes_total` |
| system.docker | memUsage | `container_memory_usage_bytes` |
| system.docker | memWorkingSet | `container_memory_working_set_bytes` |
| system.docker | netRx | `container_network_receive_bytes_total` |
| system.docker | netTx | `container_network_transmit_bytes_total` |
| system.linux | dockerContainers | `container_last_seen` |
| system.linux | dockerCpu | `container_cpu_usage_seconds_total` |
| system.linux | dockerMem | `container_memory_usage_bytes` |

## Live metrics (47)

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
