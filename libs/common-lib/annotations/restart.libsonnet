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
}
