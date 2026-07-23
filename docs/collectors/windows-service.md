# windows.service

- **source**: windows_exporter service collector
- **patterns**: `windows_service_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.windows | serviceState | `windows_service_state` |
| system.windows | servicesRunning | `windows_service_state` |
| system.windows | servicesStopped | `windows_service_state` |

## Live metrics (4)

- `windows_service_info`
- `windows_service_process`
- `windows_service_start_mode`
- `windows_service_state`
