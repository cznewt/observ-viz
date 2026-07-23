# unix.hwmon

- **source**: node_exporter
- **notes**: CPU package temps: coretemp / AMD SMN pci0000:00_0000:00:18_3; nvme drive temps.
- **patterns**: `node_hwmon_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.linux | batoceraTemp | `node_hwmon_temp_celsius`<br>`node_os_info` |
| system.linux | tempCelsius | `node_hwmon_temp_celsius` |

## Live metrics (48)

- `node_hwmon_chip_names`
- `node_hwmon_curr_amps`
- `node_hwmon_curr_average_amps`
- `node_hwmon_curr_max_amps`
- `node_hwmon_fan_max_rpm`
- `node_hwmon_fan_min_rpm`
- `node_hwmon_fan_rpm`
- `node_hwmon_fan_target_rpm`
- `node_hwmon_in_average_volts`
- `node_hwmon_in_max_volts`
- `node_hwmon_in_min_volts`
- `node_hwmon_in_volts`
- `node_hwmon_power_cap_default_watt`
- `node_hwmon_power_cap_max_watt`
- `node_hwmon_power_cap_min_watt`
- `node_hwmon_power_cap_watt`
- `node_hwmon_power_watt`
- `node_hwmon_pwm`
- `node_hwmon_pwm_auto_point1_pwm`
- `node_hwmon_pwm_auto_point1_temp`
- `node_hwmon_pwm_auto_point2_pwm`
- `node_hwmon_pwm_auto_point2_temp`
- `node_hwmon_pwm_auto_point3_pwm`
- `node_hwmon_pwm_auto_point3_temp`
- `node_hwmon_pwm_auto_point4_pwm`
- `node_hwmon_pwm_auto_point4_temp`
- `node_hwmon_pwm_auto_point5_pwm`
- `node_hwmon_pwm_auto_point5_temp`
- `node_hwmon_pwm_enable`
- `node_hwmon_pwm_max`
- `node_hwmon_pwm_min`
- `node_hwmon_sensor_label`
- `node_hwmon_temp_alarm`
- `node_hwmon_temp_auto_point1_pwm_celsius`
- `node_hwmon_temp_auto_point1_temp_celsius`
- `node_hwmon_temp_auto_point1_temp_hyst_celsius`
- `node_hwmon_temp_celsius`
- `node_hwmon_temp_crit_alarm_celsius`
- `node_hwmon_temp_crit_celsius`
- `node_hwmon_temp_crit_hyst_celsius`
- `node_hwmon_temp_emergency_celsius`
- `node_hwmon_temp_emergency_hyst_celsius`
- `node_hwmon_temp_max_alarm_celsius`
- `node_hwmon_temp_max_celsius`
- `node_hwmon_temp_max_hyst_celsius`
- `node_hwmon_temp_min_alarm_celsius`
- `node_hwmon_temp_min_celsius`
- `node_hwmon_update_interval_seconds`
