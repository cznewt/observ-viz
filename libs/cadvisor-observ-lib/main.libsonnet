// observ-viz Container resources pack (hand-written).
// cAdvisor container resource usage in Kubernetes (CPU, memory, network, disk),
// emitted as native v2 elements. Usage:
//   g.libs.kubernetes.cadvisor.new({ selector: 'namespace="default"' }).grafana.dashboard
//   g.libs.kubernetes.cadvisor.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-cadvisor',
      dashboardTitle: 'Container resources',
      dashboardTags: ['kubernetes', 'cadvisor'],
      datasource: '${datasource}',
      selector: 'namespace=~"$namespace"',
      varMetric: 'cadvisor_version_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      cpuUsage: sig('CPU usage', 'sum by (pod,container)(rate(container_cpu_usage_seconds_total{%(queriesSelector)s,container!=""}[$__rate_interval]))', 'short'),
      cpuThrottling: sig('CPU throttling', 'sum by (pod)(rate(container_cpu_cfs_throttled_periods_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      memWorkingSet: sig('Memory working set', 'sum by (pod,container)(container_memory_working_set_bytes{%(queriesSelector)s,container!=""})', 'bytes'),
      memRss: sig('Memory RSS', 'sum by (pod,container)(container_memory_rss{%(queriesSelector)s,container!=""})', 'bytes'),
      netReceive: sig('Network receive', 'sum by (pod)(rate(container_network_receive_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      netTransmit: sig('Network transmit', 'sum by (pod)(rate(container_network_transmit_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      diskReads: sig('Disk reads', 'sum by (pod)(rate(container_fs_reads_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      diskWrites: sig('Disk writes', 'sum by (pod)(rate(container_fs_writes_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
    };

    pack.build(cfg, signals, [
      {
        title: 'CPU',
        width: 12,
        height: 7,
        elements: {
          cpuUsage: signals.cpuUsage.asTimeSeries('CPU usage (cores)'),
          cpuThrottling: signals.cpuThrottling.asTimeSeries('CPU throttling'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memWorkingSet: signals.memWorkingSet.asTimeSeries('Memory working set'),
          memRss: signals.memRss.asTimeSeries('Memory RSS'),
        },
      },
      {
        title: 'Network',
        width: 12,
        height: 7,
        elements: {
          netReceive: signals.netReceive.asTimeSeries('Network receive'),
          netTransmit: signals.netTransmit.asTimeSeries('Network transmit'),
        },
      },
      {
        title: 'Disk',
        width: 12,
        height: 7,
        elements: {
          diskReads: signals.diskReads.asTimeSeries('Disk reads'),
          diskWrites: signals.diskWrites.asTimeSeries('Disk writes'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('cadvisor', [
        alert.rule.new(
          'ContainerCpuThrottlingHigh',
          'sum by (pod) (rate(container_cpu_cfs_throttled_periods_total' + rsBrace + '[5m])) > 1',
          '15m', 'warning', {},
          { summary: 'Container CPU throttling on pod {{ $labels.pod }} is high.' }
        ),
        alert.rule.new(
          'ContainerHighMemory',
          'sum by (pod, container) (container_memory_working_set_bytes{container!=""' + rsComma + '}) > 1e9',
          '15m', 'warning', {},
          { summary: 'Container memory working set on pod {{ $labels.pod }} is above 1GB.' }
        ),
        alert.rule.new(
          'ContainerHighCpu',
          'sum by (pod, container) (rate(container_cpu_usage_seconds_total{container!=""' + rsComma + '}[5m])) > 2',
          '15m', 'warning', {},
          { summary: 'Container CPU usage on pod {{ $labels.pod }} is above 2 cores.' }
        ),
        alert.rule.new(
          'ContainerNetworkUnavailable',
          'sum by (pod) (rate(container_network_receive_bytes_total' + rsBrace + '[5m])) == 0',
          '5m', 'critical', {},
          { summary: 'Container network receive on pod {{ $labels.pod }} is unavailable.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('cadvisor.rules', [
        alert.rule.record('pod:container_cpu_usage:rate5m', 'sum by (pod, container) (rate(container_cpu_usage_seconds_total{container!=""' + rsComma + '}[5m]))'),
        alert.rule.record('pod:container_memory_working_set:sum', 'sum by (pod, container) (container_memory_working_set_bytes{container!=""' + rsComma + '})'),
      ]),
    ]),
}
