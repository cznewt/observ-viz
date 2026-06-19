// observ-viz reference — Deployment folder. One TABBED board per deployment
// target, sourced directly from the pack mixins (system/kubernetes), same
// presentation as the Language reference: Overview tab + tabs per signal group.
local g = import 'g.libsonnet';
local util = import 'reference/_util.libsonnet';

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
      util.place(
        util.tabbedBoard(
          b[0].new({
            uid: 'observ-viz-deploy-' + b[1],
            dashboardTitle: b[2],
            datasource: $._config.datasource,
          }),
          b[2],
          'observ-viz-deploy-' + b[1],
        ),
        $._config.folders.deployments,
        $._config.tags,
      )
    for b in boards
  },
}
