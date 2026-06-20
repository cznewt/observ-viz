// observ-viz Linux node pack (hand-written).
// node_exporter host metrics (CPU/load, memory, disk/filesystem, network),
// emitted as native v2 elements. Usage:
//   g.libs.system.linux.new({ selector: 'job="node"' }).grafana.dashboard
//   g.libs.system.linux.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-linux',
      dashboardTitle: 'Linux node',
      dashboardTags: ['linux', 'node'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'node_uname_info',
    } + config;

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      cpuBusy: sig('CPU busy', '1 - avg without(cpu,mode)(rate(node_cpu_seconds_total{mode="idle",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      load1: sig('Load 1m', 'node_load1{%(queriesSelector)s}', 'short'),
      memUsed: sig('Memory used', 'node_memory_MemTotal_bytes{%(queriesSelector)s} - node_memory_MemAvailable_bytes{%(queriesSelector)s}', 'bytes'),
      memAvailable: sig('Memory available', 'node_memory_MemAvailable_bytes{%(queriesSelector)s}', 'bytes'),
      fsUsed: sig('Filesystem used', '1 - node_filesystem_avail_bytes{%(queriesSelector)s,fstype!=""} / node_filesystem_size_bytes{%(queriesSelector)s,fstype!=""}', 'percentunit'),
      diskIo: sig('Disk IO time', 'rate(node_disk_io_time_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit'),
      netRx: sig('Network received', 'rate(node_network_receive_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
      netTx: sig('Network transmitted', 'rate(node_network_transmit_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
    };

    pack.build(cfg, signals, [
      {
        title: 'CPU / Load',
        width: 12,
        height: 7,
        elements: {
          cpuBusy: signals.cpuBusy.asTimeSeries('CPU busy'),
          load1: signals.load1.asTimeSeries('Load 1m'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memUsed: signals.memUsed.asTimeSeries('Memory used'),
          memAvailable: signals.memAvailable.asTimeSeries('Memory available'),
        },
      },
      {
        title: 'Disk / Filesystem',
        width: 12,
        height: 7,
        elements: {
          fsUsed: signals.fsUsed.asTimeSeries('Filesystem used ratio'),
          diskIo: signals.diskIo.asTimeSeries('Disk IO utilization'),
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
    ]),
}
