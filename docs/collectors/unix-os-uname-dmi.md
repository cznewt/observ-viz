# unix.os-uname-dmi

- **source**: node_exporter
- **notes**: Device identity: system_vendor + product_version|product_name (firmware garbage fallback).
- **patterns**: `node_os_info`, `node_uname_info`, `node_dmi_info`, `node_boot_time_seconds`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.linux | batoceraOs | `node_os_info` |
| system.linux | batoceraTemp | `node_hwmon_temp_celsius`<br>`node_os_info` |
| system.linux | uptime | `node_boot_time_seconds` |

## Live metrics (4)

- `node_boot_time_seconds`
- `node_dmi_info`
- `node_os_info`
- `node_uname_info`
