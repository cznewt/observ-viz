// observ-viz Kubernetes pod pack (hand-written).
// Pod-level CPU, memory and health from kube-state-metrics + cadvisor, emitted as
// native v2 elements. Usage:
//   g.libs.kubernetes.pod.new({ selector: 'namespace="prod"' }).grafana.dashboard
//   g.libs.kubernetes.pod.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-kube-pod',
      dashboardTitle: 'Kubernetes pod',
      dashboardTags: ['kubernetes', 'pod'],
      datasource: '${datasource}',
      selector: 'namespace=~"$namespace"',
      varMetric: 'kube_pod_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      cpuUsage: sig('CPU usage', 'sum by (pod)(rate(container_cpu_usage_seconds_total{%(queriesSelector)s,container!=""}[$__rate_interval]))', 'short'),
      cpuRequests: sig('CPU requests', 'sum by (pod)(kube_pod_container_resource_requests{%(queriesSelector)s,resource="cpu"})', 'short'),
      memWorkingSet: sig('Memory working set', 'sum by (pod)(container_memory_working_set_bytes{%(queriesSelector)s,container!=""})', 'bytes'),
      memLimits: sig('Memory limits', 'sum by (pod)(kube_pod_container_resource_limits{%(queriesSelector)s,resource="memory"})', 'bytes'),
      restarts: sig('Container restarts', 'sum by (pod)(kube_pod_container_status_restarts_total{%(queriesSelector)s})', 'short'),
      phase: sig('Pod phase', 'sum by (pod,phase)(kube_pod_status_phase{%(queriesSelector)s})', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'CPU',
        width: 12,
        height: 7,
        elements: {
          cpuUsage: signals.cpuUsage.asTimeSeries('CPU usage (cores)'),
          cpuRequests: signals.cpuRequests.asTimeSeries('CPU requests (cores)'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memWorkingSet: signals.memWorkingSet.asTimeSeries('Memory working set'),
          memLimits: signals.memLimits.asTimeSeries('Memory limits'),
        },
      },
      {
        title: 'Health',
        width: 12,
        height: 7,
        elements: {
          restarts: signals.restarts.asTimeSeries('Container restarts'),
          phase: signals.phase.asTable('Pod phase'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('kubernetes-pod', [
        alert.rule.new(
          'KubePodNotReady',
          'sum by (namespace, pod) (kube_pod_status_phase{phase=~"Pending|Unknown|Failed"' + rsComma + '}) > 0',
          '15m', 'critical', {},
          { summary: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in a non-ready state for more than 15 minutes.' }
        ),
        alert.rule.new(
          'KubePodCrashLooping',
          'rate(kube_pod_container_status_restarts_total' + rsBrace + '[10m]) * 60 * 5 > 0',
          '15m', 'warning', {},
          { summary: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} on {{ $labels.instance }} is restarting frequently.' }
        ),
        alert.rule.new(
          'KubePodCpuOverRequest',
          'sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!=""' + rsComma + '}[5m])) > sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"' + rsComma + '})',
          '15m', 'warning', {},
          { summary: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} on {{ $labels.instance }} is using more CPU than requested.' }
        ),
        alert.rule.new(
          'KubePodMemoryNearLimit',
          'sum by (namespace, pod) (container_memory_working_set_bytes{container!=""' + rsComma + '}) / sum by (namespace, pod) (kube_pod_container_resource_limits{resource="memory"' + rsComma + '}) > 0.9',
          '15m', 'warning', {},
          { summary: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} on {{ $labels.instance }} memory working set is above 90% of its limit.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('kubernetes-pod.rules', [
        alert.rule.record('namespace_pod:container_cpu_usage:rate5m', 'sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!=""' + rsComma + '}[5m]))'),
        alert.rule.record('namespace_pod:container_memory_working_set_bytes:sum', 'sum by (namespace, pod) (container_memory_working_set_bytes{container!=""' + rsComma + '})'),
      ]),
    ]),
}
