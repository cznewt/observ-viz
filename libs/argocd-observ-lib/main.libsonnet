// observ-viz Argo CD pack (hand-written).
// Argo CD from its own metrics (application controller, repo server, API
// server): application health and sync state, sync operations, reconcile
// latency, cluster and repo connectivity, Kubernetes API and git traffic,
// controller workqueues. Metric names follow the Argo CD docs (argocd_*);
// the alert set mirrors adinhodovic/argo-cd-mixin.
//   g.libs.cicd.argocd.new({ selector: 'job="argocd-metrics"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-argocd',
      dashboardTitle: 'Argo CD',
      dashboardTags: ['argo-cd', 'cicd', 'gitops', 'app-level'],
      description: 'Argo CD from its own metrics: application health and sync status, sync operations and failures, reconcile latency, cluster and repository connectivity, Kubernetes API and git request traffic, controller workqueues.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'argocd_app_info',
      ruleSelector: '',
      legend: '{{pod}}',
      docTabs: true,
      folderUid: 'software-cicd',
      folderTitle: 'CI/CD',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      apps: sig('Applications', 'count(argocd_app_info{%(queriesSelector)s})', 'short', 'apps', desc='Applications Argo CD manages.'),
      appsByHealth: sig('Applications by health', 'sum by (health_status) (argocd_app_info{%(queriesSelector)s})', 'short', '{{health_status}}', desc='Applications by health status (Healthy, Progressing, Degraded, Suspended, Missing, Unknown).'),
      appsBySync: sig('Applications by sync status', 'sum by (sync_status) (argocd_app_info{%(queriesSelector)s})', 'short', '{{sync_status}}', desc='Applications by sync status (Synced, OutOfSync, Unknown).'),
      appsOutOfSync: sig('Out of sync', 'sum(argocd_app_info{%(queriesSelector)s, sync_status="OutOfSync"}) or vector(0)', 'short', 'out of sync', desc='Applications whose live state differs from git.'),
      appsUnhealthy: sig('Unhealthy', 'sum(argocd_app_info{%(queriesSelector)s, health_status!~"Healthy|Progressing"}) or vector(0)', 'short', 'unhealthy', desc='Applications that are Degraded, Missing, Suspended or Unknown.'),
      appTable: sig('Application state', 'max by (name, project, sync_status, health_status) (argocd_app_info{%(queriesSelector)s})', 'short', '{{name}}', desc='Every application with its project, sync and health status.'),
      syncs: sig('Sync operations', 'sum by (phase) (rate(argocd_app_sync_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{phase}}', desc='Sync operations per second by outcome phase (Succeeded, Failed, Error, Running).'),
      syncFailures1h: sig('Sync failures (1h)', 'sum(increase(argocd_app_sync_total{%(queriesSelector)s, phase=~"Error|Failed"}[1h])) or vector(0)', 'short', 'failed', desc='Sync operations that failed or errored in the last hour.'),
      syncFailuresByApp: sig('Sync failures by app', 'sum by (name) (increase(argocd_app_sync_total{%(queriesSelector)s, phase=~"Error|Failed"}[$__rate_interval]))', 'short', '{{name}}', desc='Failed sync operations by application.'),
      reconcileRate: sig('Reconciles', 'sum(rate(argocd_app_reconcile_count{%(queriesSelector)s}[$__rate_interval]))', 'short', 'reconciles/s', desc='Application reconciliations per second across the controller.'),
      reconcileP99: sig('Reconcile p99', 'histogram_quantile(0.99, sum by (le) (rate(argocd_app_reconcile_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Slowest 1 percent of application reconciliations. Long reconciles mean large apps, slow repos or a slow cluster API.'),
      reconcileP50: sig('Reconcile p50', 'histogram_quantile(0.50, sum by (le) (rate(argocd_app_reconcile_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p50', desc='Median application reconciliation time.'),
      clusters: sig('Clusters', 'count(argocd_cluster_info{%(queriesSelector)s})', 'short', 'clusters', desc='Clusters registered as deployment targets.'),
      clustersDown: sig('Clusters unreachable', 'count(argocd_cluster_connection_status{%(queriesSelector)s} == 0) or vector(0)', 'short', 'unreachable', desc='Registered clusters the controller cannot connect to.'),
      clusterObjects: sig('Cluster objects', 'sum by (server) (argocd_cluster_api_resource_objects{%(queriesSelector)s})', 'short', '{{server}}', desc='Kubernetes objects the controller caches per cluster.'),
      clusterEvents: sig('Cluster events', 'sum by (server) (rate(argocd_cluster_events_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{server}}', desc='Watch events received per second per cluster.'),
      k8sRequests: sig('Kubernetes API requests', 'sum by (verb, response_code) (rate(argocd_app_k8s_request_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{verb}} {{response_code}}', desc='Kubernetes API requests per second by verb and response code.'),
      gitRequests: sig('Git requests', 'sum by (request_type) (rate(argocd_git_request_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{request_type}}', desc='Git requests per second by type (ls-remote, fetch).'),
      gitP99: sig('Git request p99', 'histogram_quantile(0.99, sum by (le, request_type) (rate(argocd_git_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{request_type}}', desc='Slowest 1 percent of git requests by type.'),
      repoPending: sig('Repo requests pending', 'sum(argocd_repo_pending_request_total{%(queriesSelector)s})', 'short', 'pending', desc='Requests waiting on the repo server. A growing queue means manifest generation is the bottleneck.'),
      kubectlPending: sig('kubectl execs pending', 'sum by (command) (argocd_kubectl_exec_pending{%(queriesSelector)s})', 'short', '{{command}}', desc='kubectl invocations waiting to run (apply, auth), by command.'),
      redisFailed: sig('Redis failures', 'sum(rate(argocd_redis_request_total{%(queriesSelector)s, failed="true"}[$__rate_interval]))', 'short', 'failed', desc='Failed Redis requests per second. Redis backs the caches; failures slow every reconcile.'),
      workqueueDepth: sig('Workqueue depth', 'sum by (name) (workqueue_depth{%(queriesSelector)s})', 'short', '{{name}}', desc='Items waiting in each controller workqueue.'),
      workqueueLatencyP99: sig('Workqueue latency p99', 'histogram_quantile(0.99, sum by (le, name) (rate(workqueue_queue_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{name}}', desc='Slowest 1 percent of time items spend waiting in each workqueue.'),
      cpu: sig('CPU', 'sum by (pod) (rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='CPU cores used per Argo CD component pod.'),
      rss: sig('Resident memory', 'sum by (pod) (process_resident_memory_bytes{%(queriesSelector)s})', 'bytes', desc='Resident memory per Argo CD component pod.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };
    local red1 = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]);

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov01_apps: signals.apps.asStat('Applications'),
          ov02_outOfSync: signals.appsOutOfSync.asStat('Out of sync') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 1 }]),
          ov03_unhealthy: signals.appsUnhealthy.asStat('Unhealthy') + red1,
          ov04_syncFailures: signals.syncFailures1h.asStat('Sync failures (1h)') + red1,
          ov05_clusters: signals.clusters.asStat('Clusters'),
          ov06_clustersDown: signals.clustersDown.asStat('Clusters unreachable') + red1,
          ov07_repoPending: signals.repoPending.asStat('Repo requests pending'),
          ov08_reconcileP99: signals.reconcileP99.asStat('Reconcile p99'),
        },
      } + stats,
      {
        title: 'Applications',
        elements: {
          appsByHealth: signals.appsByHealth.asTimeSeries('Applications by health'),
          appsBySync: signals.appsBySync.asTimeSeries('Applications by sync status'),
          syncs: signals.syncs.asTimeSeries('Sync operations/s by phase'),
          syncFailuresByApp: signals.syncFailuresByApp.asTimeSeries('Sync failures by application'),
          reconcile: signals.reconcileP99.asTimeSeries('Reconcile duration p50 / p99')
                     + panel.withTargetsMixin([signals.reconcileP50.asTarget()]),
          reconcileRate: signals.reconcileRate.asTimeSeries('Reconciles/s'),
          appTable: signals.appTable.asTable('Application state'),
        },
      } + charts,
      {
        title: 'Clusters & repositories',
        elements: {
          clusterObjects: signals.clusterObjects.asTimeSeries('Cached objects per cluster'),
          clusterEvents: signals.clusterEvents.asTimeSeries('Watch events/s per cluster'),
          k8sRequests: signals.k8sRequests.asTimeSeries('Kubernetes API requests/s'),
          gitRequests: signals.gitRequests.asTimeSeries('Git requests/s'),
          gitP99: signals.gitP99.asTimeSeries('Git request p99'),
          repoPending: signals.repoPending.asTimeSeries('Repo requests pending'),
        },
      } + charts,
      {
        title: 'Controller',
        elements: {
          workqueueDepth: signals.workqueueDepth.asTimeSeries('Workqueue depth'),
          workqueueLatencyP99: signals.workqueueLatencyP99.asTimeSeries('Workqueue latency p99'),
          kubectlPending: signals.kubectlPending.asTimeSeries('kubectl execs pending'),
          redisFailed: signals.redisFailed.asTimeSeries('Redis failures/s'),
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          rss: signals.rss.asTimeSeries('Resident memory'),
        },
      } + charts,
    ], [
      alert.rule.group('argo-cd', [
        alert.rule.new('ArgoCdDown',
                       (import 'libs/common-lib/alert/rule.libsonnet').targetDown(['argocd_app_info', 'argocd_git_request_total', 'argocd_redis_request_total'], cfg.ruleSelector),
                       '5m',
                       'critical',
                       {},
                       { summary: 'Argo CD component {{ $labels.instance }} is down.' }),
        alert.rule.new('ArgoCdAppSyncFailed',
                       'sum by (name, project) (increase(argocd_app_sync_total{phase=~"Error|Failed"' + rsComma + '}[10m])) > 0',
                       '1m',
                       'warning',
                       {},
                       { summary: 'Argo CD application {{ $labels.name }} ({{ $labels.project }}) failed to sync in the last 10 minutes.' }),
        alert.rule.new('ArgoCdAppUnhealthy',
                       'sum by (name, project, health_status) (argocd_app_info{health_status!~"Healthy|Progressing"' + rsComma + '}) > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Argo CD application {{ $labels.name }} ({{ $labels.project }}) is {{ $labels.health_status }} for 15 minutes.' }),
        alert.rule.new('ArgoCdAppOutOfSync',
                       'sum by (name, project) (argocd_app_info{sync_status="OutOfSync"' + rsComma + '}) > 0',
                       '30m',
                       'info',
                       {},
                       { summary: 'Argo CD application {{ $labels.name }} ({{ $labels.project }}) has been out of sync for 30 minutes.' }),
        alert.rule.new('ArgoCdClusterUnreachable',
                       'argocd_cluster_connection_status' + rsBrace + ' == 0',
                       '10m',
                       'critical',
                       {},
                       { summary: 'Argo CD cannot connect to cluster {{ $labels.server }}.' }),
        alert.rule.new('ArgoCdRepoServerBacklog',
                       'sum(argocd_repo_pending_request_total' + rsBrace + ') > 10',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Argo CD repo server has a growing request backlog; manifest generation is the bottleneck.' }),
      ]),
    ], [
      alert.rule.group('argo-cd.rules', [
        alert.rule.record('project:argocd_app_sync_failed:increase10m', 'sum by (project, name) (increase(argocd_app_sync_total{phase=~"Error|Failed"' + rsComma + '}[10m]))'),
        alert.rule.record('job:argocd_app_reconcile_seconds:p99_5m', 'histogram_quantile(0.99, sum by (le, job) (rate(argocd_app_reconcile_bucket' + rsBrace + '[5m])))'),
      ]),
    ]),
}
