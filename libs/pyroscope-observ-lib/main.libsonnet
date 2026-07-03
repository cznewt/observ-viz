// observ-viz Pyroscope pack (hand-written).
// Grafana Pyroscope self-monitoring (pyroscope_* metrics), emitted as native v2
// elements. Usage:
//   g.libs.lgtm.pyroscope.new({ selector: 'job="pyroscope"' }).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-pyroscope',
      dashboardTitle: 'Pyroscope',
      dashboardTags: ['pyroscope', 'lgtm', 'grafana'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'pyroscope_build_info',
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
    ], [
      // alerting rule group
      alert.rule.group('pyroscope', [
        alert.rule.new(
          'PyroscopeDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'Pyroscope {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'PyroscopeHighRequestLatency',
          'histogram_quantile(0.99, sum by (le' + rsComma + ')(rate(pyroscope_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 1',
          '15m', 'warning', {},
          { summary: 'Request p99 latency on {{ $labels.instance }} is above 1s.' }
        ),
        alert.rule.new(
          'PyroscopeHighHeapMemory',
          'go_memstats_heap_inuse_bytes' + rsBrace + ' > 2e9',
          '15m', 'warning', {},
          { summary: 'Heap in use on {{ $labels.instance }} is above 2GB.' }
        ),
        alert.rule.new(
          'PyroscopeHighGoroutines',
          'go_goroutines' + rsBrace + ' > 10000',
          '15m', 'warning', {},
          { summary: 'Goroutines on {{ $labels.instance }} are above 10000.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('pyroscope.rules', [
        alert.rule.record('instance:pyroscope_request_rate:rate5m', 'sum by (instance' + rsComma + ')(rate(pyroscope_request_duration_seconds_count' + rsBrace + '[5m]))'),
        alert.rule.record('instance:pyroscope_cpu_usage:rate5m', 'rate(process_cpu_seconds_total' + rsBrace + '[5m])'),
      ]),
    ]),
}
