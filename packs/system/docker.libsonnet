// observ-viz Docker containers pack (hand-written).
// cAdvisor container metrics for Docker workloads, emitted as native v2 elements.
// Usage:
//   g.packs.system.docker.new({ selector: 'job="cadvisor"' }).grafana.dashboard
//   g.packs.system.docker.new({...}).grafana.elements   // reuse in a board
local pack = import 'packs/_pack.libsonnet';
local signal = import 'signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-docker',
      dashboardTitle: 'Docker containers',
      dashboardTags: ['docker', 'containers'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'cadvisor_version_info',
    } + config;

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
    ]),
}
