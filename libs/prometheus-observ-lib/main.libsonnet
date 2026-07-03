// observ-viz Prometheus pack (hand-written).
// Self-monitoring for a Prometheus server, emitted as native v2 elements. Usage:
//   g.libs.monitoring.prometheus.new({ selector: 'job="prometheus"' }).grafana.dashboard
//   g.libs.monitoring.prometheus.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-prometheus',
      dashboardTitle: 'Prometheus',
      dashboardTags: ['prometheus', 'infra'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'prometheus_build_info',
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

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      headSeries: sig('Head series', 'prometheus_tsdb_head_series{%(queriesSelector)s}', 'short'),
      samplesAppended: sig('Samples appended', 'rate(prometheus_tsdb_head_samples_appended_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      targetsUp: sig('Targets up', 'sum(up{%(queriesSelector)s})', 'short'),
      scrapeDuration: sig('Scrape duration p99', 'prometheus_target_interval_length_seconds{quantile="0.99",%(queriesSelector)s}', 's'),
      queryRate: sig('Query rate', 'rate(prometheus_http_requests_total{%(queriesSelector)s,handler=~"/api/v1/query.*"}[$__rate_interval])', 'reqps'),
      residentMemory: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes'),
      ruleEvalDuration: sig('Rule eval duration', 'rate(prometheus_rule_evaluation_duration_seconds_sum{%(queriesSelector)s}[$__rate_interval]) / rate(prometheus_rule_evaluation_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])', 's'),
    };

    pack.build(cfg, signals, [
      {
        title: 'TSDB',
        width: 12,
        height: 7,
        elements: {
          headSeries: signals.headSeries.asTimeSeries('Head series'),
          samplesAppended: signals.samplesAppended.asTimeSeries('Samples appended/s'),
        },
      },
      {
        title: 'Scraping',
        width: 12,
        height: 7,
        elements: {
          targetsUp: signals.targetsUp.asStat('Targets up'),
          scrapeDuration: signals.scrapeDuration.asTimeSeries('Scrape duration p99'),
        },
      },
      {
        title: 'Queries',
        width: 24,
        height: 7,
        elements: {
          queryRate: signals.queryRate.asTimeSeries('Query rate'),
        },
      },
      {
        title: 'Resources',
        width: 12,
        height: 7,
        elements: {
          residentMemory: signals.residentMemory.asTimeSeries('Resident memory'),
          ruleEvalDuration: signals.ruleEvalDuration.asTimeSeries('Rule eval duration'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('prometheus', [
        alert.rule.new(
          'PrometheusDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'Prometheus {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'PrometheusRuleEvaluationSlow',
          'rate(prometheus_rule_evaluation_duration_seconds_sum' + rsBrace + '[5m]) / rate(prometheus_rule_evaluation_duration_seconds_count' + rsBrace + '[5m]) > 60',
          '15m', 'warning', {},
          { summary: 'Rule evaluation on {{ $labels.instance }} is slow.' }
        ),
        alert.rule.new(
          'PrometheusHighMemory',
          'process_resident_memory_bytes' + rsBrace + ' > 4e9',
          '15m', 'warning', {},
          { summary: 'Prometheus {{ $labels.instance }} resident memory is above 4GB.' }
        ),
        alert.rule.new(
          'PrometheusHighScrapeDuration',
          'prometheus_target_interval_length_seconds{quantile="0.99"' + rsComma + '} > 60',
          '15m', 'warning', {},
          { summary: 'Scrape interval p99 on {{ $labels.instance }} is above 60s.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('prometheus.rules', [
        alert.rule.record('instance:prometheus_samples_appended:rate5m', 'rate(prometheus_tsdb_head_samples_appended_total' + rsBrace + '[5m])'),
        alert.rule.record('instance:prometheus_query_requests:rate5m', 'rate(prometheus_http_requests_total{handler=~"/api/v1/query.*"' + rsComma + '}[5m])'),
      ]),
    ]),
}
