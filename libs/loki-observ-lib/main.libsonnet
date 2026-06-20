// observ-viz Loki pack (hand-written).
// Grafana Loki self-monitoring (loki_* metrics), emitted as native v2 elements.
// Usage:
//   g.packs.lgtm.loki.new({ selector: 'job="loki"' }).grafana.dashboard
//   g.packs.lgtm.loki.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-loki',
      dashboardTitle: 'Loki',
      dashboardTags: ['loki', 'lgtm', 'grafana'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'loki_build_info',
    } + config;

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      lines: sig('Lines received', 'sum(rate(loki_distributor_lines_received_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      bytes: sig('Bytes received', 'sum(rate(loki_distributor_bytes_received_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      streams: sig('Active streams', 'sum(loki_ingester_memory_streams{%(queriesSelector)s})', 'short'),
      requestP99: sig('Request latency p99', 'histogram_quantile(0.99, sum by (le)(rate(loki_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's'),
      heap: sig('Heap in use', 'go_memstats_heap_inuse_bytes{%(queriesSelector)s}', 'bytes'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Writes',
        width: 8,
        height: 7,
        elements: {
          lines: signals.lines.asTimeSeries('Lines received/s'),
          bytes: signals.bytes.asTimeSeries('Bytes received/s'),
          streams: signals.streams.asTimeSeries('Active streams'),
        },
      },
      {
        title: 'Reads',
        width: 12,
        height: 7,
        elements: {
          requestP99: signals.requestP99.asTimeSeries('Request latency p99'),
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
