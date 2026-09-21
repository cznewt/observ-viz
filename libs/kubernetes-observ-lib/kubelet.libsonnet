// Kubelet node-level elements (part of the kubernetes lib) — a reusable panel
// map for embedding in host boards (e.g. the linux node board's Kubelet tab,
// shown only on nodes that actually run a kubelet).
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  elements(datasource, selector): {
    local sig(name, expr, unit, legend, desc='') =
      signal.new(name, 'prometheus', datasource, expr, unit).filteringSelector(selector).withLegendFormat(legend).withDescription(desc),
    kubeletPods:
      sig('Running pods', 'sum by (instance) (kubelet_running_pods{%(queriesSelector)s})', 'short', '{{instance}}', desc='Pods the kubelet is running on this node.')
      .asStat('Running pods'),
    kubeletContainers:
      sig('Running containers', 'sum by (instance) (kubelet_running_containers{container_state="running", %(queriesSelector)s})', 'short', '{{instance}}', desc='Containers in the running state on this node.')
      .asStat('Running containers'),
    kubeletVols:
      sig('PVC volumes', 'count(kubelet_volume_stats_capacity_bytes{%(queriesSelector)s})', 'short', 'volumes', desc='PersistentVolumeClaims mounted on this node that report capacity stats.')
      .asStat('PVC volumes with stats'),
    kubeletOps:
      sig('Runtime operations', 'sum by (operation_type) (rate(kubelet_runtime_operations_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{operation_type}}', desc='Container runtime operations per second by type (pull, create, start, exec...).')
      .asTimeSeries('Runtime operations'),
    kubeletOpErrors:
      sig('Runtime errors', 'sum by (operation_type) (rate(kubelet_runtime_operations_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{operation_type}}', desc='Container runtime operations failing per second by type. Any sustained value means the runtime or the image registry is unhealthy.')
      .asTimeSeries('Runtime operation errors'),
  },
}
