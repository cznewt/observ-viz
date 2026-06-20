// observ-viz Kubernetes pod pack (hand-written).
// Pod-level CPU, memory and health from kube-state-metrics + cadvisor, emitted as
// native v2 elements. Usage:
//   g.packs.kubernetes.pod.new({ selector: 'namespace="prod"' }).grafana.dashboard
//   g.packs.kubernetes.pod.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-kube-pod',
      dashboardTitle: 'Kubernetes pod',
      dashboardTags: ['kubernetes', 'pod'],
      datasource: '${datasource}',
      selector: 'namespace=~"$namespace"',
      varMetric: 'kube_pod_info',
    } + config;

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
    ]),
}
