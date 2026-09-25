// observ-viz anomaly-exporter pack (hand-written).
// The multi-target anomaly exporter (anomaly_exporter_*): probes per module
// (latency z-score, queue EWMA, memory IQR, rps mean-sigma...), their
// results and duration. The scores themselves are the anomalyScorer pack.
//   g.libs.monitoring.anomalyExporter.new({}).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-anomaly-exporter',
      dashboardTitle: 'Anomaly exporter',
      dashboardTags: ['anomaly', 'monitoring', 'app-level'],
      description: 'The anomaly exporter itself: probes per module, success and failure rates, probe duration and version. Anomaly scores live on the Anomaly scorer board.',
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal (process_*, go_*) cannot reach another component's
      // instances where the job label does not discriminate them
      selector: 'job=~"$job", instance=~"$instance"',
      varLabels: ['instance'],
      varMetric: 'anomaly_exporter_build_info',
      ruleSelector: '',
      legend: '{{pod}}',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table
      overviewSignals: ['probes', 'failures', 'durationP99', 'rss'],
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
      probes: sig('Probes', 'sum by (module, result) (rate(anomaly_exporter_probes_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{module}} {{result}}', desc='Probes per second by module and result.'),
      probesTotal: sig('Probe rate', 'sum(rate(anomaly_exporter_probes_total{%(queriesSelector)s}[$__rate_interval]))', 'short', 'probes/s', desc='Probes per second across all modules.'),
      failures: sig('Failed probes', 'sum by (module) (rate(anomaly_exporter_probes_total{%(queriesSelector)s, result!="success"}[$__rate_interval]))', 'short', '{{module}}', desc='Probes per second that did not succeed, by module.'),
      failureRatio: sig('Probe failure ratio', 'sum(rate(anomaly_exporter_probes_total{%(queriesSelector)s, result!="success"}[$__rate_interval])) / sum(rate(anomaly_exporter_probes_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', 'failed', desc='Share of probes that did not succeed.'),
      modules: sig('Modules', 'count(count by (module) (anomaly_exporter_probes_total{%(queriesSelector)s}))', 'short', 'modules', desc='Distinct scoring modules that ran a probe.'),
      durationP50: sig('Probe duration p50', 'histogram_quantile(0.50, sum by (le, module) (rate(anomaly_exporter_probe_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{module}} p50', desc='Median probe duration by module.'),
      durationP99: sig('Probe duration p99', 'histogram_quantile(0.99, sum by (le, module) (rate(anomaly_exporter_probe_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{module}} p99', desc='Slowest 1 percent of probes by module. A probe runs the module query against the datasource, so this is mostly query latency.'),
      durationAvg: sig('Probe duration avg', 'sum by (module) (rate(anomaly_exporter_probe_duration_seconds_sum{%(queriesSelector)s}[$__rate_interval])) / sum by (module) (rate(anomaly_exporter_probe_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 's', '{{module}}', desc='Average probe duration by module.'),
      version: sig('Version', 'max by (version) (anomaly_exporter_build_info{%(queriesSelector)s})', 'short', '{{version}}', desc='Running exporter version.'),
      // --- what the probes produce. These arrive on the /probe scrape, so they
      // carry the scrape job's labels (probe, module), not the exporter's.
      score: sig('Anomaly score', 'max by (probe, module) (anomaly_score{%(queriesSelector)s})', 'short', '{{probe}} ({{module}})', desc='Worst score of the series a probe scored, 0 to 1. Every detector emits the same scale, so one alert threshold covers all of them.'),
      scoreBySeries: sig('Anomaly score by series', 'anomaly_score{%(queriesSelector)s}', 'short', '{{probe}} {{pod}}{{instance}}', desc='Every scored series separately - which one moved, not just that something did.'),
      scoreHigh: sig('Series above 0.8', 'count(anomaly_score{%(queriesSelector)s} > 0.8) or vector(0)', 'short', 'series', desc='Series a detector currently calls anomalous. Read it with the detector in mind: a seasonality-naive one flags normal peaks.'),
      probeSuccess: sig('Probe success', 'min by (probe, module) (anomaly_probe_success{%(queriesSelector)s})', 'short', '{{probe}} ({{module}})', desc='1 when the probe ran and scored, 0 when it failed. A failing probe is a silent gap in detection.'),
      probeLatency: sig('Probe latency', 'max by (probe, module) (anomaly_probe_duration_seconds{%(queriesSelector)s})', 's', '{{probe}} ({{module}})', desc='How long the module took. Prophet and Holt-Winters are the slow ones; past the module timeout the probe returns nothing.'),
      seriesScored: sig('Series scored', 'sum by (probe) (anomaly_series_scored{%(queriesSelector)s})', 'short', '{{probe}}', desc='Series the detector actually scored.'),
      seriesSkipped: sig('Series skipped', 'sum by (probe) (anomaly_series_total{%(queriesSelector)s} - anomaly_series_scored{%(queriesSelector)s})', 'short', '{{probe}}', desc='Returned by the query but not scored - usually too few training points in the lookback.'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='CPU cores used by the exporter process.'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes', desc='Resident memory of the exporter process.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov01_rate: signals.probesTotal.asStat('Probes/s'),
          ov02_failureRatio: signals.failureRatio.asStat('Failure ratio')
                             + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.1 }]),
          ov03_modules: signals.modules.asStat('Modules'),
        },
      } + stats,
      {
        title: 'Scores',
        elements: {
          sc01_score: signals.score.asTimeSeries('Anomaly score by probe')
                      + panel.timeSeries.standardOptions.withMin(0)
                      + panel.timeSeries.standardOptions.withMax(1)
                      + panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.8 }, { color: 'red', value: 0.95 }])
                      + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } }),
          sc02_scoreBySeries: signals.scoreBySeries.asTimeSeries('Anomaly score by series')
                              + panel.timeSeries.standardOptions.withMin(0)
                              + panel.timeSeries.standardOptions.withMax(1),
          sc03_probeSuccess: signals.probeSuccess.asTimeSeries('Probe success (0 = detection gap)')
                             + panel.timeSeries.standardOptions.withMin(0)
                             + panel.timeSeries.standardOptions.withMax(1),
          sc04_probeLatency: signals.probeLatency.asTimeSeries('Probe latency by module'),
          sc05_seriesScored: signals.seriesScored.asTimeSeries('Series scored')
                             + panel.withTargetsMixin([signals.seriesSkipped.asTarget()]),
          sc06_scoreHigh: signals.scoreHigh.asTimeSeries('Series above 0.8'),
        },
      } + charts,
      {
        title: 'Probes',
        elements: {
          probes: signals.probes.asTimeSeries('Probes/s by module and result'),
          failures: signals.failures.asTimeSeries('Failed probes/s by module'),
          duration: signals.durationP99.asTimeSeries('Probe duration p99 / p50')
                    + panel.withTargetsMixin([signals.durationP50.asTarget()]),
          durationAvg: signals.durationAvg.asTimeSeries('Probe duration avg by module'),
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
      alert.rule.group('anomaly-exporter', [
        alert.rule.new('AnomalyExporterDown',
                       (import 'libs/common-lib/alert/rule.libsonnet').targetDown('anomaly_exporter_build_info', cfg.ruleSelector),
                       '10m',
                       'warning',
                       {},
                       { summary: 'Anomaly exporter {{ $labels.instance }} is down; anomaly scores stop updating.' }),
        alert.rule.new('AnomalyExporterProbesFailing',
                       'sum by (module) (rate(anomaly_exporter_probes_total{result!="success"' + rsComma + '}[10m])) / sum by (module) (rate(anomaly_exporter_probes_total' + rsBrace + '[10m])) > 0.1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Anomaly exporter module {{ $labels.module }} fails more than 10% of its probes.' }),
        alert.rule.new('AnomalyExporterProbeSlow',
                       'histogram_quantile(0.99, sum by (le, module) (rate(anomaly_exporter_probe_duration_seconds_bucket' + rsBrace + '[10m]))) > 30',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Anomaly exporter module {{ $labels.module }} probe p99 is above 30s; the module query is too slow for its scrape interval.' }),
      ]),
    ], [
      alert.rule.group('anomaly-exporter.rules', [
        alert.rule.record('module:anomaly_exporter_probes:rate5m', 'sum by (module, result) (rate(anomaly_exporter_probes_total' + rsBrace + '[5m]))'),
        alert.rule.record('module:anomaly_exporter_probe_duration_seconds:p99_5m', 'histogram_quantile(0.99, sum by (le, module) (rate(anomaly_exporter_probe_duration_seconds_bucket' + rsBrace + '[5m])))'),
      ]),
    ]),
}
