// observ-viz Python runtime pack (hand-written).
// Built from prometheus_client default metrics (python_gc_* + process_*),
// emitted as native v2 elements. Usage:
//   g.libs.runtimes.python.new({ selector: 'job="api"' }).grafana.dashboard
//   g.libs.runtimes.python.new({...}).grafana.elements   // reuse in a board
local alert = import 'libs/common-lib/alert/main.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';

{
  // the element map, for a board that embeds the Python runtime in a tab of
  // its own (the Django pack does) rather than rendering this board.
  elements(datasource, selector, prefix='')::
    local p = $.new({ datasource: datasource, selector: selector, docTabs: false });
    { [prefix + k]: p.grafana.elements[k] for k in std.objectFields(p.grafana.elements) },

  new(config={}):
    local cfg = {
      uid: 'observ-viz-python',
      dashboardTitle: 'Python runtime',
      dashboardTags: ['python', 'runtime'],
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal (process_*, go_*) cannot reach another component's
      // instances where the job label does not discriminate them
      selector: 'job=~"$job", instance=~"$instance"',
      // cascading filter variables + series legend, e.g. ['namespace', 'pod'].
      varLabels: ['instance'],
      legendLabels: [],
      // signals shown as columns of the Overview instances table.
      overviewSignals: ['cpu', 'rss', 'openFds', 'gcCollections'],
      varMetric: 'python_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig = filters.sig(cfg);

    local signals = {
      gcCollections: sig('GC collections', 'sum without(generation)(rate(python_gc_collections_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'Generational collections per second.'),
      gcObjects: sig('GC objects collected', 'rate(python_gc_objects_collected_total{%(queriesSelector)s}[$__rate_interval])', 'short', 'Objects the collector frees per second.'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short', 'Process CPU cores used.'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes', 'Resident set size (RSS).'),
      openFds: sig('Open FDs', 'process_open_fds{%(queriesSelector)s}', 'short', 'Open file descriptors.'),
      maxFds: sig('Max FDs', 'process_max_fds{%(queriesSelector)s}', 'short', 'File-descriptor limit for the process.'),
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
          'PythonProcessDown',
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('python_info', cfg.ruleSelector),
          '5m',
          'critical',
          {},
          { summary: 'Python process {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'PythonHighCpu',
          'rate(process_cpu_seconds_total' + rsBrace + '[5m]) > 0.9',
          '15m',
          'warning',
          {},
          { summary: 'CPU on {{ $labels.instance }} is above 90%.' }
        ),
        alert.rule.new(
          'PythonHighMemory',
          'process_resident_memory_bytes' + rsBrace + ' > 1e9',
          '15m',
          'warning',
          {},
          { summary: 'Resident memory on {{ $labels.instance }} is above 1GB.' }
        ),
        alert.rule.new(
          'PythonFileDescriptorsExhausted',
          'process_open_fds' + rsBrace + ' / process_max_fds' + rsBrace + ' > 0.9',
          '15m',
          'warning',
          {},
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
