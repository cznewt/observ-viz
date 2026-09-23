// observ-viz Ruby runtime pack (hand-written).
// Ruby exposes little about the VM itself, so this pack is built from what a
// Rails deployment actually reports through discourse/prometheus_exporter: the
// Puma thread pool and workers, and the Sidekiq queues and jobs, over the
// process base. Both rows are optional tabs, gated on the metrics being there.
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local processLib = import 'libs/process-observ-lib/main.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-ruby',
      dashboardTitle: 'Ruby runtime',
      dashboardTags: ['ruby', 'rails', 'puma', 'sidekiq', 'runtime'],
      description: 'A Ruby service: the Puma thread pool and its request backlog, Sidekiq queues, job throughput and failures, over the process base.',
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
      workers: sig('Puma workers', 'puma_workers{%(queriesSelector)s}', 'short', desc='Puma worker processes configured.'),
      bootedWorkers: sig('Booted workers', 'puma_booted_workers{%(queriesSelector)s}', 'short', desc='Workers that finished booting. Fewer than configured means a worker is restarting or failing to boot.'),
      oldWorkers: sig('Old workers', 'puma_old_workers{%(queriesSelector)s}', 'short', desc='Workers from the previous generation still winding down after a phased restart.'),
      busyThreads: sig('Busy threads', 'puma_busy_threads{%(queriesSelector)s}', 'short', desc='Threads currently serving a request.'),
      runningThreads: sig('Running threads', 'puma_running_threads{%(queriesSelector)s}', 'short', desc='Threads alive in the pool.'),
      maxThreads: sig('Max threads', 'puma_max_threads{%(queriesSelector)s}', 'short', desc='Upper bound of the thread pool.'),
      poolCapacity: sig('Pool capacity', 'puma_thread_pool_capacity{%(queriesSelector)s}', 'short', desc='Threads still free to take a request. Zero means the next request waits.'),
      backlog: sig('Request backlog', 'puma_request_backlog{%(queriesSelector)s}', 'short', desc='Requests queued for a free thread.'),
      threadUtil: sig('Thread usage', '100 * puma_busy_threads{%(queriesSelector)s} / clamp_min(puma_max_threads{%(queriesSelector)s}, 1)', 'percent', desc='Busy threads against the pool limit.'),
      sidekiqEnqueued: sig('Enqueued jobs', 'sidekiq_stats_enqueued{%(queriesSelector)s}', 'short', desc='Jobs waiting to run across all queues.'),
      sidekiqBacklog: sig('Queue backlog', 'sidekiq_queue_backlog{%(queriesSelector)s}', 'short', '{{queue}}', desc='Jobs waiting per queue.'),
      sidekiqLatency: sig('Queue latency', 'sidekiq_queue_latency_seconds{%(queriesSelector)s}', 's', '{{queue}}', desc='Age of the oldest job in the queue, the wait a new job can expect.'),
      sidekiqJobs: sig('Jobs', 'rate(sidekiq_jobs_total{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Jobs processed per second.'),
      sidekiqFailed: sig('Failed jobs', 'rate(sidekiq_failed_jobs_total{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Jobs that raised per second.'),
      sidekiqDead: sig('Dead jobs', 'sidekiq_stats_dead_size{%(queriesSelector)s}', 'short', desc='Jobs in the dead set, out of retries and dropped.'),
      sidekiqBusy: sig('Busy workers', 'sidekiq_process_busy{%(queriesSelector)s}', 'short', desc='Sidekiq threads currently running a job.'),
      sidekiqConcurrency: sig('Concurrency', 'sidekiq_process_concurrency{%(queriesSelector)s}', 'short', desc='Sidekiq threads configured per process.'),
      sidekiqDuration: sig('Job duration', 'rate(sidekiq_job_duration_seconds_sum{%(queriesSelector)s}[$__rate_interval]) / clamp_min(rate(sidekiq_job_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]), 0.001)', 's', desc='Mean job run time.'),
    };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Puma',
        elements: {
          threads: signals.busyThreads.asTimeSeries('Threads')
                   + panel.withTargetsMixin([signals.runningThreads.asTarget(), signals.maxThreads.asTarget(), signals.poolCapacity.asTarget()]),
          threadUtil: signals.threadUtil.asTimeSeries('Thread usage'),
          backlog: signals.backlog.asTimeSeries('Request backlog'),
          workers: signals.workers.asTimeSeries('Workers')
                   + panel.withTargetsMixin([signals.bootedWorkers.asTarget(), signals.oldWorkers.asTarget()]),
        },
      } + charts,
    ], [
      alert.rule.group('ruby', [
        alert.rule.new('PumaThreadPoolSaturated',
                       '100 * puma_busy_threads' + rsBrace + ' / clamp_min(puma_max_threads' + rsBrace + ', 1) > 90', '10m', 'warning', {},
                       { summary: 'Puma on {{ $labels.instance }} has kept over 90 percent of its threads busy for 10 minutes.' }),
        alert.rule.new('PumaRequestBacklog', 'puma_request_backlog' + rsBrace + ' > 0', '10m', 'warning', {},
                       { summary: 'Puma on {{ $labels.instance }} has kept requests queued for 10 minutes.' }),
        alert.rule.new('SidekiqQueueLatencyHigh', 'sidekiq_queue_latency_seconds' + rsBrace + ' > 300', '15m', 'warning', {},
                       { summary: 'Sidekiq queue {{ $labels.queue }} has jobs waiting more than 5 minutes.' }),
        alert.rule.new('SidekiqJobsFailing', 'rate(sidekiq_failed_jobs_total' + rsBrace + '[10m]) > 0', '15m', 'warning', {},
                       { summary: 'Sidekiq jobs on {{ $labels.instance }} keep raising.' }),
        alert.rule.new('SidekiqDeadJobsGrowing', 'increase(sidekiq_stats_dead_size' + rsBrace + '[1h]) > 0', '10m', 'info', {},
                       { summary: 'Sidekiq moved jobs to the dead set on {{ $labels.instance }}; they are out of retries.' }),
      ]),
    ], [
      alert.rule.group('ruby.rules', [
        alert.rule.record('instance:puma_thread_usage:ratio',
                          'puma_busy_threads' + rsBrace + ' / clamp_min(puma_max_threads' + rsBrace + ', 1)'),
      ]),
    ], [
      {
        title: 'Sidekiq',
        width: 12,
        height: 7,
        presence: { query: 'sidekiq_process_concurrency{' + cfg.selector + '}', label: 'instance' },
        elements: {
          sidekiqBacklog: signals.sidekiqBacklog.asTimeSeries('Queue backlog')
                          + panel.withTargetsMixin([signals.sidekiqEnqueued.asTarget()]),
          sidekiqLatency: signals.sidekiqLatency.asTimeSeries('Queue latency'),
          sidekiqJobs: signals.sidekiqJobs.asTimeSeries('Jobs/s')
                       + panel.withTargetsMixin([signals.sidekiqFailed.asTarget()]),
          sidekiqBusy: signals.sidekiqBusy.asTimeSeries('Busy workers')
                       + panel.withTargetsMixin([signals.sidekiqConcurrency.asTarget()]),
          sidekiqDuration: signals.sidekiqDuration.asTimeSeries('Mean job duration'),
          sidekiqDead: signals.sidekiqDead.asTimeSeries('Dead jobs'),
        },
      },
      {
        title: 'Process',
        width: 12,
        height: 7,
        alwaysShow: true,
        elements: processLib.elements(cfg.datasource, cfg.selector, 'proc_'),
      },
    ]),
}
