// observ-viz Node.js runtime pack (hand-written).
// Mirrors prom-client default metrics (nodejs_*, process_*), emitted as native
// v2 elements. Usage:
//   g.libs.runtimes.nodejs.new({ selector: 'job="api"' }).grafana.dashboard
//   g.libs.runtimes.nodejs.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-nodejs',
      dashboardTitle: 'Node.js runtime',
      dashboardTags: ['nodejs', 'runtime'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'nodejs_version_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      eventloopLag: sig('Event loop lag', 'nodejs_eventloop_lag_seconds{%(queriesSelector)s}', 's'),
      eventloopLagP99: sig('Event loop lag p99', 'nodejs_eventloop_lag_p99_seconds{%(queriesSelector)s}', 's'),
      heapUsed: sig('Heap used', 'nodejs_heap_size_used_bytes{%(queriesSelector)s}', 'bytes'),
      heapTotal: sig('Heap total', 'nodejs_heap_size_total_bytes{%(queriesSelector)s}', 'bytes'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes'),
      gcDuration: sig('GC duration', 'rate(nodejs_gc_duration_seconds_sum{%(queriesSelector)s}[$__rate_interval])', 's'),
      activeHandles: sig('Active handles', 'nodejs_active_handles_total{%(queriesSelector)s}', 'short'),
      activeRequests: sig('Active requests', 'nodejs_active_requests_total{%(queriesSelector)s}', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Event loop',
        width: 12,
        height: 7,
        elements: {
          eventloopLag: signals.eventloopLag.asTimeSeries('Event loop lag'),
          eventloopLagP99: signals.eventloopLagP99.asTimeSeries('Event loop lag (p99)'),
        },
      },
      {
        title: 'Memory',
        width: 8,
        height: 7,
        elements: {
          heapUsed: signals.heapUsed.asTimeSeries('Heap used'),
          heapTotal: signals.heapTotal.asTimeSeries('Heap total'),
          rss: signals.rss.asTimeSeries('Resident memory'),
        },
      },
      {
        title: 'Garbage collection',
        width: 12,
        height: 7,
        elements: {
          gcDuration: signals.gcDuration.asTimeSeries('GC time/s'),
        },
      },
      {
        title: 'Handles',
        width: 12,
        height: 7,
        elements: {
          activeHandles: signals.activeHandles.asTimeSeries('Active handles'),
          activeRequests: signals.activeRequests.asTimeSeries('Active requests'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('nodejs', [
        alert.rule.new(
          'NodeJsDown',
          'absent(nodejs_heap_size_used_bytes' + rsBrace + ') == 1',
          '5m', 'critical', {},
          { summary: 'Node.js runtime metrics for {{ $labels.instance }} are unavailable.' }
        ),
        alert.rule.new(
          'NodeJsHighEventLoopLag',
          'nodejs_eventloop_lag_p99_seconds' + rsBrace + ' > 0.1',
          '15m', 'warning', {},
          { summary: 'Event loop lag (p99) on {{ $labels.instance }} is above 100ms.' }
        ),
        alert.rule.new(
          'NodeJsHighHeapUsage',
          'nodejs_heap_size_used_bytes' + rsBrace + ' / nodejs_heap_size_total_bytes' + rsBrace + ' > 0.9',
          '15m', 'warning', {},
          { summary: 'Heap usage on {{ $labels.instance }} is above 90% of heap total.' }
        ),
        alert.rule.new(
          'NodeJsHighGcTime',
          'rate(nodejs_gc_duration_seconds_sum{' + cfg.selector + '}[5m])' == '',  // placeholder
          '15m', 'warning', {},
          { summary: 'GC time on {{ $labels.instance }} is high.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('nodejs.rules', [
        alert.rule.record('instance:nodejs_heap_utilisation:ratio', 'nodejs_heap_size_used_bytes' + rsBrace + ' / nodejs_heap_size_total_bytes' + rsBrace),
        alert.rule.record('instance:nodejs_gc_duration:rate5m', 'rate(nodejs_gc_duration_seconds_sum{' + 'job=~".+"' + rsComma + '}[5m])'),
      ]),
    ]),
}
