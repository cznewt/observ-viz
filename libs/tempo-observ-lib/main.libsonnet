// observ-viz Tempo pack (hand-written).
// Grafana Tempo self-monitoring (tempo_* metrics), emitted as native v2 elements.
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-tempo',
      dashboardTitle: 'Tempo',
      dashboardTags: ['tempo', 'lgtm', 'grafana'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'tempo_build_info',
    } + config;

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
    ]),
}
