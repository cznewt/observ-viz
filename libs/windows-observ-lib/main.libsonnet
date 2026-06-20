// observ-viz Windows host pack (hand-written).
// Signals from windows_exporter, emitted as native v2 elements. Usage:
//   g.libs.system.windows.new({ selector: 'job="windows"' }).grafana.dashboard
//   g.libs.system.windows.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-windows',
      dashboardTitle: 'Windows host',
      dashboardTags: ['windows'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'windows_os_info',
    } + config;

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      cpuBusy: sig(
        'CPU utilisation',
        '1 - avg without(core)(rate(windows_cpu_time_total{mode="idle",%(queriesSelector)s}[$__rate_interval]))',
        'percentunit'
      ),
      memFree: sig('Physical memory free', 'windows_os_physical_memory_free_bytes{%(queriesSelector)s}', 'bytes'),
      memCommitted: sig('Committed memory', 'windows_memory_committed_bytes{%(queriesSelector)s}', 'bytes'),
      diskFree: sig('Logical disk free', 'windows_logical_disk_free_bytes{%(queriesSelector)s}', 'bytes'),
      serviceState: sig('Service states', 'windows_service_state{%(queriesSelector)s}', 'short'),
      netRecv: sig('Network received', 'rate(windows_net_bytes_received_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
      netSent: sig('Network sent', 'rate(windows_net_bytes_sent_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
    };

    pack.build(cfg, signals, [
      {
        title: 'CPU',
        width: 12,
        height: 7,
        elements: {
          cpuBusy: signals.cpuBusy.asTimeSeries('CPU utilisation'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memFree: signals.memFree.asTimeSeries('Physical memory free'),
          memCommitted: signals.memCommitted.asTimeSeries('Committed memory'),
        },
      },
      {
        title: 'Disk',
        width: 12,
        height: 7,
        elements: {
          diskFree: signals.diskFree.asTimeSeries('Logical disk free'),
          serviceState: signals.serviceState.asTable('Service states'),
        },
      },
      {
        title: 'Network',
        width: 12,
        height: 7,
        elements: {
          netRecv: signals.netRecv.asTimeSeries('Network received'),
          netSent: signals.netSent.asTimeSeries('Network sent'),
        },
      },
    ]),
}
