// observ-viz Tempo pack (hand-written).
// Grafana Tempo self-monitoring (tempo_* metrics), emitted as native v2 elements.
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-tempo',
      dashboardTitle: 'Tempo',
      dashboardTags: ['tempo', 'lgtm', 'grafana'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'tempo_build_info',
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
      spansReceived: sig('Spans received', 'sum(rate(tempo_distributor_spans_received_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      tracesCreated: sig('Traces created', 'sum(rate(tempo_ingester_traces_created_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      bytesReceived: sig('Bytes received', 'sum(rate(tempo_distributor_bytes_received_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      blocklistLength: sig('Blocklist length', 'max(tempodb_blocklist_length{%(queriesSelector)s})', 'short'),
      blocksFlushed: sig('Blocks flushed', 'sum(rate(tempo_ingester_blocks_flushed_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      requestP99: sig('Request p99', 'histogram_quantile(0.99, sum by (le)(rate(tempo_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's'),
      requestRate: sig('Request rate', 'sum(rate(tempo_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps'),
      heapInuse: sig('Heap in use', 'go_memstats_heap_inuse_bytes{%(queriesSelector)s}', 'bytes'),
      goroutines: sig('Goroutines', 'go_goroutines{%(queriesSelector)s}', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Ingest',
        width: 6,
        height: 7,
        elements: {
          spansReceived: signals.spansReceived.asTimeSeries('Spans received/s'),
          tracesCreated: signals.tracesCreated.asTimeSeries('Traces created/s'),
          bytesReceived: signals.bytesReceived.asTimeSeries('Bytes received/s'),
        },
      },
      {
        title: 'Storage',
        width: 6,
        height: 7,
        elements: {
          blocklistLength: signals.blocklistLength.asStat('Blocklist length'),
          blocksFlushed: signals.blocksFlushed.asTimeSeries('Blocks flushed/s'),
        },
      },
      {
        title: 'Requests',
        width: 6,
        height: 7,
        elements: {
          requestP99: signals.requestP99.asTimeSeries('Request duration p99'),
          requestRate: signals.requestRate.asTimeSeries('Request rate'),
        },
      },
      {
        title: 'Resources',
        width: 6,
        height: 7,
        elements: {
          heapInuse: signals.heapInuse.asTimeSeries('Heap in use'),
          goroutines: signals.goroutines.asTimeSeries('Goroutines'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('tempo', [
        alert.rule.new(
          'TempoDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'Tempo {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'TempoHighBlocklistLength',
          'tempodb_blocklist_length' + rsBrace + ' > 1000',
          '15m', 'warning', {},
          { summary: 'Blocklist length on {{ $labels.instance }} is above 1000.' }
        ),
        alert.rule.new(
          'TempoSlowRequests',
          'histogram_quantile(0.99, sum by (le) (rate(tempo_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 1',
          '15m', 'warning', {},
          { summary: 'Request p99 on {{ $labels.instance }} is above 1s.' }
        ),
        alert.rule.new(
          'TempoHighGoroutines',
          'go_goroutines' + rsBrace + ' > 10000',
          '15m', 'warning', {},
          { summary: 'Goroutines on {{ $labels.instance }} are above 10000.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('tempo.rules', [
        alert.rule.record('instance:tempo_spans_received:rate5m', 'sum(rate(tempo_distributor_spans_received_total' + rsBrace + '[5m]))'),
        alert.rule.record('instance:tempo_request_rate:rate5m', 'sum(rate(tempo_request_duration_seconds_count' + rsBrace + '[5m]))'),
      ]),
    ]),
}
