// observ-viz UniFi pack (hand-written).
// Built for UnPoller's Prometheus endpoint (unpoller_* metrics) — controller,
// devices (UAP/USW/UXG) and wireless clients.
// Usage:
//   g.libs.networking.unifi.new({ selector: 'job="unpoller"' }).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-unifi',
      dashboardTitle: 'UniFi (UnPoller)',
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
        title: 'Clients',
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
