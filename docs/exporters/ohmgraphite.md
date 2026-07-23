# ohmgraphite

- **source**: OhmGraphite (LibreHardwareMonitor), opt-in via alloy:hardware_sensors pillar

## battery

- **patterns**: `ohm_battery_.*`

### Live metrics (5)

- `ohm_battery_amps`
- `ohm_battery_level_percent`
- `ohm_battery_volts`
- `ohm_battery_watt_hours`
- `ohm_battery_watts`

## cpu

- **notes**: hardware label = CPU model name.
- **patterns**: `ohm_cpu_.*`

### Live metrics (6)

- `ohm_cpu_celsius`
- `ohm_cpu_factor`
- `ohm_cpu_hertz`
- `ohm_cpu_load_percent`
- `ohm_cpu_volts`
- `ohm_cpu_watts`

## gpu

- **notes**: per-vendor families; hardware label = GPU model.
- **patterns**: `ohm_gpunvidia_.*`, `ohm_gpuati_.*`, `ohm_gpuintel_.*`

### Live metrics (0)

_none currently in the datasource_

## hdd

- **notes**: hardware label = disk model.
- **patterns**: `ohm_hdd_.*`

### Live metrics (6)

- `ohm_hdd_bytes`
- `ohm_hdd_bytes_per_second`
- `ohm_hdd_celsius`
- `ohm_hdd_factor`
- `ohm_hdd_level_percent`
- `ohm_hdd_load_percent`

## mainboard

- **patterns**: `ohm_mainboard_.*`

### Live metrics (0)

_none currently in the datasource_

## memory

- **patterns**: `ohm_memory_.*`

### Live metrics (0)

_none currently in the datasource_

## other

- **patterns**: `ohm_.*`
- **consuming signals**: system.windows.tempBySensor, system.windows.tempMax

### Live metrics (8)

- `ohm_exporter_build_info`
- `ohm_nic_bytes`
- `ohm_nic_bytes_per_second`
- `ohm_nic_load_percent`
- `ohm_ram_bytes`
- `ohm_ram_celsius`
- `ohm_ram_load_percent`
- `ohm_ram_seconds`

