// observ-viz Loki pack (hand-written).
// Grafana Loki self-monitoring (loki_* metrics), emitted as native v2 elements.
// Usage:
//   g.libs.lgtm.loki.new({ selector: 'job="loki"' }).grafana.dashboard
//   g.libs.lgtm.loki.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-loki',
      dashboardTitle: 'Loki',
      dashboardTags: ['loki', 'lgtm', 'grafana'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'loki_build_info',
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
    ], [
      // alerting rule group
      alert.rule.group('loki', [
        alert.rule.new(
          'LokiDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'Loki {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'LokiHighRequestLatency',
          'histogram_quantile(0.99, sum by (le) (rate(loki_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 1',
          '15m', 'warning', {},
          { summary: 'Request latency p99 on {{ $labels.instance }} is above 1s.' }
        ),
        alert.rule.new(
          'LokiHighHeapMemory',
          'go_memstats_heap_inuse_bytes' + rsBrace + ' > 1e9',
          '15m', 'warning', {},
          { summary: 'Heap in use on {{ $labels.instance }} is above 1GB.' }
        ),
        alert.rule.new(
          'LokiManyActiveStreams',
          'sum(loki_ingester_memory_streams' + rsBrace + ') > 100000',
          '15m', 'warning', {},
          { summary: 'Active streams on {{ $labels.instance }} are above 100000.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('loki.rules', [
        alert.rule.record('instance:loki_lines_received:rate5m', 'sum(rate(loki_distributor_lines_received_total' + rsBrace + '[5m]))'),
        alert.rule.record('instance:loki_bytes_received:rate5m', 'sum(rate(loki_distributor_bytes_received_total' + rsBrace + '[5m]))'),
      ]),
    ]),
}
