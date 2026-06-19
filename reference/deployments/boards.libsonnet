// observ-viz reference — Deployment folder. One board per deployment target.
local g = import 'g.libsonnet';
local place = (import 'reference/_util.libsonnet').place;

// [ pack, uid-suffix, title ]
local boards = [
  [g.packs.system.linux, 'linux', 'Linux'],
  [g.packs.system.docker, 'docker', 'Docker'],
  [g.packs.system.windows, 'windows', 'Windows'],
  [g.packs.kubernetes.pod, 'kube-pod', 'Kubernetes pod'],
  [g.packs.kubernetes.cadvisor, 'cadvisor', 'Container resources'],
];

{
  _config+:: {},
  grafanaDashboards+:: {
    ['deploy-' + b[1] + '.json']:
      place(
        b[0].new({ uid: 'observ-viz-deploy-' + b[1], dashboardTitle: b[2] }).grafana.dashboard,
        $._config.folders.deployments,
        $._config.tags,
      )
    for b in boards
  },
}
