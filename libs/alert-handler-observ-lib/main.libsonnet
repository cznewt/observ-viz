// observ-viz alert-handler pack (hand-written).
// The alert-handler webhook receiver (alert_handler_*): webhooks and alerts
// in, rule matches, actions by rule / type / result with their duration, and
// the loaded configuration (rules, validity, runbooks, secrets).
//   g.libs.monitoring.alertHandler.new({ selector: 'job="alert-handler"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-alert-handler',
      dashboardTitle: 'Alert handler',
      dashboardTags: ['alert-handler', 'monitoring', 'app-level'],
      description: 'The alert-handler webhook receiver: webhooks and alerts received, rule matches, actions by rule, type and result with their duration, and the loaded configuration.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'alert_handler_config_valid',
      ruleSelector: '',
      legend: '{{pod}}',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table
      overviewSignals: ['alerts', 'actions', 'actionsFailed', 'durationP99', 'rss'],
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
      webhooks: sig('Webhooks', 'sum by (result) (rate(alert_handler_webhook_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{result}}', desc='Webhook requests received per second, by outcome.'),
      webhookErrors: sig('Webhook errors', 'sum(rate(alert_handler_webhook_requests_total{%(queriesSelector)s, result!~"ok|success|accepted"}[$__rate_interval]))', 'short', 'errors', desc='Webhook requests rejected or failed per second (bad payload, auth, internal error).'),
      alerts: sig('Alerts', 'sum by (status) (rate(alert_handler_alerts_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{status}}', desc='Alerts unpacked from webhook payloads per second, firing and resolved.'),
      matches: sig('Rule matches', 'sum by (rule) (rate(alert_handler_rule_matches_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{rule}}', desc='Alerts matched by each rule per second.'),
      actions: sig('Actions', 'sum by (rule, action) (rate(alert_handler_actions_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{rule}} {{action}}', desc='Actions dispatched per second, by rule and action type (log, http, exec, runbook, k8s, salt, llm).'),
      actionsByResult: sig('Actions by result', 'sum by (result) (rate(alert_handler_actions_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{result}}', desc='Actions per second by result: ok, failed, skipped (a previous action in the chain failed).'),
      actionsFailed: sig('Failed actions', 'sum by (rule, action) (rate(alert_handler_actions_total{%(queriesSelector)s, result!~"ok|success"}[$__rate_interval]))', 'short', '{{rule}} {{action}}', desc='Actions that failed or were skipped per second, by rule and action.'),
      failureRatio: sig('Action failure ratio', 'sum(rate(alert_handler_actions_total{%(queriesSelector)s, result!~"ok|success|skipped"}[$__rate_interval])) / sum(rate(alert_handler_actions_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', 'failed', desc='Share of dispatched actions that failed.'),
      inflight: sig('Actions in flight', 'sum(alert_handler_actions_inflight{%(queriesSelector)s})', 'short', 'in flight', desc='Actions currently executing. Stuck at a high value means an action (exec, runbook, salt) hangs.'),
      durationP99: sig('Action duration p99', 'histogram_quantile(0.99, sum by (le, action) (rate(alert_handler_action_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{action}} p99', desc='Slowest 1 percent of actions by type.'),
      durationAvg: sig('Action duration avg', 'sum by (rule, action) (rate(alert_handler_action_duration_seconds_sum{%(queriesSelector)s}[$__rate_interval])) / sum by (rule, action) (rate(alert_handler_action_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 's', '{{rule}} {{action}}', desc='Average action duration by rule and type.'),
      configValid: sig('Config valid', 'min(alert_handler_config_valid{%(queriesSelector)s})', 'short', 'valid', desc='1 while the configuration in effect parsed cleanly; 0 means the last reload failed and the previous rules stay active.'),
      configRules: sig('Rules', 'max(alert_handler_config_rules{%(queriesSelector)s})', 'short', 'rules', desc='Rules in the loaded configuration.'),
      configAge: sig('Since config load', 'time() - max(alert_handler_config_loaded_timestamp_seconds{%(queriesSelector)s})', 'dtdurations', 'since load', desc='Time since the configuration was last loaded.'),
      runbooks: sig('Runbooks', 'max(alert_handler_runbooks_available{%(queriesSelector)s})', 'short', 'runbooks', desc='Scripts present in the runbook directory.'),
      secrets: sig('Secrets', 'max(alert_handler_secrets_loaded{%(queriesSelector)s})', 'short', 'secrets', desc='Credentials read from the secrets directory.'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='CPU cores used by the handler process.'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes', desc='Resident memory of the handler process.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov01_configValid: signals.configValid.asStat('Config')
                            + panel.stat.withMappings([{ type: 'value', options: { '0': { text: 'INVALID', color: 'red', index: 0 }, '1': { text: 'valid', color: 'green', index: 1 } } }]),
          ov02_rules: signals.configRules.asStat('Rules'),
          ov03_configAge: signals.configAge.asStat('Since config load'),
          ov04_runbooks: signals.runbooks.asStat('Runbooks'),
          ov05_secrets: signals.secrets.asStat('Secrets'),
          ov06_inflight: signals.inflight.asStat('Actions in flight'),
          ov07_failureRatio: signals.failureRatio.asStat('Action failure ratio')
                             + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.05 }, { color: 'red', value: 0.25 }]),
          ov08_webhookErrors: signals.webhookErrors.asStat('Webhook errors/s')
                              + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.01 }]),
        },
      } + stats,
      {
        title: 'Intake',
        elements: {
          webhooks: signals.webhooks.asTimeSeries('Webhooks/s by result'),
          alerts: signals.alerts.asTimeSeries('Alerts/s by status'),
          matches: signals.matches.asTimeSeries('Rule matches/s'),
        },
      } + charts,
      {
        title: 'Actions',
        elements: {
          actions: signals.actions.asTimeSeries('Actions/s by rule and type'),
          actionsByResult: signals.actionsByResult.asTimeSeries('Actions/s by result'),
          actionsFailed: signals.actionsFailed.asTimeSeries('Failed / skipped actions/s'),
          durationP99: signals.durationP99.asTimeSeries('Action duration p99 by type'),
          durationAvg: signals.durationAvg.asTimeSeries('Action duration avg by rule'),
          inflight: signals.inflight.asTimeSeries('Actions in flight'),
        },
      } + charts,
      {
        title: 'Resources',
        elements: {
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          rss: signals.rss.asTimeSeries('Resident memory'),
        },
      } + charts,
    ], [
      alert.rule.group('alert-handler', [
        alert.rule.new('AlertHandlerDown',
                       (import 'libs/common-lib/alert/rule.libsonnet').targetDown('alert_handler_config_valid', cfg.ruleSelector),
                       '5m',
                       'critical',
                       {},
                       { summary: 'alert-handler {{ $labels.instance }} is down; alert actions are not running.' }),
        alert.rule.new('AlertHandlerConfigInvalid',
                       'alert_handler_config_valid' + rsBrace + ' == 0',
                       '5m',
                       'critical',
                       {},
                       { summary: 'alert-handler {{ $labels.instance }} runs with an invalid configuration; the previous rules stay in effect.' }),
        alert.rule.new('AlertHandlerActionsFailing',
                       'sum by (instance, rule, action) (rate(alert_handler_actions_total{result!~"ok|success|skipped"' + rsComma + '}[10m])) > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'alert-handler rule {{ $labels.rule }} action {{ $labels.action }} keeps failing on {{ $labels.instance }}.' }),
        alert.rule.new('AlertHandlerWebhookErrors',
                       'sum by (instance) (rate(alert_handler_webhook_requests_total{result!~"ok|success|accepted"' + rsComma + '}[10m])) > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'alert-handler {{ $labels.instance }} rejects webhook requests; check the Alertmanager receiver config and the auth token.' }),
        alert.rule.new('AlertHandlerActionsStuck',
                       'alert_handler_actions_inflight' + rsBrace + ' > 5',
                       '30m',
                       'warning',
                       {},
                       { summary: 'alert-handler {{ $labels.instance }} has actions executing for more than 30 minutes.' }),
      ]),
    ], [
      alert.rule.group('alert-handler.rules', [
        alert.rule.record('rule:alert_handler_actions:rate5m', 'sum by (rule, action, result) (rate(alert_handler_actions_total' + rsBrace + '[5m]))'),
        alert.rule.record('job:alert_handler_alerts:rate5m', 'sum by (job, status) (rate(alert_handler_alerts_total' + rsBrace + '[5m]))'),
      ]),
    ]),
}
