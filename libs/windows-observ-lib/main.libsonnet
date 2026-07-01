// observ-viz Windows host pack (hand-written).
// windows_exporter host observability laid out as tabs: System (uptime/CPU/memory/
// disk/network), Applications (processes + Windows service states), and Logs
// (Windows event log via Loki). Plus windows_exporter alerting/recording rules.
// Emitted as native v2 elements. Usage:
//   g.libs.system.windows.new({ selector: 'job="windows"' }).grafana.dashboard
//   g.libs.system.windows.new({...}).grafana.elements   // reuse in a board
// Per-node board (cluster -> instance cascading selection), mirroring system.linux,
// so the Cluster Overview Servers table can drill straight to a single host.
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'node-windows',
      dashboardTitle: 'Windows Server',
      dashboardTags: ['windows'],
      datasource: '${datasource}',
      // cluster -> instance cascading selection (vars built by pack.build), so a
      // per-node drill (e.g. from Cluster Overview) lands on a single host.
      selector: 'job=~"$job", cluster=~"$cluster", instance=~"$instance"',
      varMetric: 'windows_os_info',
      varLabels: ['cluster', 'instance'],
      varMulti: false,
      // System primary tab + Applications/Logs tabs (rendered via showIfData/presence).
      primaryTabTitle: 'System',
      lokiDatasource: true,
      // Windows event logs shipped to Loki are labelled by instance (+ channel/level).
      logsSelector: 'instance=~"$instance"',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    // default legend carries the instance; per-dimension signals (disk/net/service)
    // append their volume/nic/name label.
    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);
    // Windows event log lines from Loki, scoped to the selected instance.
    local lsig(name, expr) =
      signal.new(name, 'loki', '${loki_datasource}', expr, 'short').filteringSelector(cfg.logsSelector);

    local signals = {
      // --- System ---
      uptime: sig('Uptime', 'time() - windows_system_boot_time_timestamp{%(queriesSelector)s}', 's'),

      // --- CPU ---
      cpuBusy: sig('CPU utilisation', '1 - avg without (core) (rate(windows_cpu_time_total{mode="idle",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),

      // --- Memory (windows_exporter memory collector; `available` ~ Linux MemAvailable) ---
      memTotal: sig('Physical memory total', 'windows_memory_physical_total_bytes{%(queriesSelector)s}', 'bytes'),
      memAvailable: sig('Physical memory available', 'windows_memory_available_bytes{%(queriesSelector)s}', 'bytes'),
      memFree: sig('Physical memory free', 'windows_memory_physical_free_bytes{%(queriesSelector)s}', 'bytes'),
      memUsed: sig('Physical memory used', 'windows_memory_physical_total_bytes{%(queriesSelector)s} - windows_memory_available_bytes{%(queriesSelector)s}', 'bytes'),
      memUsedRatio: sig('Memory used ratio', '1 - windows_memory_available_bytes{%(queriesSelector)s} / windows_memory_physical_total_bytes{%(queriesSelector)s}', 'percentunit'),
      memCommitted: sig('Committed memory', 'windows_memory_committed_bytes{%(queriesSelector)s}', 'bytes'),

      // --- Disk ---
      diskFree: sig('Logical disk free', 'windows_logical_disk_free_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} / {{volume}}'),
      diskUsedRatio: sig('Logical disk used ratio', '1 - windows_logical_disk_free_bytes{%(queriesSelector)s} / windows_logical_disk_size_bytes{%(queriesSelector)s}', 'percentunit', '{{instance}} / {{volume}}'),

      // --- Network ---
      netRecv: sig('Network received', 'rate(windows_net_bytes_received_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{nic}}'),
      netSent: sig('Network sent', 'rate(windows_net_bytes_sent_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{nic}}'),

      // --- Applications (processes + Windows services) ---
      processes: sig('Processes', 'windows_system_processes{%(queriesSelector)s}', 'short'),
      servicesRunning: sig('Running services', 'count(windows_service_state{state="running",%(queriesSelector)s} == 1)', 'short', 'running'),
      serviceState: sig('Service states', 'windows_service_state{%(queriesSelector)s}', 'short', '{{name}} / {{state}}'),

      // --- Logs (Windows event log via Loki) ---
      winLogs: lsig('Windows event log', '{%(queriesSelector)s}'),
    };

    pack.build(cfg, signals, [
      {
        title: 'System',
        width: 8,
        height: 6,
        elements: {
          uptime: signals.uptime.asStat('Uptime'),
          cpu: signals.cpuBusy.asStat('CPU utilisation'),
          memRatio: signals.memUsedRatio.asStat('Memory used ratio'),
        },
      },
      {
        title: 'CPU',
        width: 24,
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
          memUsed: signals.memUsed.asTimeSeries('Physical memory used'),
          memAvailable: signals.memAvailable.asTimeSeries('Physical memory available'),
          memFree: signals.memFree.asTimeSeries('Physical memory free'),
          memTotal: signals.memTotal.asTimeSeries('Physical memory total'),
          memCommitted: signals.memCommitted.asTimeSeries('Committed memory'),
        },
      },
      {
        title: 'Disk',
        width: 12,
        height: 7,
        elements: {
          diskUsedRatio: signals.diskUsedRatio.asTable('Logical disk used ratio'),
          diskFree: signals.diskFree.asTimeSeries('Logical disk free'),
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
    ], [
      // alerting rule group
      alert.rule.group('windows', [
        alert.rule.new(
          'WindowsHostDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'Windows host {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'WindowsHighCpu',
          '1 - avg without (core) (rate(windows_cpu_time_total{mode="idle"' + rsComma + '}[5m])) > 0.9',
          '15m', 'warning', {},
          { summary: 'CPU on {{ $labels.instance }} is above 90%.' }
        ),
        alert.rule.new(
          'WindowsHighMemory',
          '1 - windows_memory_available_bytes' + rsBrace + ' / windows_memory_physical_total_bytes' + rsBrace + ' > 0.9',
          '15m', 'warning', {},
          { summary: 'Physical memory on {{ $labels.instance }} is above 90%.' }
        ),
        alert.rule.new(
          'WindowsLowDiskSpace',
          'windows_logical_disk_free_bytes' + rsBrace + ' < 5e9',
          '15m', 'warning', {},
          { summary: 'Logical disk {{ $labels.volume }} on {{ $labels.instance }} has less than 5GB free.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('windows.rules', [
        alert.rule.record('instance:windows_cpu_utilisation:rate5m', '1 - avg without (core) (rate(windows_cpu_time_total{mode="idle"' + rsComma + '}[5m]))'),
        alert.rule.record('instance:windows_memory_utilisation:ratio', '1 - windows_memory_available_bytes' + rsBrace + ' / windows_memory_physical_total_bytes' + rsBrace),
        alert.rule.record('instance:windows_logical_disk_free_bytes:sum', 'sum without (volume) (windows_logical_disk_free_bytes' + rsBrace + ')'),
      ]),
    ], [
      // optional tabs — render only when their metrics/logs are present.
      {
        title: 'Workload',
        width: 12,
        height: 7,
        presence: { query: 'windows_service_state{instance=~"$instance"}', label: 'instance' },
        elements: {
          processes: signals.processes.asStat('Processes'),
          servicesRunning: signals.servicesRunning.asStat('Running services'),
          serviceState: signals.serviceState.asTable('Service states'),
        },
      },
      {
        title: 'Logs',
        width: 24,
        height: 12,
        elements: {
          winLogs: panel.logs.new('Windows event log') + panel.logs.withTargets([signals.winLogs.asTarget()]),
        },
      },
    ]),
}
