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
      varMetric: 'container_cpu_usage_seconds_total',  // allowlisted with job+namespace
      varLabels: ['namespace'],  // $namespace dropdown (label_values scoped by $job)
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      // deploy target: Software / Kubernetes (nested Grafana folders; loader creates both).
      folderUid: 'software-kubernetes',
      folderTitle: 'Kubernetes',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
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
      diskReads: sig('Disk reads', 'sum by (pod)(rate(container_fs_reads_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      diskWrites: sig('Disk writes', 'sum by (pod)(rate(container_fs_writes_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      // --- CPU detail ---
      cpuThrottleRatio: sig('CPU throttled ratio', 'sum by (pod)(rate(container_cpu_cfs_throttled_periods_total{%(queriesSelector)s}[$__rate_interval])) / sum by (pod)(rate(container_cpu_cfs_periods_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      // --- Memory detail ---
      memUsage: sig('Memory usage', 'sum by (pod,container)(container_memory_usage_bytes{%(queriesSelector)s,container!=""})', 'bytes'),
      memCache: sig('Memory cache', 'sum by (pod,container)(container_memory_cache{%(queriesSelector)s,container!=""})', 'bytes'),
      memSwap: sig('Memory swap', 'sum by (pod,container)(container_memory_swap{%(queriesSelector)s,container!=""})', 'bytes'),
      // --- Disk detail ---
      diskReadIops: sig('Disk read IOPS', 'sum by (pod)(rate(container_fs_reads_total{%(queriesSelector)s}[$__rate_interval]))', 'iops'),
      diskWriteIops: sig('Disk write IOPS', 'sum by (pod)(rate(container_fs_writes_total{%(queriesSelector)s}[$__rate_interval]))', 'iops'),
    };

    pack.build(cfg, signals, [
      {
        title: 'CPU',
        width: 12,
        height: 7,
        elements: {
          cpuUsage: signals.cpuUsage.asTimeSeries('CPU usage (cores)'),
          cpuThrottling: signals.cpuThrottling.asTimeSeries('CPU throttled periods'),
          cpuThrottleRatio: signals.cpuThrottleRatio.asTimeSeries('CPU throttled ratio'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memWorkingSet: signals.memWorkingSet.asTimeSeries('Memory working set'),
          memUsage: signals.memUsage.asTimeSeries('Memory usage'),
          memRss: signals.memRss.asTimeSeries('Memory RSS'),
          memCache: signals.memCache.asTimeSeries('Memory cache'),
          memSwap: signals.memSwap.asTimeSeries('Memory swap'),
        },
      },
      {
        title: 'Disk',
        width: 12,
        height: 7,
        elements: {
          diskReads: signals.diskReads.asTimeSeries('Disk read'),
          diskWrites: signals.diskWrites.asTimeSeries('Disk write'),
          diskReadIops: signals.diskReadIops.asTimeSeries('Disk read IOPS'),
          diskWriteIops: signals.diskWriteIops.asTimeSeries('Disk write IOPS'),
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
