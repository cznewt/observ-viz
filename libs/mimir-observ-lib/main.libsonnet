// observ-viz Mimir pack (hand-written).
// Grafana Mimir self-monitoring. Mimir exposes cortex_* metrics. Usage:
//   g.libs.lgtm.mimir.new({ selector: 'job="mimir"' }).grafana.dashboard
//   g.libs.lgtm.mimir.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-mimir',
      dashboardTitle: 'Mimir',
      dashboardTags: ['mimir', 'lgtm', 'grafana'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'cortex_build_info',
    } + config;

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
    ]),
}
