// observ-viz .NET runtime pack (hand-written).
// Mirrors prometheus-net runtime metrics (dotnet_* family), emitted as native v2
// elements. Usage:
//   g.libs.runtimes.dotnet.new({ selector: 'job="api"' }).grafana.dashboard
//   g.libs.runtimes.dotnet.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-dotnet',
      dashboardTitle: '.NET runtime',
      dashboardTags: ['dotnet', 'runtime'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'dotnet_build_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      // GC. prometheus-net exposes total managed heap and per-generation collection counts.
      gcHeap: sig('GC heap', 'dotnet_total_memory_bytes{%(queriesSelector)s}', 'bytes'),
      gcCollections: sig('GC collections', 'sum without(generation)(rate(dotnet_collection_count_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      // Process memory + CPU exposed alongside the dotnet_* family by prometheus-net.
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      // Threads. Number of thread-pool threads in use, plus total OS threads.
      threadpool: sig('Thread-pool threads', 'dotnet_threadpool_num_threads{%(queriesSelector)s}', 'short'),
      processThreads: sig('Process threads', 'process_num_threads{%(queriesSelector)s}', 'short'),
      // Exceptions thrown per second.
      exceptions: sig('Exceptions', 'rate(dotnet_exceptions_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      // JIT. Methods compiled per second.
      jitMethods: sig('JIT methods', 'rate(dotnet_jit_method_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Garbage collection',
        width: 6,
        height: 7,
        elements: {
          gcHeap: signals.gcHeap.asTimeSeries('Managed heap'),
          gcCollections: signals.gcCollections.asTimeSeries('Collections/s'),
          rss: signals.rss.asTimeSeries('Resident memory'),
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
        },
      },
      {
        title: 'Threads',
        width: 12,
        height: 7,
        elements: {
          threadpool: signals.threadpool.asTimeSeries('Thread-pool threads'),
          processThreads: signals.processThreads.asTimeSeries('Process threads'),
        },
      },
      {
        title: 'Exceptions',
        width: 12,
        height: 7,
        elements: {
          exceptions: signals.exceptions.asTimeSeries('Exceptions/s'),
        },
      },
      {
        title: 'JIT',
        width: 12,
        height: 7,
        elements: {
          jitMethods: signals.jitMethods.asTimeSeries('JIT methods/s'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('dotnet', [
        alert.rule.new(
          'DotnetDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: '.NET app {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'DotnetHighExceptionRate',
          'rate(dotnet_exceptions_total' + rsBrace + '[5m]) > 1',
          '15m', 'warning', {},
          { summary: 'Exception rate on {{ $labels.instance }} is above 1/s.' }
        ),
        alert.rule.new(
          'DotnetHighCpu',
          'rate(process_cpu_seconds_total' + rsBrace + '[5m]) > 0.9',
          '15m', 'warning', {},
          { summary: 'CPU on {{ $labels.instance }} is above 0.9 cores.' }
        ),
        alert.rule.new(
          'DotnetThreadPoolStarvation',
          'dotnet_threadpool_num_threads' + rsBrace + ' > 200',
          '15m', 'warning', {},
          { summary: 'Thread-pool threads on {{ $labels.instance }} are above 200.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('dotnet.rules', [
        alert.rule.record('instance:dotnet_exceptions:rate5m', 'rate(dotnet_exceptions_total' + rsBrace + '[5m])'),
        alert.rule.record('instance:dotnet_cpu_utilisation:rate5m', 'rate(process_cpu_seconds_total' + rsBrace + '[5m])'),
      ]),
    ]),
}
