// observ-viz reference — Deployment folder. One TABBED board per deployment
// target, sourced directly from the pack mixins (system/kubernetes), same
// presentation as the Language reference: Overview tab + tabs per signal group.
local g = import 'g.libsonnet';
local util = import 'libs/reference-lib/_util.libsonnet';

// [ pack, uid-suffix, title, overview table config ]
// `overviewSignals` are the columns of the Overview tab's instances table and
// `instanceLabel` the label its rows are keyed by (a pod, not a scrape target,
// for the Kubernetes packs).
local boards = [
  [g.libs.system.linux, 'linux', 'Linux', {
    overviewSignals: ['cpuBusy', 'memUsedRatio', 'load1', 'fsUsed', 'uptime'],
  }],
  [g.libs.system.docker, 'docker', 'Docker', {
    overviewSignals: ['cpu', 'memUsage', 'netRx', 'netTx'],
  }],
  [g.libs.system.windows, 'windows', 'Windows', {
    overviewSignals: ['cpuBusy', 'memUsedRatio', 'diskUsedRatio', 'processes', 'uptime'],
  }],
  [g.libs.kubernetes.pod, 'kube-pod', 'Kubernetes pod', {
    // the pack aggregates by (pod), so that is what a row can be keyed by
    overviewSignals: ['cpuUsage', 'memWorkingSet', 'restarts', 'containersReady', 'cpuLimits'],
    varLabels: ['namespace', 'pod'],
    rowLabels: ['pod'],
  }],
  [g.libs.kubernetes.cadvisor, 'cadvisor', 'Container resources', {
    overviewSignals: ['cpuUsage', 'memWorkingSet', 'cpuThrottleRatio', 'netRx', 'netTx'],
    varLabels: ['namespace', 'pod'],
    rowLabels: ['pod'],
  }],
  // what a host runs, rather than a component of the platform: these two keep
  // the uids they had under Components so existing links still resolve
  [g.libs.system.systemd, 'systemd', 'systemd units', { uid: 'observ-viz-systemd' }],
  [g.libs.system.processExporter, 'process', 'Process groups', { uid: 'observ-viz-process-exporter' }],
];

{
  _config+:: {},
  grafanaDashboards+:: {
    ['deploy-' + b[1] + '.json']:
      util.place(
        b[0].new({
          uid: 'observ-viz-deploy-' + b[1],
          dashboardTitle: b[2],
          datasource: $._config.datasource,
          tabbed: true,
        } + b[3]).grafana.dashboard,
        $._config.folders.deployments,
        $._config.tags,
      )
    for b in boards
  },
}
