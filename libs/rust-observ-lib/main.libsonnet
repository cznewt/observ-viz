// observ-viz Rust runtime pack (hand-written).
// Rust's Prometheus clients expose the process_* base and nothing else about
// the language, so this pack is the base plus the Tokio runtime metrics from
// tokio-metrics-collector (tokio_*, which needs RUSTFLAGS="--cfg
// tokio_unstable"). A Rust service without Tokio is fully covered by
// runtimes.process alone.
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local processLib = import 'libs/process-observ-lib/main.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-rust',
      dashboardTitle: 'Rust runtime',
      dashboardTags: ['rust', 'tokio', 'runtime'],
      description: 'A Rust service: the Tokio runtime (workers, how busy they are, queue depths, parks, polls and steals) over the process base that every Prometheus client exposes.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'process_start_time_seconds',
      ruleSelector: '',
      legend: '{{instance}}',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-runtimes',
      folderTitle: 'Runtimes',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      workers: sig('Workers', 'tokio_workers_count{%(queriesSelector)s}', 'short', desc='Worker threads in the Tokio runtime.'),
      busy: sig('Worker busy', '100 * sum by (instance) (rate(tokio_total_busy_duration{%(queriesSelector)s}[$__rate_interval])) / sum by (instance) (tokio_workers_count{%(queriesSelector)s})', 'percent', desc='Share of worker time spent running tasks rather than parked. Near 100 percent means the runtime is saturated.'),
      globalQueue: sig('Global queue depth', 'tokio_global_queue_depth{%(queriesSelector)s}', 'short', desc='Tasks waiting in the runtime-wide queue. A standing backlog means not enough workers or blocking work on the async threads.'),
      localQueue: sig('Local queue depth', 'tokio_total_local_queue_depth{%(queriesSelector)s}', 'short', desc='Tasks queued on the workers own queues.'),
      polls: sig('Polls', 'rate(tokio_total_polls_count{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Task polls per second, the runtime work rate.'),
      parks: sig('Parks', 'rate(tokio_total_park_count{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='How often workers went to sleep for lack of work.'),
      steals: sig('Steals', 'rate(tokio_total_steal_count{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Tasks stolen between workers. High steal rates mean uneven load.'),
      overflows: sig('Queue overflows', 'rate(tokio_total_overflow_count{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Local queues overflowing into the global queue.'),
      forcedYields: sig('Forced yields', 'rate(tokio_budget_forced_yield_count{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Tasks forced to yield because they used their whole budget. A sign of long-running work on the async runtime.'),
      ioReady: sig('IO readiness events', 'rate(tokio_io_driver_ready_count{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Readiness events the IO driver handled per second.'),
      remoteSchedules: sig('Remote schedules', 'rate(tokio_num_remote_schedules{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Tasks scheduled from outside the runtime threads.'),
    };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Tokio runtime',
        elements: {
          workers: signals.workers.asTimeSeries('Workers'),
          busy: signals.busy.asTimeSeries('Worker busy'),
          globalQueue: signals.globalQueue.asTimeSeries('Global queue depth')
                       + panel.withTargetsMixin([signals.localQueue.asTarget()]),
          polls: signals.polls.asTimeSeries('Polls/s')
                 + panel.withTargetsMixin([signals.parks.asTarget()]),
        },
      } + charts,
      {
        title: 'Scheduling',
        elements: {
          steals: signals.steals.asTimeSeries('Steals/s'),
          overflows: signals.overflows.asTimeSeries('Queue overflows/s'),
          forcedYields: signals.forcedYields.asTimeSeries('Forced yields/s'),
          remoteSchedules: signals.remoteSchedules.asTimeSeries('Remote schedules/s'),
          ioReady: signals.ioReady.asTimeSeries('IO readiness events/s'),
        },
      } + charts,
    ], [
      alert.rule.group('rust', [
        alert.rule.new('TokioRuntimeSaturated',
                       '100 * sum by (instance, job) (rate(tokio_total_busy_duration' + rsBrace + '[5m])) / sum by (instance, job) (tokio_workers_count' + rsBrace + ') > 90',
                       '15m', 'warning', {},
                       { summary: 'Tokio workers on {{ $labels.instance }} are busy more than 90 percent of the time.' }),
        alert.rule.new('TokioQueueBacklog', 'tokio_global_queue_depth' + rsBrace + ' > 100', '10m', 'warning', {},
                       { summary: 'Tokio on {{ $labels.instance }} keeps more than 100 tasks waiting in the global queue.' }),
        alert.rule.new('TokioForcedYields', 'rate(tokio_budget_forced_yield_count' + rsBrace + '[5m]) > 1', '15m', 'info', {},
                       { summary: 'Tasks on {{ $labels.instance }} are being forced to yield; something blocking is running on the async runtime.' }),
      ]),
    ], [
      alert.rule.group('rust.rules', [
        alert.rule.record('instance:tokio_worker_busy:ratio5m',
                          'sum by (instance, job) (rate(tokio_total_busy_duration' + rsBrace + '[5m])) / sum by (instance, job) (tokio_workers_count' + rsBrace + ')'),
      ]),
    ], [
      {
        title: 'Process',
        width: 12,
        height: 7,
        alwaysShow: true,
        elements: processLib.elements(cfg.datasource, cfg.selector, 'proc_'),
      },
    ]),
}
