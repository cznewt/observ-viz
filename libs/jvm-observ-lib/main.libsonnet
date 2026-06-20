// observ-viz JVM runtime pack (hand-written).
// Mirrors Micrometer/Prometheus JVM metric conventions, emitted as native v2
// elements. Usage:
//   g.packs.runtimes.jvm.new({ selector: 'job="api"' }).grafana.dashboard
//   g.packs.runtimes.jvm.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-jvm',
      dashboardTitle: 'JVM runtime',
      dashboardTags: ['jvm', 'java', 'runtime'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'jvm_info',
    } + config;

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      heapUsed: sig('Heap used', 'sum without(area,id)(jvm_memory_used_bytes{area="heap",%(queriesSelector)s})', 'bytes'),
      heapMax: sig('Heap max', 'sum without(area,id)(jvm_memory_max_bytes{area="heap",%(queriesSelector)s})', 'bytes'),
      nonheapUsed: sig('Non-heap used', 'sum without(area,id)(jvm_memory_used_bytes{area="nonheap",%(queriesSelector)s})', 'bytes'),
      gcPauseAvg: sig('GC pause (avg)', 'rate(jvm_gc_pause_seconds_sum{%(queriesSelector)s}[$__rate_interval]) / rate(jvm_gc_pause_seconds_count{%(queriesSelector)s}[$__rate_interval])', 's'),
      gcRate: sig('GC rate', 'rate(jvm_gc_pause_seconds_count{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      threadsLive: sig('Live threads', 'jvm_threads_live_threads{%(queriesSelector)s}', 'short'),
      threadsDaemon: sig('Daemon threads', 'jvm_threads_daemon_threads{%(queriesSelector)s}', 'short'),
      classesLoaded: sig('Loaded classes', 'jvm_classes_loaded_classes{%(queriesSelector)s}', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Memory',
        width: 8,
        height: 7,
        elements: {
          heapUsed: signals.heapUsed.asTimeSeries('Heap used'),
          heapMax: signals.heapMax.asTimeSeries('Heap max'),
          nonheapUsed: signals.nonheapUsed.asTimeSeries('Non-heap used'),
        },
      },
      {
        title: 'Garbage collection',
        width: 12,
        height: 7,
        elements: {
          gcPauseAvg: signals.gcPauseAvg.asTimeSeries('GC pause (avg)'),
          gcRate: signals.gcRate.asTimeSeries('GC cycles/s'),
        },
      },
      {
        title: 'Threads',
        width: 12,
        height: 7,
        elements: {
          threadsLive: signals.threadsLive.asTimeSeries('Live threads'),
          threadsDaemon: signals.threadsDaemon.asTimeSeries('Daemon threads'),
        },
      },
      {
        title: 'Classes',
        width: 12,
        height: 7,
        elements: {
          classesLoaded: signals.classesLoaded.asTimeSeries('Loaded classes'),
        },
      },
    ]),
}
