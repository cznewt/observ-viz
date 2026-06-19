// observ-viz Pyroscope pack (hand-written).
// Grafana Pyroscope self-monitoring (pyroscope_* metrics), emitted as native v2
// elements. Usage:
//   g.packs.lgtm.pyroscope.new({ selector: 'job="pyroscope"' }).grafana.dashboard
local pack = import 'packs/_pack.libsonnet';
local signal = import 'signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-pyroscope',
      dashboardTitle: 'Pyroscope',
      dashboardTags: ['pyroscope', 'lgtm', 'grafana'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'pyroscope_build_info',
    } + config;

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      receivedBytes: sig('Received bytes', 'sum(rate(pyroscope_distributor_received_compressed_bytes_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      requestRate: sig('Request rate', 'sum(rate(pyroscope_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps'),
      latencyP99: sig('Latency p99', 'histogram_quantile(0.99, sum by (le)(rate(pyroscope_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's'),
      latencyP50: sig('Latency p50', 'histogram_quantile(0.50, sum by (le)(rate(pyroscope_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's'),
      heapInuse: sig('Heap in use', 'go_memstats_heap_inuse_bytes{%(queriesSelector)s}', 'bytes'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      goroutines: sig('Goroutines', 'go_goroutines{%(queriesSelector)s}', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Ingest',
        width: 12,
        height: 7,
        elements: {
          receivedBytes: signals.receivedBytes.asTimeSeries('Received bytes/s'),
        },
      },
      {
        title: 'Requests',
        width: 6,
        height: 7,
        elements: {
          requestRate: signals.requestRate.asTimeSeries('Request rate'),
          latencyP99: signals.latencyP99.asTimeSeries('Latency p99'),
          latencyP50: signals.latencyP50.asTimeSeries('Latency p50'),
        },
      },
      {
        title: 'Resources',
        width: 6,
        height: 7,
        elements: {
          heapInuse: signals.heapInuse.asTimeSeries('Heap in use'),
          rss: signals.rss.asTimeSeries('Resident memory'),
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          goroutines: signals.goroutines.asTimeSeries('Goroutines'),
        },
      },
    ]),
}
