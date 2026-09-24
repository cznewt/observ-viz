// observ-viz reference — Runtimes folder. One TABBED board per language runtime
// and per framework built on one: an Overview tab (what the board is, reference
// links, a table of instances) + one tab per signal group, each opening with
// that group's signal table. A framework board ends with the runtime it runs
// on, so a slow request and a busy interpreter are one board apart.
local g = import 'g.libsonnet';
local util = import 'libs/reference-lib/_util.libsonnet';

// runtime key, board title, one-line description, reference links.
local runtimes = [
  {
    key: 'golang',
    title: 'Go',
    description: 'The Go runtime as exposed by `client_golang`: goroutines, threads, heap, stack and garbage collection, plus the shared `process_*` metrics.',
    references: [
      { title: 'Go runtime metrics', url: 'https://pkg.go.dev/runtime/metrics', description: 'what the runtime itself measures' },
      { title: 'client_golang', url: 'https://github.com/prometheus/client_golang', description: 'the exporter behind go_* and process_*' },
      { title: 'Instrumenting a Go application', url: 'https://prometheus.io/docs/guides/go-application/', description: 'Prometheus guide' },
    ],
  },
  {
    key: 'jvm',
    title: 'JVM',
    description: 'JVM memory pools, threads, loaded classes and garbage collection, as exposed by Micrometer or the JMX exporter.',
    references: [
      { title: 'Micrometer JVM metrics', url: 'https://docs.micrometer.io/micrometer/reference/reference/jvm.html', description: 'jvm_* meter binders' },
      { title: 'JMX exporter', url: 'https://github.com/prometheus/jmx_exporter', description: 'for apps without Micrometer' },
    ],
  },
  {
    key: 'python',
    title: 'Python',
    description: 'CPython garbage collection plus the process metrics exposed by `prometheus_client` default collectors.',
    references: [
      { title: 'prometheus_client', url: 'https://prometheus.github.io/client_python/', description: 'the exporter behind python_* and process_*' },
      { title: 'gc module', url: 'https://docs.python.org/3/library/gc.html', description: 'what the generational collector counts' },
    ],
  },
  {
    key: 'dotnet',
    title: '.NET',
    description: 'The .NET runtime as exposed by prometheus-net: managed heap, thread pool, exceptions and JIT activity.',
    references: [
      { title: 'prometheus-net', url: 'https://github.com/prometheus-net/prometheus-net', description: 'the exporter behind dotnet_*' },
      { title: '.NET runtime metrics', url: 'https://learn.microsoft.com/dotnet/core/diagnostics/available-counters', description: 'the counters underneath' },
    ],
  },
  {
    key: 'rust',
    title: 'Rust',
    description: 'The Tokio runtime as exposed by the `tokio-metrics` crate: the worker threads, what they are busy with, and the queues behind them. Rust has no runtime of its own to measure, so this is the async executor most services run on.',
    references: [
      { title: 'tokio-metrics', url: 'https://docs.rs/tokio-metrics/', description: 'the crate behind every tokio_* series here' },
      { title: 'Tokio scheduler', url: 'https://tokio.rs/blog/2019-10-scheduler', description: 'what the local queues, steals and overflows mean' },
    ],
  },
  {
    key: 'nodejs',
    title: 'Node.js',
    description: 'The Node.js event loop, V8 heap and handle/request counts, as exposed by `prom-client` default metrics.',
    references: [
      { title: 'prom-client', url: 'https://github.com/siimon/prom-client', description: 'the exporter behind nodejs_*' },
      { title: 'Event loop lag', url: 'https://nodejs.org/api/perf_hooks.html#perf_hooksmonitoreventloopdelayoptions', description: 'what the lag signals measure' },
    ],
  },
];

// frameworks: the pack's own config already carries its description and
// references, so these only need the folder, the filters and the legend.
local frameworks = [
  { key: 'django', lib: 'django' },
  { key: 'rails', lib: 'rails' },
];

{
  _config+:: {},
  grafanaDashboards+:: {
    ['lang-' + r.key + '.json']:
      util.place(
        util.tabbedBoard(
          g.libs.runtimes[r.key].new({
            uid: 'observ-viz-lang-' + r.key,
            dashboardTitle: r.title,
            datasource: $._config.datasource,
            description: r.description,
            references: r.references,
            // cascading filters + a legend that names the pod, not the URL.
            varLabels: ['namespace', 'pod', 'instance'],
            legendLabels: ['namespace', 'pod'],
            // the Overview table is keyed by namespace/pod
            rowLabels: ['namespace', 'pod'],
          }),
          r.title,
          'observ-viz-lang-' + r.key,
        ),
        $._config.folders.languages,
        $._config.tags,
      )
    for r in runtimes
  } + {
    ['framework-' + f.key + '.json']:
      util.place(
        g.libs.frameworks[f.lib].new({
          uid: 'observ-viz-framework-' + f.key,
          datasource: $._config.datasource,
          varLabels: ['namespace', 'pod', 'instance'],
          legendLabels: ['namespace', 'pod'],
          rowLabels: ['namespace', 'pod'],
        }).grafana.dashboard,
        $._config.folders.languages,
        $._config.tags,
      )
    for f in frameworks
  },
}
