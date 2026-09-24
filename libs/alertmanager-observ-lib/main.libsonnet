// observ-viz Alertmanager pack (hand-written).
// Prometheus Alertmanager self-monitoring: alerts in and out, notifications
// per integration with failures and latency, silences, the gossip cluster and
// the config reload state. Alert rules follow the upstream alertmanager-mixin.
//   g.libs.monitoring.alertmanager.new({ selector: 'job="alertmanager"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-alertmanager',
      dashboardTitle: 'Alertmanager',
      dashboardTags: ['alertmanager', 'monitoring', 'app-level'],
      description: 'Prometheus Alertmanager self-monitoring: alerts received and active, notifications per integration with failures and latency, silences, the gossip cluster and configuration reloads.',
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal (process_*, go_*) cannot reach another component's
      // instances where the job label does not discriminate them
      selector: 'job=~"$job", instance=~"$instance"',
      varLabels: ['instance'],
      varMetric: 'alertmanager_build_info',
      ruleSelector: '',
      legend: '{{pod}}',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table
      overviewSignals: ['alertsActive', 'notifications', 'notificationsFailed', 'silencesActive', 'rss'],
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
      // ===== alerts =====
      alertsByState: sig('Alerts by state', 'sum by (state) (alertmanager_alerts{%(queriesSelector)s})', 'short', '{{state}}', desc='Alerts currently held, by state: active (firing or pending notification) and suppressed (silenced or inhibited).'),
      alertsActive: sig('Active alerts', 'sum(alertmanager_alerts{%(queriesSelector)s, state="active"})', 'short', 'active', desc='Alerts currently active in Alertmanager.'),
      alertsSuppressed: sig('Suppressed alerts', 'sum(alertmanager_alerts{%(queriesSelector)s, state="suppressed"})', 'short', 'suppressed', desc='Alerts currently silenced or inhibited.'),
      received: sig('Alerts received', 'sum by (status) (rate(alertmanager_alerts_received_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{status}}', desc='Alerts posted to the API per second, firing and resolved.'),
      invalid: sig('Invalid alerts', 'sum(rate(alertmanager_alerts_invalid_total{%(queriesSelector)s}[$__rate_interval]))', 'short', 'invalid', desc='Alerts rejected by the API per second (malformed labels or timestamps). Anything above zero means a misbehaving sender.'),
      aggregationGroups: sig('Aggregation groups', 'sum(alertmanager_dispatcher_aggregation_groups{%(queriesSelector)s})', 'short', 'groups', desc='Alert groups the dispatcher currently tracks.'),
      processingAvg: sig('Alert processing time', 'sum(rate(alertmanager_dispatcher_alert_processing_duration_seconds_sum{%(queriesSelector)s}[$__rate_interval])) / sum(rate(alertmanager_dispatcher_alert_processing_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 's', 'avg', desc='Average time the dispatcher spends processing an alert.'),
      // ===== notifications =====
      notifications: sig('Notifications', 'sum by (integration) (rate(alertmanager_notifications_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{integration}}', desc='Notifications attempted per second, by integration.'),
      notificationsFailed: sig('Failed notifications', 'sum by (integration, reason) (rate(alertmanager_notifications_failed_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{integration}} {{reason}}', desc='Notifications that failed per second, by integration and reason (clientError, serverError, contextCanceled...).'),
      failureRatio: sig('Notification failure ratio', 'sum by (integration) (rate(alertmanager_notifications_failed_total{%(queriesSelector)s}[$__rate_interval])) / sum by (integration) (rate(alertmanager_notifications_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '{{integration}}', desc='Share of notifications that failed, by integration. Above 1 percent sustained means a receiver is broken.'),
      failureRatioTotal: sig('Notification failure ratio', 'sum(rate(alertmanager_notifications_failed_total{%(queriesSelector)s}[$__rate_interval])) / sum(rate(alertmanager_notifications_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', 'failed', desc='Share of all notifications that failed.'),
      notificationP99: sig('Notification latency p99', 'histogram_quantile(0.99, sum by (le, integration) (rate(alertmanager_notification_latency_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{integration}}', desc='Slowest 1 percent of notification deliveries, by integration.'),
      suppressed: sig('Suppressed notifications', 'sum by (reason) (rate(alertmanager_notifications_suppressed_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{reason}}', desc='Notifications not sent per second because of a silence, inhibition or mute time interval.'),
      requestsFailed: sig('Failed notification requests', 'sum by (integration) (rate(alertmanager_notification_requests_failed_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{integration}}', desc='Individual HTTP requests to receivers that failed per second (a notification may retry several requests).'),
      // ===== silences / config / cluster =====
      silences: sig('Silences', 'sum by (state) (alertmanager_silences{%(queriesSelector)s})', 'short', '{{state}}', desc='Silences by state: active, pending, expired.'),
      silencesActive: sig('Active silences', 'sum(alertmanager_silences{%(queriesSelector)s, state="active"})', 'short', 'active', desc='Silences currently in effect.'),
      receivers: sig('Receivers', 'max(alertmanager_receivers{%(queriesSelector)s})', 'short', 'receivers', desc='Receivers in the loaded configuration.'),
      integrations: sig('Integrations', 'max(alertmanager_integrations{%(queriesSelector)s})', 'short', 'integrations', desc='Integrations (receiver endpoints) in the loaded configuration.'),
      inhibitionRules: sig('Inhibition rules', 'max(alertmanager_inhibition_rules{%(queriesSelector)s})', 'short', 'rules', desc='Inhibition rules in the loaded configuration.'),
      reloadOk: sig('Config reload ok', 'min(alertmanager_config_last_reload_successful{%(queriesSelector)s})', 'short', 'ok', desc='1 while the last configuration reload succeeded on every instance; 0 means an instance is running a stale configuration.'),
      reloadAge: sig('Since last reload', 'time() - max(alertmanager_config_last_reload_success_timestamp_seconds{%(queriesSelector)s})', 'dtdurations', 'since reload', desc='Time since the last successful configuration reload.'),
      clusterMembers: sig('Cluster members', 'alertmanager_cluster_members{%(queriesSelector)s}', 'short', desc='Peers each instance sees in the gossip cluster. All instances should agree on the same number.'),
      clusterFailedPeers: sig('Failed peers', 'alertmanager_cluster_failed_peers{%(queriesSelector)s}', 'short', desc='Peers an instance considers failed. Above zero the cluster is partitioned and notifications may duplicate.'),
      clusterHealth: sig('Cluster health score', 'alertmanager_cluster_health_score{%(queriesSelector)s}', 'short', desc='Memberlist health score: 0 is healthy, higher means the instance is struggling to keep up with gossip.'),
      clusterQueued: sig('Gossip queue', 'alertmanager_cluster_messages_queued{%(queriesSelector)s}', 'short', desc='Gossip messages waiting to be sent to peers.'),
      clusterReconnectFailed: sig('Failed reconnections', 'sum by (pod) (rate(alertmanager_cluster_reconnections_failed_total{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='Failed attempts to reconnect to a peer per second.'),
      // ===== API =====
      httpRate: sig('API requests', 'sum by (handler) (rate(alertmanager_http_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{handler}}', desc='API requests per second by handler.'),
      httpP99: sig('API request p99', 'histogram_quantile(0.99, sum by (le) (rate(alertmanager_http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Slowest 1 percent of API requests.'),
      httpInFlight: sig('API requests in flight', 'sum(alertmanager_http_requests_in_flight{%(queriesSelector)s})', 'short', 'in flight', desc='API requests currently being served.'),
      nflogErrors: sig('Notification log query errors', 'sum(rate(alertmanager_nflog_query_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'short', 'nflog', desc='Errors querying the notification log per second (the deduplication state).'),
      silenceErrors: sig('Silence query errors', 'sum(rate(alertmanager_silences_query_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'short', 'silences', desc='Errors querying silences per second.'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='CPU cores used by the Alertmanager process.'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes', desc='Resident memory of the Alertmanager process.'),
      uptime: sig('Uptime', 'min(time() - process_start_time_seconds{%(queriesSelector)s})', 'dtdurations', 'uptime', desc='Time since the oldest Alertmanager instance started.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };
    local red1 = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]);

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov01_active: signals.alertsActive.asStat('Active alerts'),
          ov02_suppressed: signals.alertsSuppressed.asStat('Suppressed alerts'),
          ov03_silences: signals.silencesActive.asStat('Active silences'),
          ov04_failureRatio: signals.failureRatioTotal.asStat('Notification failure ratio')
                             + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.1 }]),
          ov05_reloadOk: signals.reloadOk.asStat('Config reload')
                         + panel.stat.withMappings([{ type: 'value', options: { '0': { text: 'FAILED', color: 'red', index: 0 }, '1': { text: 'ok', color: 'green', index: 1 } } }]),
          ov06_reloadAge: signals.reloadAge.asStat('Since last reload'),
          ov07_receivers: signals.receivers.asStat('Receivers'),
          ov08_integrations: signals.integrations.asStat('Integrations'),
          ov09_inhibitions: signals.inhibitionRules.asStat('Inhibition rules'),
          ov10_groups: signals.aggregationGroups.asStat('Aggregation groups'),
          ov11_failedPeers: signals.clusterFailedPeers.asStat('Failed peers') + red1,
          ov12_uptime: signals.uptime.asStat('Uptime'),
        },
      } + stats,
      {
        title: 'Alerts',
        elements: {
          alertsByState: signals.alertsByState.asTimeSeries('Alerts by state'),
          received: signals.received.asTimeSeries('Alerts received/s'),
          invalid: signals.invalid.asTimeSeries('Invalid alerts/s'),
          processingAvg: signals.processingAvg.asTimeSeries('Alert processing time (avg)'),
          silences: signals.silences.asTimeSeries('Silences by state'),
          aggregationGroups: signals.aggregationGroups.asTimeSeries('Aggregation groups'),
        },
      } + charts,
      {
        title: 'Notifications',
        elements: {
          notifications: signals.notifications.asTimeSeries('Notifications/s by integration'),
          notificationsFailed: signals.notificationsFailed.asTimeSeries('Failed notifications/s'),
          failureRatio: signals.failureRatio.asTimeSeries('Failure ratio by integration'),
          notificationP99: signals.notificationP99.asTimeSeries('Notification latency p99'),
          suppressed: signals.suppressed.asTimeSeries('Suppressed notifications/s'),
          requestsFailed: signals.requestsFailed.asTimeSeries('Failed receiver requests/s'),
        },
      } + charts,
      {
        title: 'Cluster',
        elements: {
          clusterMembers: signals.clusterMembers.asTimeSeries('Cluster members'),
          clusterFailedPeers: signals.clusterFailedPeers.asTimeSeries('Failed peers'),
          clusterHealth: signals.clusterHealth.asTimeSeries('Health score'),
          clusterQueued: signals.clusterQueued.asTimeSeries('Gossip queue'),
          clusterReconnectFailed: signals.clusterReconnectFailed.asTimeSeries('Failed reconnections/s'),
        },
      } + charts,
      {
        title: 'API & resources',
        elements: {
          httpRate: signals.httpRate.asTimeSeries('API requests/s'),
          httpP99: signals.httpP99.asTimeSeries('API request p99'),
          httpInFlight: signals.httpInFlight.asTimeSeries('API requests in flight'),
          storeErrors: signals.nflogErrors.asTimeSeries('Notification log / silence query errors')
                       + panel.withTargetsMixin([signals.silenceErrors.asTarget()]),
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          rss: signals.rss.asTimeSeries('Resident memory'),
        },
      } + charts,
    ], [
      alert.rule.group('alertmanager', [
        alert.rule.new('AlertmanagerDown',
                       (import 'libs/common-lib/alert/rule.libsonnet').targetDown('alertmanager_build_info', cfg.ruleSelector),
                       '5m',
                       'critical',
                       {},
                       { summary: 'Alertmanager {{ $labels.instance }} is down.' }),
        alert.rule.new('AlertmanagerFailedReload',
                       'max_over_time(alertmanager_config_last_reload_successful' + rsBrace + '[5m]) == 0',
                       '10m',
                       'critical',
                       {},
                       { summary: 'Alertmanager {{ $labels.instance }} failed to reload its configuration and runs a stale one.' }),
        alert.rule.new('AlertmanagerClusterFailedPeers',
                       'alertmanager_cluster_failed_peers' + rsBrace + ' > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Alertmanager {{ $labels.instance }} lost contact with gossip peers; notifications may duplicate or be missed.' }),
        alert.rule.new('AlertmanagerFailedToSendAlerts',
                       'sum by (instance, integration) (rate(alertmanager_notifications_failed_total' + rsBrace + '[5m])) / sum by (instance, integration) (rate(alertmanager_notifications_total' + rsBrace + '[5m])) > 0.01',
                       '5m',
                       'warning',
                       {},
                       { summary: 'Alertmanager {{ $labels.instance }} fails to send more than 1% of {{ $labels.integration }} notifications.' }),
        alert.rule.new('AlertmanagerClusterFailedToSendAlerts',
                       'min by (integration) (sum by (instance, integration) (rate(alertmanager_notifications_failed_total' + rsBrace + '[5m])) / sum by (instance, integration) (rate(alertmanager_notifications_total' + rsBrace + '[5m]))) > 0.01',
                       '5m',
                       'critical',
                       {},
                       { summary: 'Every Alertmanager instance fails to send more than 1% of {{ $labels.integration }} notifications; the receiver is broken.' }),
        alert.rule.new('AlertmanagerClusterCrashlooping',
                       'changes(process_start_time_seconds' + rsBrace + '[10m]) > 4',
                       '0m',
                       'critical',
                       {},
                       { summary: 'Alertmanager {{ $labels.instance }} restarted more than 4 times in 10 minutes.' }),
      ]),
    ], [
      alert.rule.group('alertmanager.rules', [
        alert.rule.record('integration:alertmanager_notifications_failed:ratio_rate5m', 'sum by (integration) (rate(alertmanager_notifications_failed_total' + rsBrace + '[5m])) / sum by (integration) (rate(alertmanager_notifications_total' + rsBrace + '[5m]))'),
        alert.rule.record('job:alertmanager_alerts_received:rate5m', 'sum by (job, status) (rate(alertmanager_alerts_received_total' + rsBrace + '[5m]))'),
      ]),
    ]),
}
