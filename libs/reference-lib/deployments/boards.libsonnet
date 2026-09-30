// observ-viz reference — Deployment folder. One TABBED board per deployment
// target, sourced directly from the pack mixins (system/kubernetes), same
// presentation as the Language reference: Overview tab + tabs per signal group.
local g = import 'g.libsonnet';
local util = import 'libs/reference-lib/_util.libsonnet';

// [ pack, uid-suffix, title, overview table config, folder key (default
// 'deployments' - see reference-lib/config.libsonnet) ]
// `overviewSignals` are the columns of the Overview tab's instances table and
// `instanceLabel` the label its rows are keyed by (a pod, not a scrape target,
// for the Kubernetes packs).
local boards = [
  // Linux and Windows: their node boards (system.linux / system.windows,
  // Platform / Infrastructure / Compute) are tabbed with this Overview now
  [g.libs.kubernetes.pod, 'kube-pod', 'Kubernetes pod', {
    // the pack aggregates by (pod), so that is what a row can be keyed by
    overviewSignals: ['cpuUsage', 'memWorkingSet', 'restarts', 'containersReady', 'cpuLimits'],
    overviewSparklines: ['cpuUsage', 'memWorkingSet'],
    overviewTopK: 25,
    varLabels: ['namespace', 'pod'],
    rowLabels: ['pod'],
  }],
  [g.libs.kubernetes.cadvisor, 'cadvisor', 'Container runtime', {
    // cAdvisor's unit is the container, not the pod - and only the signals
    // aggregated by (pod, container) can key a row by one. The pod-level ones
    // (throttling, network, disk) live on their own tabs.
    overviewSignals: ['cpuUsage', 'memWorkingSet', 'memRss', 'memUsage', 'specMemLimit'],
    overviewSparklines: ['cpuUsage', 'memWorkingSet'],
    overviewTopK: 25,
    varLabels: ['namespace', 'pod'],
    rowLabels: ['pod', 'container'],
  }],
  // what a host runs, rather than a component of the platform: these two keep
  // the uids they had under Components so existing links still resolve
  [g.libs.system.systemd, 'systemd', 'Systemd unit', { uid: 'observ-viz-systemd' }],
  [g.libs.system.processExporter, 'process', 'Process group', {
    uid: 'observ-viz-process-exporter',
    overviewSignals: ['cpu', 'rss', 'openFds', 'threads', 'uptime'],
    overviewSparklines: ['cpu', 'rss'],
    overviewTopK: 20,
  }],
  [g.libs.system.windowsService, 'windows-service', 'Windows service', { uid: 'observ-viz-windows-service' }],
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
        $._config.folders[if std.length(b) > 4 then b[4] else 'deployments'],
        $._config.tags,
      )
    for b in boards
  },
}
