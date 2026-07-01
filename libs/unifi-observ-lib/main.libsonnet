// observ-viz UniFi pack (hand-written).
// Built for UnPoller's Prometheus endpoint (unpoller_* metrics) — controller,
// devices (UAP/USW/UXG) and wireless clients.
// Usage:
//   g.libs.networking.unifi.new({ selector: 'job="unpoller"' }).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'network-unifi-control',
      dashboardTitle: 'Unifi Controller',
      dashboardTags: ['unifi', 'unpoller', 'network'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'unpoller_device_info',
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';

    local sig(name, expr, unit, legend='{{name}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      // controller / inventory
      controllerUptime: sig('Controller uptime', 'unpoller_controller_uptime_seconds{%(queriesSelector)s}', 's', '{{hostname}}'),
      updateAvailable: sig('Update available', 'sum(unpoller_controller_update_available{%(queriesSelector)s})', 'short', 'update'),
      deviceCount: sig('Devices', 'count(unpoller_device_info{%(queriesSelector)s})', 'short', 'devices'),
      clientCount: sig('Clients', 'count(unpoller_client_uptime_seconds{%(queriesSelector)s})', 'short', 'clients'),

      // devices (per name)
      deviceCpu: sig('Device CPU', 'unpoller_device_cpu_utilization_ratio{%(queriesSelector)s}', 'percentunit'),
      deviceMem: sig('Device memory', 'unpoller_device_memory_utilization_ratio{%(queriesSelector)s}', 'percentunit'),
      deviceTemp: sig('Device temperature', 'unpoller_device_temperature_celsius{%(queriesSelector)s}', 'celsius'),
      deviceLoad: sig('Device load 1m', 'unpoller_device_load_average_1{%(queriesSelector)s}', 'short'),
      deviceRx: sig('Device LAN received', 'rate(unpoller_device_lan_receive_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
      deviceTx: sig('Device LAN transmitted', 'rate(unpoller_device_lan_transmit_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
      uplinkLatency: sig('Uplink latency', 'unpoller_device_uplink_latency_seconds{%(queriesSelector)s}', 's'),

      // clients (per name)
      clientRx: sig('Clients received', 'sum(rate(unpoller_client_receive_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'received'),
      clientTx: sig('Clients transmitted', 'sum(rate(unpoller_client_transmit_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'transmitted'),
      clientRssi: sig('Client RSSI', 'unpoller_client_rssi_db{%(queriesSelector)s}', 'none'),
      clientSignal: sig('Client signal', 'unpoller_client_radio_signal_db{%(queriesSelector)s}', 'none'),
      clientSatisfaction: sig('Client satisfaction', 'unpoller_client_satisfaction_ratio{%(queriesSelector)s}', 'percentunit'),
    };

    // Per-client overview table (like the UniFi client list): identity from the
    // uptime series, other metrics summed by mac so only the join key survives (no
    // duplicate label columns). Wired clients simply have blank RSSI/SSID.
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local clientsTable =
      panel.table.new('Clients')
      + panel.table.withTargets([
        tq('unpoller_client_uptime_seconds{' + cfg.selector + '}'),                     // A: identity + Uptime
        tq('sum by (mac) (unpoller_client_receive_bytes_total{' + cfg.selector + '})'),   // B: Down (rx)
        tq('sum by (mac) (unpoller_client_transmit_bytes_total{' + cfg.selector + '})'),  // C: Up (tx)
        tq('sum by (mac) (unpoller_client_rssi_db{' + cfg.selector + '})'),               // D: RSSI (wireless)
        tq('sum by (mac) (unpoller_client_satisfaction_ratio{' + cfg.selector + '})'),    // E: Satisfaction
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['mac', 'name', 'ip', 'ap_name', 'essid', 'Value #A', 'Value #B', 'Value #C', 'Value #D', 'Value #E'] } } },
        { id: 'seriesToColumns', options: { byField: 'mac' } },
        { id: 'organize', options: {
          excludeByName: { mac: true },
          indexByName: { name: 0, ip: 1, ap_name: 2, essid: 3, 'Value #D': 4, 'Value #E': 5, 'Value #B': 6, 'Value #C': 7, 'Value #A': 8 },
          renameByName: { name: 'Client', ip: 'IP', ap_name: 'AP', essid: 'SSID', 'Value #A': 'Uptime', 'Value #B': 'Down', 'Value #C': 'Up', 'Value #D': 'RSSI', 'Value #E': 'Satisfaction' },
        } },
      ])
      + panel.table.withOverrides([
        ov('Down|Up', [{ id: 'unit', value: 'bytes' }]),
        ov('Uptime', [{ id: 'unit', value: 'dtdurations' }]),
        ov('Satisfaction', [{ id: 'unit', value: 'percentunit' }, { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } }, { id: 'min', value: 0 }, { id: 'max', value: 1 }]),
      ]);

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 6,
        height: 5,
        elements: {
          deviceCount: signals.deviceCount.asStat('Devices'),
          clientCount: signals.clientCount.asStat('Clients'),
          controllerUptime: signals.controllerUptime.asStat('Controller uptime'),
          updateAvailable: signals.updateAvailable.asStat('Update available'),
        },
      },
      {
        title: 'Clients',
        width: 24,
        height: 9,
        elements: {
          clientsTable: clientsTable,
        },
      },
      {
        title: 'Devices',
        width: 12,
        height: 7,
        elements: {
          deviceCpu: signals.deviceCpu.asTimeSeries('CPU utilization'),
          deviceMem: signals.deviceMem.asTimeSeries('Memory utilization'),
          deviceTemp: signals.deviceTemp.asTimeSeries('Temperature'),
          deviceLoad: signals.deviceLoad.asTimeSeries('Load 1m'),
          deviceRx: signals.deviceRx.asTimeSeries('LAN received'),
          deviceTx: signals.deviceTx.asTimeSeries('LAN transmitted'),
          uplinkLatency: signals.uplinkLatency.asTimeSeries('Uplink latency'),
        },
      },
      {
        title: 'Client trends',
        width: 12,
        height: 7,
        elements: {
          clientRx: signals.clientRx.asTimeSeries('Clients received'),
          clientTx: signals.clientTx.asTimeSeries('Clients transmitted'),
          clientSatisfaction: signals.clientSatisfaction.asTimeSeries('Satisfaction'),
          clientRssi: signals.clientRssi.asTimeSeries('RSSI'),
          clientSignal: signals.clientSignal.asTimeSeries('Signal'),
        },
      },
    ], [
      alert.rule.group('unifi', [
        alert.rule.new(
          'UnifiDeviceHighTemperature',
          'unpoller_device_temperature_celsius' + rsBrace + ' > 80',
          '10m',
          'warning',
          {},
          {
            summary: 'UniFi device running hot.',
            description: 'UniFi device {{ $labels.name }} temperature is {{ printf "%.0f" $value }}°C (>80°C) for 10m.',
          }
        ),
        alert.rule.new(
          'UnifiControllerUpdateAvailable',
          'sum(unpoller_controller_update_available{' + cfg.ruleSelector + '}) > 0',
          '6h',
          'info',
          {},
          { summary: 'A UniFi controller/device update is available.' }
        ),
      ]),
    ]),
}
