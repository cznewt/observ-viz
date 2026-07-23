# unix.cpu

- **source**: node_exporter (alloy prometheus.exporter.unix)
- **notes**: node_cpu_info needs the cpu info flag (alloy-resources enable_cpu_info, default on since 2026-07-22).
- **patterns**: `node_cpu_seconds_total`, `node_cpu_info`, `node_cpu_scaling_frequency_.*`, `node_cpu_frequency_.*`, `node_schedstat_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.linux | cpuBusy | `node_cpu_seconds_total` |
| system.linux | cpuFreq | `node_cpu_scaling_frequency_hertz` |
| system.linux | cpuMode | `node_cpu_seconds_total` |
| system.linux | loadPerCpu | `node_cpu_seconds_total`<br>`node_load1` |
| system.linux | schedWait | `node_schedstat_waiting_seconds_total` |

## Live metrics (11)

- `node_cpu_frequency_hertz`
- `node_cpu_frequency_max_hertz`
- `node_cpu_frequency_min_hertz`
- `node_cpu_info`
- `node_cpu_scaling_frequency_hertz`
- `node_cpu_scaling_frequency_max_hertz`
- `node_cpu_scaling_frequency_min_hertz`
- `node_cpu_seconds_total`
- `node_schedstat_running_seconds_total`
- `node_schedstat_timeslices_total`
- `node_schedstat_waiting_seconds_total`
