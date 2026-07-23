# ohmgraphite

- **source**: OhmGraphite (LibreHardwareMonitor), opt-in via alloy:hardware_sensors pillar
- **notes**: hardware label carries CPU/GPU/disk model names; gpu families are per vendor (gpunvidia/gpuati/gpuintel).
- **patterns**: `ohm_cpu_.*`, `ohm_gpunvidia_.*`, `ohm_gpuati_.*`, `ohm_gpuintel_.*`, `ohm_hdd_.*`, `ohm_battery_.*`, `ohm_memory_.*`, `ohm_mainboard_.*`

## Live metrics (34)

- `ohm_battery_amps`
- `ohm_battery_level_percent`
- `ohm_battery_volts`
- `ohm_battery_watt_hours`
- `ohm_battery_watts`
- `ohm_cpu_celsius`
- `ohm_cpu_factor`
- `ohm_cpu_hertz`
- `ohm_cpu_load_percent`
- `ohm_cpu_volts`
- `ohm_cpu_watts`
- `ohm_gpuati_bytes`
- `ohm_gpuati_celsius`
- `ohm_gpuati_factor`
- `ohm_gpuati_hertz`
- `ohm_gpuati_load_percent`
- `ohm_gpuati_volts`
- `ohm_gpuati_watts`
- `ohm_gpuintel_bytes`
- `ohm_gpuintel_hertz`
- `ohm_gpuintel_load_percent`
- `ohm_gpuintel_watts`
- `ohm_gpunvidia_bytes`
- `ohm_gpunvidia_bytes_per_second`
- `ohm_gpunvidia_celsius`
- `ohm_gpunvidia_hertz`
- `ohm_gpunvidia_load_percent`
- `ohm_gpunvidia_watts`
- `ohm_hdd_bytes`
- `ohm_hdd_bytes_per_second`
- `ohm_hdd_celsius`
- `ohm_hdd_factor`
- `ohm_hdd_level_percent`
- `ohm_hdd_load_percent`
