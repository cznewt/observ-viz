// observ-viz Home Assistant observ-lib (hand-written).
// Signals for the Home Assistant Prometheus integration / home-assistant-exporter
// (homeassistant_* metrics): climate/energy sensors, wireless device properties
// (battery, RSSI), and presence (device_tracker).
//   g.libs.iot.homeAssistant.new({ selector: 'job="home-assistant"' })
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-home-assistant',
      dashboardTitle: 'Home Assistant',
      dashboardTags: ['home-assistant', 'iot'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'homeassistant_entity_available',
    } + config;

    local sig(name, expr, unit, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withDescription(desc);

    local signals = {
      temperature: sig('Temperature', 'homeassistant_sensor_temperature_celsius{%(queriesSelector)s}', 'celsius', 'Temperature sensors.'),
      humidity: sig('Humidity', 'homeassistant_sensor_humidity_percent{%(queriesSelector)s}', 'humidity', 'Humidity sensors.'),
      power: sig('Power', 'homeassistant_sensor_power_w{%(queriesSelector)s}', 'watt', 'Per-entity power draw.'),
      energy: sig('Energy', 'homeassistant_sensor_energy_kwh{%(queriesSelector)s}', 'kwatth', 'Cumulative energy.'),
      battery: sig('Battery', 'homeassistant_sensor_battery_percent{%(queriesSelector)s}', 'percent', 'Wireless device battery levels.'),
      rssi: sig('Wi-Fi signal', 'homeassistant_sensor_signal_strength_dbm{%(queriesSelector)s}', 'dBm', 'Wireless device signal strength (RSSI).'),
      available: sig('Entities available', 'avg(homeassistant_entity_available{%(queriesSelector)s})', 'percentunit', 'Fraction of entities reporting.'),
      devicesHome: sig('Devices home', 'sum(homeassistant_device_tracker_state{%(queriesSelector)s})', 'short', 'Wireless devices currently home.'),
      stale: sig('Stale entities', 'count(time() - homeassistant_last_updated_time_seconds{%(queriesSelector)s} > 3600)', 'short', 'Entities not updated in >1h.'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Climate',
        width: 12,
        height: 8,
        elements: {
          temperature: signals.temperature.asTimeSeries('Temperature'),
          humidity: signals.humidity.asTimeSeries('Humidity'),
        },
      },
      {
        title: 'Energy',
        width: 8,
        height: 7,
        elements: {
          power: signals.power.asTimeSeries('Power'),
          energy: signals.energy.asStat('Energy'),
          available: signals.available.asStat('Entities available'),
        },
      },
      {
        title: 'Wireless devices',
        width: 8,
        height: 7,
        elements: {
          battery: signals.battery.asTable('Battery levels'),
          rssi: signals.rssi.asTimeSeries('Wi-Fi signal (RSSI)'),
          devicesHome: signals.devicesHome.asStat('Devices home'),
        },
      },
    ]),
}
