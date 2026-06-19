// observ-viz Python runtime pack (hand-written).
// Built from prometheus_client default metrics (python_gc_* + process_*),
// emitted as native v2 elements. Usage:
//   g.packs.runtimes.python.new({ selector: 'job="api"' }).grafana.dashboard
//   g.packs.runtimes.python.new({...}).grafana.elements   // reuse in a board
local pack = import 'packs/_pack.libsonnet';
local signal = import 'signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-python',
      dashboardTitle: 'Python runtime',
      dashboardTags: ['python', 'runtime'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'python_info',
    } + config;

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
    ]),
}
