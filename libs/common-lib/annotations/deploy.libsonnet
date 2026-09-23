// common-lib annotations — deployments. Marks the moment a workload was
// rolled out, so a change in a graph can be tied to a release rather than
// guessed at. Pair it with annotations.restart, which marks the restarts a
// rollout causes.
//   annotations.deploy.new('Deploys', annotations.deploy.kubeDeployment(ds, sel))
local base = import 'libs/common-lib/annotations/base.libsonnet';
local colors = import 'libs/common-lib/tokens/colors.libsonnet';
local sel(selector) = if selector != '' then '{' + selector + '}' else '';
base {
  new(title, target, instanceLabels=[]):
    super.new(title, target)
    + { spec+: { iconColor: colors.palette.info, hide: false } }
    + base.withTagKeys(instanceLabels),

  // kube-state-metrics: the controller observed a new spec.
  kubeDeployment(datasource, selector='')::
    base.target(datasource, 'changes(kube_deployment_status_observed_generation%s[$__interval]) > 0' % sel(selector)),
  kubeStatefulSet(datasource, selector='')::
    base.target(datasource, 'changes(kube_statefulset_status_observed_generation%s[$__interval]) > 0' % sel(selector)),
  kubeDaemonSet(datasource, selector='')::
    base.target(datasource, 'changes(kube_daemonset_status_observed_generation%s[$__interval]) > 0' % sel(selector)),
  // Argo CD: a sync operation finished.
  argocdSync(datasource, selector='')::
    base.target(datasource, 'increase(argocd_app_sync_total%s[$__interval]) > 0' % sel(selector)),
}
