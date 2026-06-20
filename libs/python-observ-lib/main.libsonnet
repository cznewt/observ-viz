// observ-viz Python runtime pack (hand-written).
// Built from prometheus_client default metrics (python_gc_* + process_*),
// emitted as native v2 elements. Usage:
//   g.libs.runtimes.python.new({ selector: 'job="api"' }).grafana.dashboard
//   g.libs.runtimes.python.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-python',
      dashboardTitle: 'Python runtime',
      dashboardTags: ['python', 'runtime'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'python_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      gcCollections: sig('GC collections', 'sum without(generation)(rate(python_gc_collections_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      gcObjects: sig('GC objects collected', 'rate(python_gc_objects_collected_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes'),
      openFds: sig('Open FDs', 'process_open_fds{%(queriesSelector)s}', 'short'),
      maxFds: sig('Max FDs', 'process_max_fds{%(queriesSelector)s}', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Garbage collection',
        width: 12,
        height: 7,
        elements: {
          gcCollections: signals.gcCollections.asTimeSeries('GC collections/s'),
          gcObjects: signals.gcObjects.asTimeSeries('Objects collected/s'),
        },
      },
      {
        title: 'Process',
        width: 12,
        height: 7,
        elements: {
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          rss: signals.rss.asTimeSeries('Resident memory'),
        },
      },
      {
        title: 'File descriptors',
        width: 12,
        height: 7,
        elements: {
          openFds: signals.openFds.asTimeSeries('Open file descriptors'),
          maxFds: signals.maxFds.asTimeSeries('Max file descriptors'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('python', [
        alert.rule.new(
          'PythonProcessDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'Python process {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'PythonHighCpu',
          'rate(process_cpu_seconds_total' + rsBrace + '[5m]) > 0.9',
          '15m', 'warning', {},
          { summary: 'CPU on {{ $labels.instance }} is above 90%.' }
        ),
        alert.rule.new(
          'PythonHighMemory',
          'process_resident_memory_bytes' + rsBrace + ' > 1e9',
          '15m', 'warning', {},
          { summary: 'Resident memory on {{ $labels.instance }} is above 1GB.' }
        ),
        alert.rule.new(
          'PythonFileDescriptorsExhausted',
          'process_open_fds' + rsBrace + ' / process_max_fds' + rsBrace + ' > 0.9',
          '15m', 'warning', {},
          { summary: 'Open file descriptors on {{ $labels.instance }} are above 90% of the limit.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('python.rules', [
        alert.rule.record('instance:python_cpu_usage:rate5m', 'rate(process_cpu_seconds_total' + rsBrace + '[5m])'),
        alert.rule.record('instance:python_gc_collections:rate5m', 'sum without (generation) (rate(python_gc_collections_total' + rsBrace + '[5m]))'),
      ]),
    ]),
}
