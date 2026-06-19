// observ-viz Go runtime pack (hand-written).
// Mirrors grafana/jsonnet-libs golang-observ-lib signal conventions, emitted as
// native v2 elements. Usage:
//   g.packs.runtimes.golang.new({ selector: 'job="api"' }).grafana.dashboard
//   g.packs.runtimes.golang.new({...}).grafana.elements   // reuse in a board
local pack = import 'packs/_pack.libsonnet';
local signal = import 'signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-golang',
      dashboardTitle: 'Go runtime',
      dashboardTags: ['golang', 'runtime'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
    } + config;

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
    goroutines: sig('Goroutines', 'go_goroutines{%(queriesSelector)s}', 'short'),
    threads: sig('OS threads', 'go_threads{%(queriesSelector)s}', 'short'),
    cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
    openFds: sig('Open FDs', 'process_open_fds{%(queriesSelector)s}', 'short'),
    heapInuse: sig('Heap in use', 'go_memstats_heap_inuse_bytes{%(queriesSelector)s}', 'bytes'),
    heapAlloc: sig('Heap alloc', 'go_memstats_heap_alloc_bytes{%(queriesSelector)s}', 'bytes'),
    heapObjects: sig('Heap objects', 'go_memstats_heap_objects{%(queriesSelector)s}', 'short'),
    stackInuse: sig('Stack in use', 'go_memstats_stack_inuse_bytes{%(queriesSelector)s}', 'bytes'),
    rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes'),
    gcPauseMax: sig('GC pause (max)', 'go_gc_duration_seconds{quantile="1", %(queriesSelector)s}', 's'),
    gcRate: sig('GC rate', 'rate(go_gc_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])', 'ops'),
  };

  pack.build(cfg, signals, [
    {
      title: 'Go runtime',
      width: 6,
      height: 7,
      elements: {
        goroutines: signals.goroutines.asTimeSeries('Goroutines'),
        threads: signals.threads.asTimeSeries('OS threads'),
        cpu: signals.cpu.asTimeSeries('CPU (cores)'),
        openFds: signals.openFds.asTimeSeries('Open file descriptors'),
      },
    },
    {
      title: 'Memory',
      width: 6,
      height: 7,
      elements: {
        heapInuse: signals.heapInuse.asTimeSeries('Heap in use'),
        heapAlloc: signals.heapAlloc.asTimeSeries('Heap alloc'),
        stackInuse: signals.stackInuse.asTimeSeries('Stack in use'),
        rss: signals.rss.asTimeSeries('Resident memory'),
      },
    },
    {
      title: 'Garbage collection',
      width: 12,
      height: 7,
      elements: {
        gcPauseMax: signals.gcPauseMax.asTimeSeries('GC pause (max quantile)'),
        gcRate: signals.gcRate.asTimeSeries('GC cycles/s'),
      },
    },
  ]),
}
