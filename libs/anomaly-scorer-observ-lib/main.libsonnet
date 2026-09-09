// observ-viz anomaly scorer pack (hand-written).
//
// Boards for the anomaly scorers in cznewt/monitor-tools (iqr / zscore /
// prophet). Each scorer range-queries one metric, scores how far the trailing
// points fall outside a band built from that metric's own recent history, and
// re-exports the worst point per series as a gauge — so anomaly detection
// becomes an ordinary Prometheus metric you can chart and alert on.
//
//   g.libs.monitoring.anomalyScorer.new({ selector: 'namespace="global-monitor-anomaly-scorer"' }).grafana.dashboard
//   g.libs.monitoring.anomalyScorer.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-anomaly-scorer',
      dashboardTitle: 'Anomaly scorer',
      dashboardTags: ['anomaly-detection', 'monitoring', 'app-level'],
      datasource: '${datasource}',
      selector: 'job=~"$job", pod=~"$pod"',
      varMetric: 'custom_anomaly_score',
      varLabels: ['pod'],
      // The score above which a series counts as anomalous. Keep it in step with
      // the threshold used by the alerting rule below.
      scoreThreshold: '0.8',
      // A scorer that has not published for several loop intervals is stuck.
      staleAfterSeconds: '1800',
      ruleSelector: '',
      docTabs: true,
      folderUid: 'software-monitoring',
      folderTitle: 'Monitoring',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      // 0 means the point sits inside the band; 1 means it is a full band width
      // outside it. The gauge is already normalised, so percentunit reads well.
      score: sig('Anomaly score', 'custom_anomaly_score{%(queriesSelector)s}', 'percentunit'),
      worstScore: sig('Worst score', 'max(custom_anomaly_score{%(queriesSelector)s})', 'percentunit'),
      anomalousSeries: sig(
        'Anomalous series',
        'count(custom_anomaly_score{%(queriesSelector)s} > ' + cfg.scoreThreshold + ') or vector(0)',
        'short'
      ),
      scoredSeries: sig('Scored series', 'count(custom_anomaly_score{%(queriesSelector)s})', 'short'),
      // How long ago the scorer last published. Flat and small is healthy; a
      // rising sawtooth taller than the loop interval means it is falling behind.
      staleness: sig(
        'Time since last score',
        'time() - max(timestamp(custom_anomaly_score{%(queriesSelector)s}))',
        's'
      ),
      up: sig('Scorers up', 'sum(up{%(queriesSelector)s})', 'short'),
      residentMemory: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Anomaly score',
        width: 24,
        height: 8,
        elements: {
          score: signals.score.asTimeSeries('Score per series'),
          worstScore: signals.worstScore.asStat('Worst score now'),
          anomalousSeries: signals.anomalousSeries.asStat('Series above threshold'),
        },
      },
      {
        title: 'Coverage',
        width: 12,
        height: 7,
        elements: {
          scoredSeries: signals.scoredSeries.asTimeSeries('Series being scored'),
          staleness: signals.staleness.asTimeSeries('Time since last score'),
        },
      },
      {
        title: 'Scorer health',
        width: 12,
        height: 7,
        elements: {
          up: signals.up.asStat('Scorers up'),
          residentMemory: signals.residentMemory.asTimeSeries('Resident memory'),
          cpu: signals.cpu.asTimeSeries('CPU'),
        },
      },
    ], [
      alert.rule.group('anomaly-scorer', [
        alert.rule.new(
          'AnomalyScoreHigh',
          'custom_anomaly_score' + rsBrace + ' > ' + cfg.scoreThreshold,
          '15m',
          'warning',
          {},
          {
            summary: 'A scored series is behaving unlike its recent history.',
            description: 'Anomaly score {{ printf "%.2f" $value }} on {{ $labels.pod }}. Compare the scored metric with its band before acting; the score says the shape changed, not that anything is broken.',
          }
        ),
        alert.rule.new(
          'AnomalyScorerDown',
          'up' + rsBrace + ' == 0',
          '5m',
          'critical',
          {},
          { summary: 'Anomaly scorer {{ $labels.pod }} is down, so nothing is being scored.' }
        ),
        alert.rule.new(
          'AnomalyScorerStale',
          'time() - timestamp(custom_anomaly_score' + rsBrace + ') > ' + cfg.staleAfterSeconds,
          '15m',
          'warning',
          {},
          { summary: 'Anomaly scorer {{ $labels.pod }} has not published a score recently.' }
        ),
      ]),
    ], [
      alert.rule.group('anomaly-scorer.rules', [
        alert.rule.record('pod:anomaly_score:max', 'max by (pod) (custom_anomaly_score' + rsBrace + ')'),
        alert.rule.record(
          'pod:anomaly_score_anomalous_series:count',
          'count by (pod) (custom_anomaly_score' + rsBrace + ' > ' + cfg.scoreThreshold + ')'
        ),
      ]),
    ]),
}
