// observ-viz kube-state-metrics self-monitoring pack (hand-written).
// KSM's own health from its telemetry endpoint (kube_state_metrics_* on the
// telemetry port, default :8081 - a separate scrape from the object metrics on
// :8080; the k8s-monitoring subchart needs selfMonitor.enabled plus
// k8s.grafana.com scrape annotations for port 8081): list / watch outcomes per
// resource and sharding. Alerts ported from
// the service catalog's kube-state-metrics-mixin, grouped by cluster so one
// cluster's KSM cannot mask another's.
// Usage:
//   g.libs.monitoring.kubeStateMetrics.new({ ruleSelector: 'job=~".*kube-state-metrics.*"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-kube-state-metrics',
      dashboardTitle: 'kube-state-metrics',
      // Platform / Monitoring / Collectors
      folderPath: (import 'libs/common-lib/folders.libsonnet').monitoringCollectors,
      dashboardTags: ['kube-state-metrics', 'kubernetes', 'collector', 'app-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      selector: 'job=~"$job", cluster=~"$cluster"',
      varMetric: 'kube_state_metrics_build_info',
      varLabels: ['cluster'],
      ruleSelector: '',
      errorRatio: 0.01,
    } + config;

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, legend='{{cluster}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      instances: sig('Instances', 'count(kube_state_metrics_build_info{%(queriesSelector)s})', 'short', 'instances'),
      shards: sig('Shards', 'max(kube_state_metrics_total_shards{%(queriesSelector)s})', 'short', 'shards'),
      // the result="error" series only exists after a first error: 0 until then
      listErrorRatio: sig('List error ratio', '(sum(rate(kube_state_metrics_list_total{result="error", %(queriesSelector)s}[$__rate_interval])) or vector(0)) / sum(rate(kube_state_metrics_list_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', 'list errors'),
      watchErrorRatio: sig('Watch error ratio', '(sum(rate(kube_state_metrics_watch_total{result="error", %(queriesSelector)s}[$__rate_interval])) or vector(0)) / sum(rate(kube_state_metrics_watch_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', 'watch errors'),
      listByResult: sig('List operations', 'sum by (result) (rate(kube_state_metrics_list_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{result}}'),
      watchByResult: sig('Watch operations', 'sum by (result) (rate(kube_state_metrics_watch_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{result}}'),
      errorsByResource: sig('Errors by resource', 'sum by (resource) (rate(kube_state_metrics_list_total{result="error", %(queriesSelector)s}[$__rate_interval])) + sum by (resource) (rate(kube_state_metrics_watch_total{result="error", %(queriesSelector)s}[$__rate_interval]))', 'ops', '{{resource}}'),
      memory: sig('Resident memory', 'sum by (cluster, pod) (process_resident_memory_bytes{%(queriesSelector)s})', 'bytes', '{{cluster}} / {{pod}}'),
      cpu: sig('CPU', 'sum by (cluster, pod) (rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{cluster}} / {{pod}}'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 6,
        height: 5,
        elements: {
          a_instances: signals.instances.asStat('Instances'),
          b_shards: signals.shards.asStat('Shards'),
          c_list: signals.listErrorRatio.asStat('List error ratio'),
          d_watch: signals.watchErrorRatio.asStat('Watch error ratio'),
        },
      },
      {
        title: 'List & watch',
        width: 8,
        height: 7,
        elements: {
          a_list: signals.listByResult.asTimeSeries('List operations by result'),
          b_watch: signals.watchByResult.asTimeSeries('Watch operations by result'),
          c_errors: signals.errorsByResource.asTimeSeries('Errors by resource'),
        },
      },
      {
        title: 'Process',
        width: 12,
        height: 7,
        elements: {
          a_memory: signals.memory.asTimeSeries('Resident memory'),
          b_cpu: signals.cpu.asTimeSeries('CPU (cores)'),
        },
      },
    ], [
      alert.rule.group('kube-state-metrics', [
        alert.rule.new(
          'KubeStateMetricsListErrors',
          '(sum by (cluster) (rate(kube_state_metrics_list_total{result="error"' + rsComma + '}[5m])) / sum by (cluster) (rate(kube_state_metrics_list_total' + rs + '[5m]))) > ' + cfg.errorRatio,
          '15m',
          'critical',
          {},
          { summary: 'kube-state-metrics is experiencing errors in list operations.', description: 'kube-state-metrics in {{ $labels.cluster }} fails {{ $value | humanizePercentage }} of its list operations, so it may not expose metrics about Kubernetes objects correctly or at all.' }
        ),
        alert.rule.new(
          'KubeStateMetricsWatchErrors',
          '(sum by (cluster) (rate(kube_state_metrics_watch_total{result="error"' + rsComma + '}[5m])) / sum by (cluster) (rate(kube_state_metrics_watch_total' + rs + '[5m]))) > ' + cfg.errorRatio,
          '15m',
          'critical',
          {},
          { summary: 'kube-state-metrics is experiencing errors in watch operations.', description: 'kube-state-metrics in {{ $labels.cluster }} fails {{ $value | humanizePercentage }} of its watch operations, so it may not expose metrics about Kubernetes objects correctly or at all.' }
        ),
        alert.rule.new(
          'KubeStateMetricsShardingMismatch',
          'stdvar by (cluster) (kube_state_metrics_total_shards' + rs + ') != 0',
          '15m',
          'critical',
          {},
          { summary: 'kube-state-metrics sharding is misconfigured.', description: 'kube-state-metrics pods in {{ $labels.cluster }} run with different --total-shards settings; some objects may be exposed twice or not at all.' }
        ),
        alert.rule.new(
          'KubeStateMetricsShardsMissing',
          '2 ^ max by (cluster) (kube_state_metrics_total_shards' + rs + ') - 1 - sum by (cluster) (2 ^ max by (cluster, shard_ordinal) (kube_state_metrics_shard_ordinal' + rs + ')) != 0',
          '15m',
          'critical',
          {},
          { summary: 'kube-state-metrics shards are missing.', description: 'kube-state-metrics shards are missing in {{ $labels.cluster }} (bitmask {{ $value }} of absent ordinals); some Kubernetes objects are not exposed.' }
        ),
      ]),
    ]),
}
