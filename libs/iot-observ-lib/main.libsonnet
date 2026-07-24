// observ-viz Home Assistant pack (hand-written).
// Consumes the home_assistant_exporter job (hass_* metrics from the HAOS box):
// Core tab = inventory + availability + battery + sensor entity values (class
// metadata joined from hass_entity_info by entity_id); optional per-family
// device tabs, gated on the matching devices existing:
//   ESP        -> hass_device_info{manufacturer=~"Espressif.*"}
//   Zigbee     -> hass_device_info{integration="zha"} (+ ZHA mesh health)
//   Bluetooth  -> hass_device_info{integration="bluetooth"}
// Usage:
//   g.libs.iot.devices.new({}).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'home-assistant',
      dashboardTitle: 'Home Assistant',
      dashboardTags: ['iot', 'home-assistant', 'cluster-level'],
      datasource: '${datasource}',
      selector: 'cluster=~"$cluster"',
      varMetric: 'hass_device_info',
      varLabels: ['cluster'],
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster boards', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local s = cfg.selector;

    local sig(name, expr, unit, legend='{{device_name}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(s).withLegendFormat(legend);
    // entity values joined to their class metadata (value carries only entity_id)
    local classExpr(cls) =
      'hass_entity_value{%(queriesSelector)s} * on (cluster, entity_id) group_left(entity_name, device_name, area_id) (hass_entity_info{class="' + cls + '", %(queriesSelector)s} == 1)';

    local signals = {
      devices: sig('Devices', 'count(hass_device_info{%(queriesSelector)s})', 'short', 'devices'),
      available: sig('Available', 'count(hass_device_available{%(queriesSelector)s} == 1) or vector(0)', 'short', 'available'),
      lowBattery: sig('Low battery', 'count(hass_device_battery_remaining{%(queriesSelector)s} < 20) or vector(0)', 'short', 'low battery'),
      haUp: sig('Home Assistant up', 'sum(up{job="homeassistant", %(queriesSelector)s}) or vector(0)', 'short', 'up'),
      temperature: sig('Temperature', classExpr('temperature'), 'celsius', '{{entity_name}}'),
      humidity: sig('Humidity', classExpr('humidity'), 'percent', '{{entity_name}}'),
      pressure: sig('Pressure', classExpr('pressure'), 'pressurehpa', '{{entity_name}}'),
      battery: sig('Battery', 'hass_device_battery_remaining{%(queriesSelector)s}', 'percent'),
      meshLqi: sig('ZHA mesh LQI', 'avg(hass_zha_mesh_lqi{%(queriesSelector)s})', 'short', 'mesh LQI'),
      zhaLqi: sig('ZHA link quality', 'hass_zha_device_lqi{%(queriesSelector)s}', 'short'),
      zhaRssi: sig('ZHA RSSI', 'hass_zha_device_rssi{%(queriesSelector)s}', 'dBm'),
    };

    // Device inventory joined by device_id: identity labels from the info
    // metric (optionally family-filtered), availability / battery / last
    // activity as value columns.
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local devicesTable(title, filter='') =
      local infoSel = s + (if filter != '' then ', ' + filter else '');
      panel.table.new(title)
      + panel.table.withTargets([
        tq('hass_device_info{' + infoSel + '}'),                              // A: identity
        tq('sum by (device_id) (hass_device_available{' + s + '})'),          // B: available
        tq('sum by (device_id) (hass_device_battery_remaining{' + s + '})'),  // C: battery
        tq('sum by (device_id) (hass_device_last_activity{' + s + '} * 1000)'),  // D: last activity (ms)
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['device_id', 'device_name', 'manufacturer', 'model', 'integration', 'sw_version', 'Value #B', 'Value #C', 'Value #D'] } } },
        { id: 'seriesToColumns', options: { byField: 'device_id' } },
        // inner join on the (filtered) identity: drop rows the info query
        // did not return (i.e. other device families).
        { id: 'filterByValue', options: { filters: [{ fieldName: 'device_name', config: { id: 'isNotNull', options: {} } }], match: 'all', type: 'include' } },
        { id: 'organize', options: {
          excludeByName: { device_id: true, 'Value #A': true },
          indexByName: { device_name: 0, manufacturer: 1, model: 2, integration: 3, sw_version: 4, 'Value #B': 5, 'Value #C': 6, 'Value #D': 7 },
          renameByName: { device_name: 'Device', manufacturer: 'Manufacturer', model: 'Model', integration: 'Integration', sw_version: 'Firmware', 'Value #B': 'Available', 'Value #C': 'Battery', 'Value #D': 'Last activity' },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Device', desc: false }] } },
      ])
      + panel.table.withOverrides([
        ov('Device', [{ id: 'custom.width', value: 260 }]),
        ov('Available', [
          { id: 'custom.width', value: 90 },
          { id: 'mappings', value: [{ type: 'value', options: { '1': { text: 'up', color: 'green' }, '0': { text: 'down', color: 'red' } } }] },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ]),
        ov('Battery', [
          { id: 'unit', value: 'percent' }, { id: 'custom.width', value: 100 },
          { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } },
          { id: 'min', value: 0 }, { id: 'max', value: 100 },
          { id: 'thresholds', value: { mode: 'absolute', steps: [
            { color: 'red', value: null }, { color: 'yellow', value: 20 }, { color: 'green', value: 50 },
          ] } },
        ]),
        ov('Last activity', [{ id: 'unit', value: 'dateTimeFromNow' }, { id: 'custom.width', value: 130 }]),
      ]);

    // entity values for one device family (value -> entity_info -> device_info chain)
    local familyEntities(title, filter) =
      signal.new(title, 'prometheus', cfg.datasource,
        'hass_entity_value{%(queriesSelector)s}'
        + ' * on (cluster, entity_id) group_left(entity_name, device_id) (hass_entity_info{%(queriesSelector)s} == 1)'
        + ' * on (cluster, device_id) group_left() (hass_device_info{' + filter + ', %(queriesSelector)s} == 1)',
        'short').filteringSelector(s).withLegendFormat('{{entity_name}}');

    pack.build(cfg, signals, [
      {
        title: 'Core',
        width: 6,
        height: 5,
        elements: {
          haUp: signals.haUp.asStat('Home Assistant up'),
          devices: signals.devices.asStat('Devices'),
          available: signals.available.asStat('Available'),
          lowBattery: signals.lowBattery.asStat('Low battery'),
        },
      },
      {
        title: 'Devices',
        width: 24,
        height: 10,
        elements: {
          allDevices: devicesTable('Devices'),
        },
      },
      {
        title: 'Sensors',
        width: 12,
        height: 8,
        elements: {
          temperature: signals.temperature.asTimeSeries('Temperature'),
          humidity: signals.humidity.asTimeSeries('Humidity'),
          pressure: signals.pressure.asTimeSeries('Pressure'),
          battery: signals.battery.asTimeSeries('Battery'),
        },
      },
    ], [
      alert.rule.group('home-assistant', [
        alert.rule.new(
          'IotDeviceUnavailable',
          'hass_device_available' + rsBrace + ' == 0',
          '30m',
          'warning',
          {},
          {
            summary: 'IoT device unavailable.',
            description: 'Device {{ $labels.device_name }} ({{ $labels.cluster }}) has been unavailable for 30 minutes.',
          }
        ),
        alert.rule.new(
          'IotDeviceLowBattery',
          'hass_device_battery_remaining' + rsBrace + ' < 15',
          '1h',
          'warning',
          {},
          {
            summary: 'IoT device battery low.',
            description: 'Device {{ $labels.device_name }} ({{ $labels.cluster }}) battery at {{ $value }}%.',
          }
        ),
      ]),
    ], [], [
      {
        title: 'ESP Devices',
        width: 24,
        height: 9,
        presence: { query: 'hass_device_info{manufacturer=~"Espressif.*", cluster=~"$cluster"}', label: 'device_id' },
        elements: {
          espDevices: devicesTable('ESP devices', 'manufacturer=~"Espressif.*"'),
          espEntities: familyEntities('ESP entity values', 'manufacturer=~"Espressif.*"').asTimeSeries('ESP entity values'),
        },
      },
      {
        title: 'Zigbee Devices',
        width: 24,
        height: 8,
        presence: { query: 'hass_device_info{integration="zha", cluster=~"$cluster"}', label: 'device_id' },
        // element keys are laid out alphabetically — prefix to pin the order:
        // full-width table first, mesh health below.
        elements: {
          a_zigbee_devices: devicesTable('Zigbee devices', 'integration="zha"'),
          b_zha_lqi: signals.zhaLqi.asTimeSeries('Link quality (LQI)'),
          c_zha_rssi: signals.zhaRssi.asTimeSeries('RSSI'),
        },
      },
      {
        title: 'Bluetooth Devices',
        width: 24,
        height: 9,
        presence: { query: 'hass_device_info{integration="bluetooth", cluster=~"$cluster"}', label: 'device_id' },
        elements: {
          bluetoothDevices: devicesTable('Bluetooth devices', 'integration="bluetooth"'),
        },
      },
    ]),
}
