# windows.other

- **source**: windows_exporter (unclassified families)
- **patterns**: `windows_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.windows | collectorDuration | `windows_exporter_collector_duration_seconds` |
| system.windows | collectorSuccess | `windows_exporter_collector_success` |
| system.windows | scrapeDuration | `windows_exporter_scrape_duration_seconds` |
| system.windows | tempBySensor | `ohm_`<br>`windows_thermalzone_temperature_celsius` |
| system.windows | tempMax | `ohm_`<br>`windows_thermalzone_temperature_celsius` |

## Live metrics (5)

- `windows_exporter_build_info`
- `windows_exporter_collector_duration_seconds`
- `windows_exporter_collector_success`
- `windows_exporter_collector_timeout`
- `windows_exporter_scrape_duration_seconds`
