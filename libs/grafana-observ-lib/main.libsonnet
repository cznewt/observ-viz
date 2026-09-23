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
      description: 'Grafana server self-monitoring: request rate, errors and latency, datasource and plugin requests, the alerting scheduler, the database pool, Live connections, instance totals and process resources.',
      // per-instance legend: the pod on kube; set '{{instance}}' for a host deployment.
      legend: '{{pod}}',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'grafana_build_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      // deploy target: Components / Monitoring (nested Grafana folders; loader creates both).
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table
      overviewSignals: ['httpRate', 'httpErrorRatio', 'httpP99', 'activeUsers', 'rss'],
      folderUid: 'components-monitoring',
      folderTitle: 'Monitoring',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      // ===== HTTP (the server's own request handling) =====
      httpRate: sig('Requests', 'sum by (status_code) (rate(grafana_http_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{status_code}}', desc='HTTP requests handled per second, by response status code.'),
      httpErrorRatio: sig('Error ratio', 'sum(rate(grafana_http_request_duration_seconds_count{%(queriesSelector)s, status_code=~"5.."}[$__rate_interval])) / sum(rate(grafana_http_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '5xx', desc='Share of HTTP requests answered with a 5xx. Sustained values above a few percent mean a datasource, the database or a plugin is failing behind Grafana.'),
      httpP99: sig('Request p99', 'histogram_quantile(0.99, sum by (le) (rate(grafana_http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Request duration percentiles across all handlers: p99 (slowest 1 percent) and p50 (typical).'),
      httpP50: sig('Request p50', 'histogram_quantile(0.50, sum by (le) (rate(grafana_http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p50', desc='Median request duration.'),
      httpByHandler: sig('Requests by handler', 'topk(10, sum by (handler) (rate(grafana_http_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])))', 'reqps', '{{handler}}', desc='The ten busiest API and page handlers by request rate.'),
      httpInFlight: sig('Requests in flight', 'sum(grafana_http_request_in_flight{%(queriesSelector)s})', 'short', 'in flight', desc='Requests currently being processed. A climbing value with flat throughput means requests are queueing behind something slow.'),
      apiStatus: sig('API responses', 'sum by (code) (rate(grafana_api_response_status_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'api {{code}}', desc='API responses per second by status code.'),
      pageStatus: sig('Page responses', 'sum by (code) (rate(grafana_page_response_status_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'page {{code}}', desc='HTML page responses per second by status code.'),
      // ===== Datasource proxy / plugin requests =====
      dsRequests: sig('Datasource requests', 'sum by (datasource) (rate(grafana_datasource_request_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{datasource}}', desc='Requests Grafana forwards to datasources per second, by datasource.'),
      dsErrors: sig('Datasource errors', 'sum by (datasource) (rate(grafana_datasource_request_total{%(queriesSelector)s, code=~"5.."}[$__rate_interval]))', 'reqps', '{{datasource}}', desc='Datasource requests that came back with a 5xx per second, by datasource.'),
      dsP99: sig('Datasource p99', 'histogram_quantile(0.99, sum by (le, datasource) (rate(grafana_datasource_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{datasource}}', desc='Slowest 1 percent of datasource round trips, by datasource. Slow panels usually show up here first.'),
      dsInFlight: sig('Datasource requests in flight', 'sum(grafana_datasource_request_in_flight{%(queriesSelector)s})', 'short', 'in flight', desc='Datasource requests currently in flight.'),
      proxyStatus: sig('Proxy responses', 'sum by (code) (rate(grafana_proxy_response_status_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'proxy {{code}}', desc='Datasource proxy responses per second by status code.'),
      pluginRequests: sig('Plugin requests', 'sum by (plugin_id) (rate(grafana_plugin_request_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{plugin_id}}', desc='Backend plugin requests per second, by plugin.'),
      pluginP99: sig('Plugin request p99', 'histogram_quantile(0.99, sum by (le) (rate(grafana_plugin_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Slowest 1 percent of backend plugin requests.'),
      // ===== Alerting =====
      alertsActive: sig('Active alerts', 'sum(grafana_alerting_active_alerts{%(queriesSelector)s})', 'short', 'active', desc='Alert instances currently active in unified alerting.'),
      alertRules: sig('Scheduled alert rules', 'sum(grafana_alerting_schedule_alert_rules{%(queriesSelector)s})', 'short', 'rules', desc='Alert rules the scheduler is evaluating.'),
      schedulerBehind: sig('Scheduler behind', 'max(grafana_alerting_scheduler_behind_seconds{%(queriesSelector)s})', 's', 'behind', desc='How far the alert scheduler is behind its tick. Above a few seconds evaluations are being skipped or delayed.'),
      evalTime: sig('Rule evaluation time', 'sum(rate(grafana_alerting_execution_time_milliseconds_sum{%(queriesSelector)s}[$__rate_interval])) / sum(rate(grafana_alerting_execution_time_milliseconds_count{%(queriesSelector)s}[$__rate_interval]))', 'ms', 'avg', desc='Average time to evaluate an alert rule (query plus state calculation).'),
      notifLatencyP99: sig('Notification latency p99', 'histogram_quantile(0.99, sum by (le) (rate(grafana_alerting_notification_latency_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Slowest 1 percent of notification deliveries to contact points.'),
      alertsReceived: sig('Alerts received', 'sum(rate(grafana_alerting_alerts_received_total{%(queriesSelector)s}[$__rate_interval]))', 'short', 'received/s', desc='Alerts received by the built-in Alertmanager per second.'),
      // ===== Database pool =====
      dbOpen: sig('DB connections open', 'grafana_database_conn_open{%(queriesSelector)s}', 'short', cfg.legend + ' open', desc='Connections in the database pool: open, in use and idle. In-use pinned at max open means the pool is exhausted.'),
      dbInUse: sig('DB connections in use', 'grafana_database_conn_in_use{%(queriesSelector)s}', 'short', cfg.legend + ' in use', desc='Database connections currently in use.'),
      dbIdle: sig('DB connections idle', 'grafana_database_conn_idle{%(queriesSelector)s}', 'short', cfg.legend + ' idle', desc='Idle connections in the database pool.'),
      dbMaxOpen: sig('DB max open', 'grafana_database_conn_max_open{%(queriesSelector)s}', 'short', desc='Configured maximum of open database connections.'),
      dbWaitRate: sig('DB connection waits', 'rate(grafana_database_conn_wait_count_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='How often a request had to wait for a free database connection per second. Anything above zero means the pool is too small or queries are too slow.'),
      dbWaitTime: sig('DB wait time', 'rate(grafana_database_conn_wait_duration_seconds{%(queriesSelector)s}[$__rate_interval])', 's', desc='Total time per second spent waiting for database connections.'),
      // ===== Live (websocket) + rendering =====
      liveClients: sig('Live clients', 'sum(grafana_live_node_num_clients{%(queriesSelector)s})', 'short', 'clients', desc='Clients connected to Grafana Live (websocket streaming).'),
      liveChannels: sig('Live channels', 'sum(grafana_live_node_num_channels{%(queriesSelector)s})', 'short', 'channels', desc='Active Grafana Live channels.'),
      liveSent: sig('Live messages sent', 'sum(rate(grafana_live_node_messages_sent_count{%(queriesSelector)s}[$__rate_interval]))', 'short', 'sent/s', desc='Messages pushed to Live clients per second.'),
      renderingQueue: sig('Rendering queue', 'sum(grafana_rendering_queue_size{%(queriesSelector)s})', 'short', 'queued', desc='Image rendering requests waiting for the renderer.'),
      emailsFailed: sig('Emails failed', 'sum(rate(grafana_emails_sent_failed{%(queriesSelector)s}[$__rate_interval]))', 'short', 'failed/s', desc='Emails that failed to send per second (notifications, invites, resets).'),
      // ===== Totals (instance stats, refreshed by grafana every few minutes) =====
      totalDashboards: sig('Dashboards', 'max(grafana_stat_totals_dashboard{%(queriesSelector)s})', 'short', 'dashboards', desc='Dashboards stored in this instance.'),
      totalDatasources: sig('Datasources', 'max(grafana_stat_totals_datasource{%(queriesSelector)s})', 'short', 'datasources', desc='Datasources configured.'),
      totalFolders: sig('Folders', 'max(grafana_stat_totals_folder{%(queriesSelector)s})', 'short', 'folders', desc='Folders.'),
      totalUsers: sig('Users', 'max(grafana_stat_total_users{%(queriesSelector)s})', 'short', 'users', desc='User accounts.'),
      activeUsers: sig('Active users', 'max(grafana_stat_active_users{%(queriesSelector)s})', 'short', 'active', desc='Users active in the last 30 days.'),
      totalOrgs: sig('Organisations', 'max(grafana_stat_total_orgs{%(queriesSelector)s})', 'short', 'orgs', desc='Organisations.'),
      totalAlertRules: sig('Alert rules', 'max(grafana_stat_totals_alert_rules{%(queriesSelector)s})', 'short', 'rules', desc='Alert rules stored.'),
      // ===== Resources (Go process) =====
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='CPU cores used by the Grafana process.'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes', desc='Resident memory of the Grafana process.'),
      goroutines: sig('Goroutines', 'go_goroutines{%(queriesSelector)s}', 'short', desc='Goroutines in the Grafana process. A steady climb is a leak, usually in a datasource or plugin.'),
      uptime: sig('Uptime', 'min(time() - process_start_time_seconds{%(queriesSelector)s})', 'dtdurations', 'uptime', desc='Time since the Grafana process started.'),
      restarts: sig('Instance starts', 'sum(increase(grafana_instance_start_total{%(queriesSelector)s}[1h]))', 'short', 'starts/1h', desc='Grafana instance starts in the last hour. Above zero means a crash or a redeploy.'),
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
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('grafana_build_info', cfg.ruleSelector),
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
