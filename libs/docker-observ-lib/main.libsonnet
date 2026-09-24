// observ-viz Docker containers pack (hand-written).
// cAdvisor container metrics for Docker workloads, emitted as native v2 elements.
// Usage:
//   g.libs.system.docker.new({ selector: 'job="cadvisor"' }).grafana.dashboard
//   g.libs.system.docker.new({...}).grafana.elements   // reuse in a board
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-docker',
      dashboardTitle: 'Docker containers',
      // node-level too: the containers on a host are reached from that host
      dashboardTags: ['docker', 'containers', 'app-level', 'node-level'],
      description: 'Container resource usage from cAdvisor on a Docker host: CPU, memory, network and disk IO per container.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'cadvisor_version_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withDescription(desc);

    local signals = {
      cpu: sig('CPU usage', 'sum by (name)(rate(container_cpu_usage_seconds_total{%(queriesSelector)s,name!=""}[$__rate_interval]))', 'short', desc='CPU cores used per container (cAdvisor on the Docker host).'),
      memUsage: sig('Memory usage', 'container_memory_usage_bytes{%(queriesSelector)s,name!=""}', 'bytes', desc='Total memory usage per container including page cache.'),
      memWorkingSet: sig('Working set memory', 'container_memory_working_set_bytes{%(queriesSelector)s,name!=""}', 'bytes', desc='Working-set memory per container, what an OOM kill is judged on.'),
      netRx: sig('Network received', 'rate(container_network_receive_bytes_total{%(queriesSelector)s,name!=""}[$__rate_interval])', 'Bps', desc='Bytes received per container per second.'),
      netTx: sig('Network transmitted', 'rate(container_network_transmit_bytes_total{%(queriesSelector)s,name!=""}[$__rate_interval])', 'Bps', desc='Bytes transmitted per container per second.'),
      diskWrite: sig('Disk write', 'rate(container_fs_writes_bytes_total{%(queriesSelector)s,name!=""}[$__rate_interval])', 'Bps', desc='Bytes written to block devices per container per second.'),
      diskRead: sig('Disk read', 'rate(container_fs_reads_bytes_total{%(queriesSelector)s,name!=""}[$__rate_interval])', 'Bps', desc='Bytes read from block devices per container per second.'),
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
          'CadvisorDown',
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('cadvisor_version_info', cfg.ruleSelector),
          '5m',
          'critical',
          {},
          { summary: 'cAdvisor on {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'ContainerHighCpu',
          'sum by (name) (rate(container_cpu_usage_seconds_total{name!=""' + rsComma + '}[5m])) > 0.9',
          '15m',
          'warning',
          {},
          { summary: 'Container {{ $labels.name }} on {{ $labels.instance }} CPU usage is above 0.9 cores.' }
        ),
        alert.rule.new(
          'ContainerHighMemory',
          'container_memory_working_set_bytes{name!=""' + rsComma + '} > 1e9',
          '15m',
          'warning',
          {},
          { summary: 'Container {{ $labels.name }} on {{ $labels.instance }} working set memory is above 1GB.' }
        ),
        alert.rule.new(
          'ContainerHighDiskWrite',
          'rate(container_fs_writes_bytes_total{name!=""' + rsComma + '}[5m]) > 5e7',
          '15m',
          'warning',
          {},
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
