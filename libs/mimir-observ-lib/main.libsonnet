// observ-viz Mimir pack (hand-written).
// Grafana Mimir self-monitoring. Mimir exposes cortex_* metrics. Usage:
//   g.libs.lgtm.mimir.new({ selector: 'job="mimir"' }).grafana.dashboard
//   g.libs.lgtm.mimir.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-mimir',
      dashboardTitle: 'Mimir',
      dashboardTags: ['mimir', 'lgtm', 'grafana'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'cortex_build_info',
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
      receivedSamples: sig('Received samples', 'sum(rate(cortex_distributor_received_samples_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      ingesterSeries: sig('Ingester series', 'sum(cortex_ingester_memory_series{%(queriesSelector)s})', 'short'),
      queries: sig('Queries', 'sum(rate(cortex_query_frontend_queries_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps'),
      requestP99: sig('Request p99', 'histogram_quantile(0.99, sum by (le)(rate(cortex_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's'),
      heap: sig('Heap in use', 'go_memstats_heap_inuse_bytes{%(queriesSelector)s}', 'bytes'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Writes',
        width: 12,
        height: 7,
        elements: {
          receivedSamples: signals.receivedSamples.asTimeSeries('Received samples/s'),
          ingesterSeries: signals.ingesterSeries.asTimeSeries('Ingester in-memory series'),
        },
      },
      {
        title: 'Reads',
        width: 12,
        height: 7,
        elements: {
          queries: signals.queries.asTimeSeries('Queries/s'),
          requestP99: signals.requestP99.asTimeSeries('Request duration p99'),
        },
      },
      {
        title: 'Resources',
        width: 12,
        height: 7,
        elements: {
          heap: signals.heap.asTimeSeries('Heap in use'),
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('mimir', [
        alert.rule.new(
          'MimirDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'Mimir {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'MimirHighRequestLatency',
          'histogram_quantile(0.99, sum by (le) (rate(cortex_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 1',
          '15m', 'warning', {},
          { summary: 'Request p99 latency on {{ $labels.instance }} is above 1s.' }
        ),
        alert.rule.new(
          'MimirHighHeapMemory',
          'go_memstats_heap_inuse_bytes' + rsBrace + ' > 4e9',
          '15m', 'warning', {},
          { summary: 'Heap in use on {{ $labels.instance }} is above 4GB.' }
        ),
        alert.rule.new(
          'MimirHighCpu',
          'rate(process_cpu_seconds_total' + rsBrace + '[5m]) > 0.9',
          '15m', 'warning', {},
          { summary: 'CPU on {{ $labels.instance }} is above 90%.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('mimir.rules', [
        alert.rule.record('instance:cortex_received_samples:rate5m', 'sum(rate(cortex_distributor_received_samples_total' + rsBrace + '[5m]))'),
        alert.rule.record('instance:cortex_queries:rate5m', 'sum(rate(cortex_query_frontend_queries_total' + rsBrace + '[5m]))'),
      ]),
    ]),
}
