// observ-viz Grafana pack (hand-written).
// Grafana server self-monitoring (grafana_* metrics), emitted as native v2
// elements. Metric names verified against a Grafana 13 /metrics scrape. Usage:
//   g.libs.monitoring.grafana.new({ selector: 'job="grafana"' }).grafana.dashboard
//   g.libs.monitoring.grafana.new({...}).grafana.elements   // reuse in a board
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-grafana',
      dashboardTitle: 'Grafana',
      dashboardTags: ['grafana', 'monitoring', 'app-level'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'grafana_build_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      // deploy target: Software / Monitoring (nested Grafana folders; loader creates both).
      folderUid: 'software-monitoring',
      folderTitle: 'Monitoring',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      // ===== HTTP (the server's own request handling) =====
      httpRate: sig('Requests', 'sum by (status_code) (rate(grafana_http_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{status_code}}'),
      httpErrorRatio: sig('Error ratio', 'sum(rate(grafana_http_request_duration_seconds_count{%(queriesSelector)s, status_code=~"5.."}[$__rate_interval])) / sum(rate(grafana_http_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '5xx'),
      httpP99: sig('Request p99', 'histogram_quantile(0.99, sum by (le) (rate(grafana_http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99'),
      httpP50: sig('Request p50', 'histogram_quantile(0.50, sum by (le) (rate(grafana_http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p50'),
      httpByHandler: sig('Requests by handler', 'topk(10, sum by (handler) (rate(grafana_http_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])))', 'reqps', '{{handler}}'),
      httpInFlight: sig('Requests in flight', 'sum(grafana_http_request_in_flight{%(queriesSelector)s})', 'short', 'in flight'),
      apiStatus: sig('API responses', 'sum by (code) (rate(grafana_api_response_status_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'api {{code}}'),
      pageStatus: sig('Page responses', 'sum by (code) (rate(grafana_page_response_status_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'page {{code}}'),

      // ===== Datasource proxy / plugin requests =====
      dsRequests: sig('Datasource requests', 'sum by (datasource) (rate(grafana_datasource_request_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{datasource}}'),
      dsErrors: sig('Datasource errors', 'sum by (datasource) (rate(grafana_datasource_request_total{%(queriesSelector)s, code=~"5.."}[$__rate_interval]))', 'reqps', '{{datasource}}'),
      dsP99: sig('Datasource p99', 'histogram_quantile(0.99, sum by (le, datasource) (rate(grafana_datasource_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{datasource}}'),
      dsInFlight: sig('Datasource requests in flight', 'sum(grafana_datasource_request_in_flight{%(queriesSelector)s})', 'short', 'in flight'),
      proxyStatus: sig('Proxy responses', 'sum by (code) (rate(grafana_proxy_response_status_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'proxy {{code}}'),
      pluginRequests: sig('Plugin requests', 'sum by (plugin_id) (rate(grafana_plugin_request_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{plugin_id}}'),
      pluginP99: sig('Plugin request p99', 'histogram_quantile(0.99, sum by (le) (rate(grafana_plugin_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99'),

      // ===== Alerting =====
      alertsActive: sig('Active alerts', 'sum(grafana_alerting_active_alerts{%(queriesSelector)s})', 'short', 'active'),
      alertRules: sig('Scheduled alert rules', 'sum(grafana_alerting_schedule_alert_rules{%(queriesSelector)s})', 'short', 'rules'),
      schedulerBehind: sig('Scheduler behind', 'max(grafana_alerting_scheduler_behind_seconds{%(queriesSelector)s})', 's', 'behind'),
      evalTime: sig('Rule evaluation time', 'sum(rate(grafana_alerting_execution_time_milliseconds_sum{%(queriesSelector)s}[$__rate_interval])) / sum(rate(grafana_alerting_execution_time_milliseconds_count{%(queriesSelector)s}[$__rate_interval]))', 'ms', 'avg'),
      notifLatencyP99: sig('Notification latency p99', 'histogram_quantile(0.99, sum by (le) (rate(grafana_alerting_notification_latency_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99'),
      alertsReceived: sig('Alerts received', 'sum(rate(grafana_alerting_alerts_received_total{%(queriesSelector)s}[$__rate_interval]))', 'short', 'received/s'),

      // ===== Database pool =====
      dbOpen: sig('DB connections open', 'grafana_database_conn_open{%(queriesSelector)s}', 'short', '{{instance}} open'),
      dbInUse: sig('DB connections in use', 'grafana_database_conn_in_use{%(queriesSelector)s}', 'short', '{{instance}} in use'),
      dbIdle: sig('DB connections idle', 'grafana_database_conn_idle{%(queriesSelector)s}', 'short', '{{instance}} idle'),
      dbMaxOpen: sig('DB max open', 'grafana_database_conn_max_open{%(queriesSelector)s}', 'short'),
      dbWaitRate: sig('DB connection waits', 'rate(grafana_database_conn_wait_count_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      dbWaitTime: sig('DB wait time', 'rate(grafana_database_conn_wait_duration_seconds{%(queriesSelector)s}[$__rate_interval])', 's'),

      // ===== Live (websocket) + rendering =====
      liveClients: sig('Live clients', 'sum(grafana_live_node_num_clients{%(queriesSelector)s})', 'short', 'clients'),
      liveChannels: sig('Live channels', 'sum(grafana_live_node_num_channels{%(queriesSelector)s})', 'short', 'channels'),
      liveSent: sig('Live messages sent', 'sum(rate(grafana_live_node_messages_sent_count{%(queriesSelector)s}[$__rate_interval]))', 'short', 'sent/s'),
      renderingQueue: sig('Rendering queue', 'sum(grafana_rendering_queue_size{%(queriesSelector)s})', 'short', 'queued'),
      emailsFailed: sig('Emails failed', 'sum(rate(grafana_emails_sent_failed{%(queriesSelector)s}[$__rate_interval]))', 'short', 'failed/s'),

      // ===== Totals (instance stats, refreshed by grafana every few minutes) =====
      totalDashboards: sig('Dashboards', 'max(grafana_stat_totals_dashboard{%(queriesSelector)s})', 'short', 'dashboards'),
      totalDatasources: sig('Datasources', 'max(grafana_stat_totals_datasource{%(queriesSelector)s})', 'short', 'datasources'),
      totalFolders: sig('Folders', 'max(grafana_stat_totals_folder{%(queriesSelector)s})', 'short', 'folders'),
      totalUsers: sig('Users', 'max(grafana_stat_total_users{%(queriesSelector)s})', 'short', 'users'),
      activeUsers: sig('Active users', 'max(grafana_stat_active_users{%(queriesSelector)s})', 'short', 'active'),
      totalOrgs: sig('Organisations', 'max(grafana_stat_total_orgs{%(queriesSelector)s})', 'short', 'orgs'),
      totalAlertRules: sig('Alert rules', 'max(grafana_stat_totals_alert_rules{%(queriesSelector)s})', 'short', 'rules'),

      // ===== Resources (Go process) =====
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes'),
      goroutines: sig('Goroutines', 'go_goroutines{%(queriesSelector)s}', 'short'),
      uptime: sig('Uptime', 'min(time() - process_start_time_seconds{%(queriesSelector)s})', 'dtdurations', 'uptime'),
      restarts: sig('Instance starts', 'sum(increase(grafana_instance_start_total{%(queriesSelector)s}[1h]))', 'short', 'starts/1h'),
    };

    local panel = import 'custom/panel.libsonnet';
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };
    local warn1 = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 1 }]);
    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov01_dashboards: signals.totalDashboards.asStat('Dashboards'),
          ov02_datasources: signals.totalDatasources.asStat('Datasources'),
          ov03_folders: signals.totalFolders.asStat('Folders'),
          ov04_users: signals.totalUsers.asStat('Users'),
          ov05_activeUsers: signals.activeUsers.asStat('Active users'),
          ov06_orgs: signals.totalOrgs.asStat('Organisations'),
          ov07_alertRules: signals.alertRules.asStat('Scheduled alert rules'),
          ov08_alertsActive: signals.alertsActive.asStat('Active alerts') + warn1,
          ov09_dbMaxOpen: signals.dbMaxOpen.asStat('DB max open'),
          ov10_uptime: signals.uptime.asStat('Uptime'),
          ov11_restarts: signals.restarts.asStat('Instance starts (1h)') + warn1,
          ov12_inFlight: signals.httpInFlight.asStat('Requests in flight'),
        },
      } + stats,
      {
        title: 'Requests',
        elements: {
          httpRate: signals.httpRate.asTimeSeries('Requests/s by status'),
          httpErrorRatio: signals.httpErrorRatio.asTimeSeries('5xx ratio'),
          httpDuration: signals.httpP99.asTimeSeries('Request duration p50 / p99')
                        + panel.withTargetsMixin([signals.httpP50.asTarget()]),
          httpByHandler: signals.httpByHandler.asTimeSeries('Top handlers'),
          apiStatus: signals.apiStatus.asTimeSeries('API responses by code'),
          pageStatus: signals.pageStatus.asTimeSeries('Page responses by code'),
        },
      } + charts,
      {
        title: 'Datasources & plugins',
        elements: {
          dsRequests: signals.dsRequests.asTimeSeries('Datasource requests/s'),
          dsErrors: signals.dsErrors.asTimeSeries('Datasource 5xx/s'),
          dsP99: signals.dsP99.asTimeSeries('Datasource request p99'),
          dsInFlight: signals.dsInFlight.asTimeSeries('Datasource requests in flight'),
          proxyStatus: signals.proxyStatus.asTimeSeries('Proxy responses by code'),
          pluginRequests: signals.pluginRequests.asTimeSeries('Plugin requests/s'),
          pluginP99: signals.pluginP99.asTimeSeries('Plugin request p99'),
        },
      } + charts,
      {
        title: 'Alerting',
        elements: {
          schedulerBehind: signals.schedulerBehind.asTimeSeries('Scheduler behind'),
          evalTime: signals.evalTime.asTimeSeries('Rule evaluation time (avg)'),
          notifLatencyP99: signals.notifLatencyP99.asTimeSeries('Notification latency p99'),
          alertsReceived: signals.alertsReceived.asTimeSeries('Alerts received/s'),
        },
      } + charts,
      {
        title: 'Database',
        elements: {
          dbConns: signals.dbOpen.asTimeSeries('Connections: open / in use / idle')
                   + panel.withTargetsMixin([signals.dbInUse.asTarget(), signals.dbIdle.asTarget()]),
          dbWaitRate: signals.dbWaitRate.asTimeSeries('Connection waits/s'),
          dbWaitTime: signals.dbWaitTime.asTimeSeries('Wait time/s'),
        },
      } + charts,
      {
        title: 'Live & rendering',
        elements: {
          liveClients: signals.liveClients.asTimeSeries('Live clients'),
          liveChannels: signals.liveChannels.asTimeSeries('Live channels'),
          liveSent: signals.liveSent.asTimeSeries('Live messages sent/s'),
          renderingQueue: signals.renderingQueue.asTimeSeries('Rendering queue'),
          emailsFailed: signals.emailsFailed.asTimeSeries('Emails failed/s'),
        },
      } + charts,
      {
        title: 'Resources',
        elements: {
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          rss: signals.rss.asTimeSeries('Resident memory'),
          goroutines: signals.goroutines.asTimeSeries('Goroutines'),
        },
      } + charts,
    ], [
      // alerting rule group
      alert.rule.group('grafana', [
        alert.rule.new(
          'GrafanaDown',
          'up' + rsBrace + ' == 0',
          '5m',
          'critical',
          {},
          { summary: 'Grafana {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'GrafanaHttpErrorRatioHigh',
          'sum by (instance) (rate(grafana_http_request_duration_seconds_count{status_code=~"5.."' + rsComma + '}[5m])) / sum by (instance) (rate(grafana_http_request_duration_seconds_count' + rsBrace + '[5m])) > 0.05',
          '15m',
          'warning',
          {},
          { summary: 'Grafana {{ $labels.instance }} is answering more than 5% of requests with a 5xx.' }
        ),
        alert.rule.new(
          'GrafanaHttpLatencyHigh',
          'histogram_quantile(0.99, sum by (le, instance) (rate(grafana_http_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 2',
          '15m',
          'warning',
          {},
          { summary: 'Grafana {{ $labels.instance }} request p99 latency is above 2s.' }
        ),
        alert.rule.new(
          'GrafanaDatabaseConnectionWait',
          'rate(grafana_database_conn_wait_count_total' + rsBrace + '[5m]) > 0',
          '15m',
          'warning',
          {},
          { summary: 'Grafana {{ $labels.instance }} is waiting for database connections — the pool is exhausted.' }
        ),
        alert.rule.new(
          'GrafanaAlertingSchedulerBehind',
          'grafana_alerting_scheduler_behind_seconds' + rsBrace + ' > 10',
          '10m',
          'warning',
          {},
          { summary: 'Grafana {{ $labels.instance }} alert rule scheduler is more than 10s behind.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('grafana.rules', [
        alert.rule.record('instance:grafana_http_requests:rate5m', 'sum by (instance) (rate(grafana_http_request_duration_seconds_count' + rsBrace + '[5m]))'),
        alert.rule.record('instance:grafana_http_errors:ratio_rate5m', 'sum by (instance) (rate(grafana_http_request_duration_seconds_count{status_code=~"5.."' + rsComma + '}[5m])) / sum by (instance) (rate(grafana_http_request_duration_seconds_count' + rsBrace + '[5m]))'),
      ]),
    ]),
}
