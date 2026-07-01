# Unifi Controller  (`g.libs.networking.unifi`)

Dashboard uid `network-unifi-control` · 16 signals · 2 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `clientCount` | short | `count(unpoller_client_uptime_seconds{job=~"$job"})` | — |
| `clientRssi` | none | `unpoller_client_rssi_db{job=~"$job"}` | — |
| `clientRx` | Bps | `sum(rate(unpoller_client_receive_bytes_total{job=~"$job"}[$__rate_interval]))` | — |
| `clientSatisfaction` | percentunit | `unpoller_client_satisfaction_ratio{job=~"$job"}` | — |
| `clientSignal` | none | `unpoller_client_radio_signal_db{job=~"$job"}` | — |
| `clientTx` | Bps | `sum(rate(unpoller_client_transmit_bytes_total{job=~"$job"}[$__rate_interval]))` | — |
| `controllerUptime` | s | `unpoller_controller_uptime_seconds{job=~"$job"}` | — |
| `deviceCount` | short | `count(unpoller_device_info{job=~"$job"})` | — |
| `deviceCpu` | percentunit | `unpoller_device_cpu_utilization_ratio{job=~"$job"}` | — |
| `deviceLoad` | short | `unpoller_device_load_average_1{job=~"$job"}` | — |
| `deviceMem` | percentunit | `unpoller_device_memory_utilization_ratio{job=~"$job"}` | — |
| `deviceRx` | Bps | `rate(unpoller_device_lan_receive_bytes_total{job=~"$job"}[$__rate_interval])` | — |
| `deviceTemp` | celsius | `unpoller_device_temperature_celsius{job=~"$job"}` | — |
| `deviceTx` | Bps | `rate(unpoller_device_lan_transmit_bytes_total{job=~"$job"}[$__rate_interval])` | — |
| `updateAvailable` | short | `sum(unpoller_controller_update_available{job=~"$job"})` | — |
| `uplinkLatency` | s | `unpoller_device_uplink_latency_seconds{job=~"$job"}` | — |

## Dashboard

- **Overview** — `clientCount`, `controllerUptime`, `deviceCount`, `updateAvailable`
- **Clients** — `clientsTable`
- **Devices** — `deviceCpu`, `deviceLoad`, `deviceMem`, `deviceRx`, `deviceTemp`, `deviceTx`, `uplinkLatency`
- **Client trends** — `clientRssi`, `clientRx`, `clientSatisfaction`, `clientSignal`, `clientTx`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `UnifiDeviceHighTemperature` | warning | 10m | — |
| `UnifiControllerUpdateAvailable` | info | 6h | — |
