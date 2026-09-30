// common-lib annotations — restarts. Marks the moment a process, container,
// pod or service started again, so a break in a graph can be read as "it was
// restarted" rather than guessed at. Ready-made queries for the platforms:
//   annotations.restart.new('Restarts', annotations.restart.process(ds, sel))
local base = import 'libs/common-lib/annotations/base.libsonnet';
local colors = import 'libs/common-lib/tokens/colors.libsonnet';
local sel(selector) = if selector != '' then '{' + selector + '}' else '';
base {
  new(title, target, instanceLabels=[]):
    super.new(title, target)
    + { spec+: { iconColor: colors.palette.warning, hide: false } }
    + base.withTagKeys(instanceLabels),

  // any Prometheus client library: its start time moved.
  process(datasource, selector='')::
    base.target(datasource, 'changes(process_start_time_seconds%s[$__interval]) > 0' % sel(selector)),
  // kube-state-metrics: a container restarted (crash, OOM kill, liveness).
  kubeContainer(datasource, selector='')::
    base.target(datasource, 'increase(kube_pod_container_status_restarts_total%s[$__interval]) > 0' % sel(selector)),
  // cadvisor / Docker: a container started.
  container(datasource, selector='')::
    base.target(datasource, 'changes(container_start_time_seconds%s[$__interval]) > 0' % sel(selector)),
  // node_exporter: a systemd unit was (re)started.
  systemdUnit(datasource, selector='')::
    base.target(datasource, 'changes(node_systemd_unit_start_time_seconds%s[$__interval]) > 0' % sel(selector)),
  // kube-state-metrics: a Deployment, StatefulSet or DaemonSet rolled out.
  kubeRollout(datasource, selector='')::
    base.target(datasource, 'changes(kube_deployment_status_observed_generation%s[$__interval]) > 0' % sel(selector)),
  // node_exporter without the start-time collector (the usual case): the unit
  // went active since the previous step - a start, a restart, or the host
  // coming back up.
  systemdUnitActivated(datasource, selector='')::
    local s = 'node_systemd_unit_state{state="active"%s}' % (if selector != '' then ', ' + selector else '');
    base.target(datasource, '(%s == 1) unless (%s offset $__interval == 1)' % [s, s]),

  // ---- exact start times ----
  // The queries below return the start time itself (unix ms) as the value and
  // are drawn with useValueForTime: one marker per pod / container / process
  // at the moment it started, not at the step that noticed it. Use newAt().
  newAt(title, target, instanceLabels=[], titleFormat='')::
    self.new(title, target, instanceLabels)
    + base.withValueForTime(true)
    + (if titleFormat != '' then base.withTitleFormat(titleFormat) else {}),
  // kube-state-metrics: a pod was created and started, with the node it runs on.
  kubePodStart(datasource, selector='')::
    base.target(datasource, '1000 * max by (cluster, namespace, pod, node) (max by (cluster, namespace, pod) (kube_pod_start_time%s) * on (cluster, namespace, pod) group_left (node) topk by (cluster, namespace, pod) (1, max by (cluster, namespace, pod, node) (kube_pod_info%s)))' % [sel(selector), sel(selector)]),
  // kube-state-metrics: a container (re)started - first start and every restart.
  kubeContainerStart(datasource, selector='')::
    base.target(datasource, '1000 * max by (cluster, namespace, pod, container) (kube_pod_container_state_started%s)' % sel(selector)),
  // any Prometheus client library: the process started.
  processStart(datasource, selector='')::
    base.target(datasource, '1000 * max by (cluster, job, instance, namespace, pod) (process_start_time_seconds%s)' % sel(selector)),
}
