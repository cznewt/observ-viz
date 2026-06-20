// observ-viz Home Assistant observ-lib (hand-written).
// Signals for the home-assistant-exporter (hass_* metrics): estate overview,
// device batteries, and wireless device properties (ESPHome Wi-Fi RSSI/uptime,
// ZHA Zigbee LQI/RSSI). The canonical copy ships with the exporter repo.
//   g.libs.iot.homeAssistant.new({ selector: 'job="home-assistant-exporter"' })
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-home-assistant',
      dashboardTitle: 'Home Assistant',
      dashboardTags: ['home-assistant', 'iot', 'esphome', 'zha'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'hass_device_info',
    } + config;

    local sig(name, expr, unit, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withDescription(desc);

    local signals = {
      devices: sig('Devices', 'count(hass_device_info{%(queriesSelector)s})', 'short', 'Registered devices.'),
      areas: sig('Areas', 'count(hass_area_info{%(queriesSelector)s})', 'short', 'Configured areas.'),
      entities: sig('Entities', 'count(hass_entity_info{%(queriesSelector)s})', 'short', 'Registered entities.'),
      entitiesAvailable: sig('Entities available', 'avg(hass_entity_available{%(queriesSelector)s})', 'percentunit', 'Fraction of entities reporting available.'),
      unavailable: sig('Unavailable entities', 'count(hass_entity_available{%(queriesSelector)s} == 0)', 'short', 'Entities currently unavailable.'),
      stale: sig('Stale entities', 'count((time() - hass_entity_last_update{%(queriesSelector)s}) > 3600)', 'short', 'Entities not updated in >1h.'),
      battery: sig('Battery remaining', 'hass_device_battery_remaining{%(queriesSelector)s}', 'percent', 'Remaining battery charge per device.'),
      batteryVoltage: sig('Battery voltage', 'hass_device_battery_voltage{%(queriesSelector)s}', 'volt', 'Battery voltage per device.'),
      lowBattery: sig('Low batteries', 'count(hass_device_battery_remaining{%(queriesSelector)s} < 20)', 'short', 'Devices below 20% battery.'),
      esphomeRssi: sig('ESPHome Wi-Fi RSSI', 'hass_esphome_device_rssi{%(queriesSelector)s}', 'dBm', 'WiFi signal strength of ESPHome devices.'),
      esphomeUptime: sig('ESPHome uptime', 'hass_esphome_device_uptime{%(queriesSelector)s}', 's', 'ESPHome device uptime.'),
      zhaRssi: sig('Zigbee RSSI', 'hass_zha_device_rssi{%(queriesSelector)s}', 'dBm', 'Received signal strength of Zigbee devices.'),
      zhaLqi: sig('Zigbee LQI', 'hass_zha_device_lqi{%(queriesSelector)s}', 'short', 'Link quality of Zigbee devices.'),
      zhaAvailable: sig('ZHA availability', 'avg(hass_device_available{%(queriesSelector)s})', 'percentunit', 'Fraction of ZHA devices available.'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 5,
        elements: {
          devices: signals.devices.asStat('Devices'),
          areas: signals.areas.asStat('Areas'),
          entities: signals.entities.asStat('Entities'),
          entitiesAvailable: signals.entitiesAvailable.asStat('Available'),
          unavailable: signals.unavailable.asStat('Unavailable'),
          stale: signals.stale.asStat('Stale'),
        },
      },
      {
        title: 'Batteries',
        width: 8,
        height: 8,
        elements: {
          battery: signals.battery.asTable('Battery remaining'),
          batteryVoltage: signals.batteryVoltage.asTimeSeries('Battery voltage'),
          lowBattery: signals.lowBattery.asStat('Low batteries'),
        },
      },
      {
        title: 'ESPHome (Wi-Fi)',
        width: 12,
        height: 8,
        elements: {
          esphomeRssi: signals.esphomeRssi.asTimeSeries('Wi-Fi RSSI'),
          esphomeUptime: signals.esphomeUptime.asTimeSeries('Uptime'),
        },
      },
      {
        title: 'Zigbee (ZHA)',
        width: 8,
        height: 8,
        elements: {
          zhaRssi: signals.zhaRssi.asTimeSeries('Zigbee RSSI'),
          zhaLqi: signals.zhaLqi.asTimeSeries('Zigbee LQI'),
          zhaAvailable: signals.zhaAvailable.asStat('ZHA available'),
        },
      },
    ]),
}
