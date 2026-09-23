// observ-viz Container resources pack (hand-written).
// cAdvisor container resource usage in Kubernetes (CPU, memory, network, disk),
// emitted as native v2 elements. Usage:
//   g.libs.kubernetes.cadvisor.new({ selector: 'namespace="default"' }).grafana.dashboard
//   g.libs.kubernetes.cadvisor.new({...}).grafana.elements   // reuse in a board
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-cadvisor',
      dashboardTitle: 'Container resources',
      dashboardTags: ['kubernetes', 'cadvisor', 'app-level'],
      description: 'Container resource usage from cAdvisor for Kubernetes pods: CPU with throttling, memory against limits, disk IO.',
      datasource: '${datasource}',
      selector: 'namespace=~"$namespace"',
      varMetric: 'container_cpu_usage_seconds_total',  // allowlisted with job+namespace
      varLabels: ['namespace'],  // $namespace dropdown (label_values scoped by $job)
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      // deploy target: Components / Kubernetes (nested Grafana folders; loader creates both).
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-kubernetes',
      folderTitle: 'Kubernetes',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withDescription(desc);

    local signals = {
      cpuUsage: sig('CPU usage', 'sum by (pod,container)(rate(container_cpu_usage_seconds_total{%(queriesSelector)s,container!=""}[$__rate_interval]))', 'short', desc='CPU cores used per container (cAdvisor).'),
      cpuThrottling: sig('CPU throttling', 'sum by (pod)(rate(container_cpu_cfs_throttled_periods_total{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='CFS periods per second in which the container was throttled because it hit its CPU limit.'),
      memWorkingSet: sig('Memory working set', 'sum by (pod,container)(container_memory_working_set_bytes{%(queriesSelector)s,container!=""})', 'bytes', desc='Working-set memory per container, what the kernel counts against the memory limit.'),
      memRss: sig('Memory RSS', 'sum by (pod,container)(container_memory_rss{%(queriesSelector)s,container!=""})', 'bytes', desc='Resident anonymous memory per container.'),
      diskReads: sig('Disk reads', 'sum by (pod)(rate(container_fs_reads_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', desc='Bytes read from block devices per pod per second.'),
      diskWrites: sig('Disk writes', 'sum by (pod)(rate(container_fs_writes_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', desc='Bytes written to block devices per pod per second.'),
      // --- CPU detail ---
      cpuThrottleRatio: sig('CPU throttled ratio', 'sum by (pod)(rate(container_cpu_cfs_throttled_periods_total{%(queriesSelector)s}[$__rate_interval])) / sum by (pod)(rate(container_cpu_cfs_periods_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', desc='Share of CFS periods in which the pod was throttled. Above 0.25 the CPU limit is visibly slowing the workload.'),
      // --- Memory detail ---
      memUsage: sig('Memory usage', 'sum by (pod,container)(container_memory_usage_bytes{%(queriesSelector)s,container!=""})', 'bytes', desc='Total memory usage per container including page cache.'),
      memCache: sig('Memory cache', 'sum by (pod,container)(container_memory_cache{%(queriesSelector)s,container!=""})', 'bytes', desc='Page cache attributed to the container. Reclaimable, so not a leak by itself.'),
      memSwap: sig('Memory swap', 'sum by (pod,container)(container_memory_swap{%(queriesSelector)s,container!=""})', 'bytes', desc='Swap used by the container.'),
      // --- CPU user/system + Memory limit/OOM (unlocked via cadvisor includeMetrics) ---
      cpuUser: sig('CPU user', 'sum by (pod,container)(rate(container_cpu_user_seconds_total{%(queriesSelector)s,container!=""}[$__rate_interval]))', 'short', desc='CPU time spent in user mode per container.'),
      cpuSystem: sig('CPU system', 'sum by (pod,container)(rate(container_cpu_system_seconds_total{%(queriesSelector)s,container!=""}[$__rate_interval]))', 'short', desc='CPU time spent in kernel mode per container.'),
      specMemLimit: sig('Memory limit (spec)', 'sum by (pod,container)(container_spec_memory_limit_bytes{%(queriesSelector)s,container!=""})', 'bytes', desc='Memory limit configured on the container.'),
      oomEvents: sig('OOM kills', 'sum by (pod)(rate(container_oom_events_total{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='Out-of-memory kills per pod per second.'),
      // --- Network (pod level: cAdvisor reports it on the pause container) ---
      netRx: sig('Network received', 'sum by (pod)(rate(container_network_receive_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', desc='Traffic the pod received per second.'),
      netTx: sig('Network transmitted', 'sum by (pod)(rate(container_network_transmit_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', desc='Traffic the pod sent per second.'),
      netRxPackets: sig('Packets received', 'sum by (pod)(rate(container_network_receive_packets_total{%(queriesSelector)s}[$__rate_interval]))', 'pps', desc='Packets the pod received per second.'),
      netTxPackets: sig('Packets transmitted', 'sum by (pod)(rate(container_network_transmit_packets_total{%(queriesSelector)s}[$__rate_interval]))', 'pps', desc='Packets the pod sent per second.'),
      netRxDropped: sig('Received packets dropped', 'sum by (pod)(rate(container_network_receive_packets_dropped_total{%(queriesSelector)s}[$__rate_interval]))', 'pps', desc='Inbound packets dropped, often a full socket buffer or a saturated interface.'),
      netTxDropped: sig('Transmitted packets dropped', 'sum by (pod)(rate(container_network_transmit_packets_dropped_total{%(queriesSelector)s}[$__rate_interval]))', 'pps', desc='Outbound packets dropped.'),
      netRxErrors: sig('Receive errors', 'sum by (pod)(rate(container_network_receive_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'pps', desc='Inbound packet errors.'),
      netTxErrors: sig('Transmit errors', 'sum by (pod)(rate(container_network_transmit_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'pps', desc='Outbound packet errors.'),
      // --- Disk detail ---
      diskReadIops: sig('Disk read IOPS', 'sum by (pod)(rate(container_fs_reads_total{%(queriesSelector)s}[$__rate_interval]))', 'iops', desc='Read operations per pod per second.'),
      diskWriteIops: sig('Disk write IOPS', 'sum by (pod)(rate(container_fs_writes_total{%(queriesSelector)s}[$__rate_interval]))', 'iops', desc='Write operations per pod per second.'),
    };

    pack.build(cfg, signals, [
      {
        title: 'CPU',
        width: 12,
        height: 7,
        elements: {
          cpuUsage: signals.cpuUsage.asTimeSeries('CPU usage (cores)'),
          cpuUser: signals.cpuUser.asTimeSeries('CPU user'),
          cpuSystem: signals.cpuSystem.asTimeSeries('CPU system'),
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
          specMemLimit: signals.specMemLimit.asTimeSeries('Memory limit (spec)'),
          oomEvents: signals.oomEvents.asTimeSeries('OOM kills'),
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
      {
        title: 'Network',
        width: 12,
        height: 7,
        elements: {
          netThroughput: signals.netRx.asTimeSeries('Network throughput')
                         + panel.withTargetsMixin([signals.netTx.asTarget()]),
          netPackets: signals.netRxPackets.asTimeSeries('Packets/s')
                      + panel.withTargetsMixin([signals.netTxPackets.asTarget()]),
          netDropped: signals.netRxDropped.asTimeSeries('Dropped packets/s')
                      + panel.withTargetsMixin([signals.netTxDropped.asTarget()]),
          netErrors: signals.netRxErrors.asTimeSeries('Packet errors/s')
                     + panel.withTargetsMixin([signals.netTxErrors.asTarget()]),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('cadvisor', [
        alert.rule.new(
          'ContainerCpuThrottlingHigh',
          'sum by (pod) (rate(container_cpu_cfs_throttled_periods_total' + rsBrace + '[5m])) > 1',
          '15m',
          'warning',
          {},
          { summary: 'Container CPU throttling on pod {{ $labels.pod }} is high.' }
        ),
        alert.rule.new(
          'ContainerHighMemory',
          'sum by (pod, container) (container_memory_working_set_bytes{container!=""' + rsComma + '}) > 1e9',
          '15m',
          'warning',
          {},
          { summary: 'Container memory working set on pod {{ $labels.pod }} is above 1GB.' }
        ),
        alert.rule.new(
          'ContainerHighCpu',
          'sum by (pod, container) (rate(container_cpu_usage_seconds_total{container!=""' + rsComma + '}[5m])) > 2',
          '15m',
          'warning',
          {},
          { summary: 'Container CPU usage on pod {{ $labels.pod }} is above 2 cores.' }
        ),
        alert.rule.new(
          'ContainerNetworkUnavailable',
          'sum by (pod) (rate(container_network_receive_bytes_total' + rsBrace + '[5m])) == 0',
          '5m',
          'critical',
          {},
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
