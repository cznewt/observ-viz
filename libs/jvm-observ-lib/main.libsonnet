// observ-viz JVM runtime pack (hand-written).
// Mirrors Micrometer/Prometheus JVM metric conventions, emitted as native v2
// elements. Usage:
//   g.libs.runtimes.jvm.new({ selector: 'job="api"' }).grafana.dashboard
//   g.libs.runtimes.jvm.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-jvm',
      dashboardTitle: 'JVM runtime',
      dashboardTags: ['jvm', 'java', 'runtime'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'jvm_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

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
    ], [
      // alerting rule group
      alert.rule.group('jvm', [
        alert.rule.new(
          'JvmProcessDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'JVM process {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'JvmHighHeapMemory',
          'sum without(area,id)(jvm_memory_used_bytes{area="heap"' + rsComma + '}) / sum without(area,id)(jvm_memory_max_bytes{area="heap"' + rsComma + '}) > 0.9',
          '15m', 'warning', {},
          { summary: 'Heap usage on {{ $labels.instance }} is above 90%.' }
        ),
        alert.rule.new(
          'JvmSlowGcPause',
          'rate(jvm_gc_pause_seconds_sum' + rsBrace + '[5m]) / rate(jvm_gc_pause_seconds_count' + rsBrace + '[5m]) > 0.1',
          '15m', 'warning', {},
          { summary: 'Average GC pause on {{ $labels.instance }} is above 100ms.' }
        ),
        alert.rule.new(
          'JvmHighThreadCount',
          'jvm_threads_live_threads' + rsBrace + ' > 1000',
          '15m', 'warning', {},
          { summary: 'Live threads on {{ $labels.instance }} are above 1000.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('jvm.rules', [
        alert.rule.record('instance:jvm_heap_utilisation:ratio', 'sum without(area,id)(jvm_memory_used_bytes{area="heap"' + rsComma + '}) / sum without(area,id)(jvm_memory_max_bytes{area="heap"' + rsComma + '})'),
        alert.rule.record('instance:jvm_gc_rate:rate5m', 'rate(jvm_gc_pause_seconds_count' + rsBrace + '[5m])'),
      ]),
    ]),
}
