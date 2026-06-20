// observ-viz Docker containers pack (hand-written).
// cAdvisor container metrics for Docker workloads, emitted as native v2 elements.
// Usage:
//   g.libs.system.docker.new({ selector: 'job="cadvisor"' }).grafana.dashboard
//   g.libs.system.docker.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-docker',
      dashboardTitle: 'Docker containers',
      dashboardTags: ['docker', 'containers'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'cadvisor_version_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      cpu: sig('CPU usage', 'sum by (name)(rate(container_cpu_usage_seconds_total{%(queriesSelector)s,name!=""}[$__rate_interval]))', 'short'),
      memUsage: sig('Memory usage', 'container_memory_usage_bytes{%(queriesSelector)s,name!=""}', 'bytes'),
      memWorkingSet: sig('Working set memory', 'container_memory_working_set_bytes{%(queriesSelector)s,name!=""}', 'bytes'),
      netRx: sig('Network received', 'rate(container_network_receive_bytes_total{%(queriesSelector)s,name!=""}[$__rate_interval])', 'Bps'),
      netTx: sig('Network transmitted', 'rate(container_network_transmit_bytes_total{%(queriesSelector)s,name!=""}[$__rate_interval])', 'Bps'),
      diskWrite: sig('Disk write', 'rate(container_fs_writes_bytes_total{%(queriesSelector)s,name!=""}[$__rate_interval])', 'Bps'),
      diskRead: sig('Disk read', 'rate(container_fs_reads_bytes_total{%(queriesSelector)s,name!=""}[$__rate_interval])', 'Bps'),
    };

    pack.build(cfg, signals, [
      {
        title: 'CPU',
        width: 12,
        height: 7,
        elements: {
          cpu: signals.cpu.asTimeSeries('CPU usage (cores)'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memUsage: signals.memUsage.asTimeSeries('Memory usage'),
          memWorkingSet: signals.memWorkingSet.asTimeSeries('Working set memory'),
        },
      },
      {
        title: 'Network',
        width: 12,
        height: 7,
        elements: {
          netRx: signals.netRx.asTimeSeries('Network received'),
          netTx: signals.netTx.asTimeSeries('Network transmitted'),
        },
      },
      {
        title: 'Disk IO',
        width: 12,
        height: 7,
        elements: {
          diskWrite: signals.diskWrite.asTimeSeries('Disk write'),
          diskRead: signals.diskRead.asTimeSeries('Disk read'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('docker', [
        alert.rule.new(
          'CadvisorDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'cAdvisor on {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'ContainerHighCpu',
          'sum by (name) (rate(container_cpu_usage_seconds_total{name!=""' + rsComma + '}[5m])) > 0.9',
          '15m', 'warning', {},
          { summary: 'Container {{ $labels.name }} on {{ $labels.instance }} CPU usage is above 0.9 cores.' }
        ),
        alert.rule.new(
          'ContainerHighMemory',
          'container_memory_working_set_bytes{name!=""' + rsComma + '} > 1e9',
          '15m', 'warning', {},
          { summary: 'Container {{ $labels.name }} on {{ $labels.instance }} working set memory is above 1GB.' }
        ),
        alert.rule.new(
          'ContainerHighDiskWrite',
          'rate(container_fs_writes_bytes_total{name!=""' + rsComma + '}[5m]) > 5e7',
          '15m', 'warning', {},
          { summary: 'Container {{ $labels.name }} on {{ $labels.instance }} disk write rate is above 50MB/s.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('docker.rules', [
        alert.rule.record('instance_name:container_cpu_usage:rate5m', 'sum by (name) (rate(container_cpu_usage_seconds_total{name!=""' + rsComma + '}[5m]))'),
        alert.rule.record('instance_name:container_memory_working_set_bytes:sum', 'sum by (name) (container_memory_working_set_bytes{name!=""' + rsComma + '})'),
      ]),
    ]),
}
