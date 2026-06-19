// observ-viz Node.js runtime pack (hand-written).
// Mirrors prom-client default metrics (nodejs_*, process_*), emitted as native
// v2 elements. Usage:
//   g.packs.runtimes.nodejs.new({ selector: 'job="api"' }).grafana.dashboard
//   g.packs.runtimes.nodejs.new({...}).grafana.elements   // reuse in a board
local pack = import 'packs/_pack.libsonnet';
local signal = import 'signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-nodejs',
      dashboardTitle: 'Node.js runtime',
      dashboardTags: ['nodejs', 'runtime'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'nodejs_version_info',
    } + config;

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
    ]),
}
