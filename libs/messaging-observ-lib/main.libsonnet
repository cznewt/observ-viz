// observ-viz messaging / background work pack (hand-written).
// The queues a service works off: Celery through danihodovic/celery-exporter
// (celery_*) and Kafka consumer groups through danielqsj/kafka_exporter
// (kafka_consumergroup_*). Both rows are gated on their metrics being there,
// so a service using one of them shows only that one.
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  elements(datasource, selector, prefix='')::
    local p = $.new({ datasource: datasource, selector: selector, docTabs: false });
    { [prefix + k]: p.grafana.elements[k] for k in std.objectFields(p.grafana.elements) },

  new(config={}):
    local cfg = {
      uid: 'observ-viz-messaging',
      dashboardTitle: 'Queues and background work',
      dashboardTags: ['messaging', 'queue', 'celery', 'kafka', 'instrumentation'],
      description: 'Work a service does off a queue: Celery task throughput, failures, runtime and queue wait, and Kafka consumer group lag. Lag and wait time are what tell you the workers are behind.',
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal (process_*, go_*) cannot reach another component's
      // instances where the job label does not discriminate them
      selector: 'job=~"$job", instance=~"$instance"',
      varLabels: ['instance'],
      varMetric: 'celery_worker_up',
      ruleSelector: '',
      legend: '{{queue_name}}{{consumergroup}}',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-instrumentation',
      folderTitle: 'Instrumentation',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      workers: sig('Workers up', 'sum(celery_worker_up{%(queriesSelector)s})', 'short', 'workers', desc='Celery workers the exporter can see.'),
      activeWorkers: sig('Active workers', 'sum(celery_active_worker_count{%(queriesSelector)s})', 'short', 'active', desc='Workers currently running a task.'),
      activeConsumers: sig('Active consumers', 'sum(celery_active_consumer_count{%(queriesSelector)s})', 'short', 'consumers', desc='Consumers attached to the broker.'),
      activeProcesses: sig('Active processes', 'sum(celery_active_process_count{%(queriesSelector)s})', 'short', 'processes', desc='Worker processes available to run tasks.'),
      queueLength: sig('Queue length', 'celery_queue_length{%(queriesSelector)s}', 'short', '{{queue_name}}', desc='Tasks waiting per queue. A queue that only grows means not enough workers.'),
      taskRuntime: sig('Task runtime p95', 'histogram_quantile(0.95, sum by (le, name) (rate(celery_task_runtime_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{name}}', desc='Slowest 5 percent of task runs, per task.'),
      queueWait: sig('Queue wait p95', 'histogram_quantile(0.95, sum by (le, queue_name) (rate(celery_task_queue_wait_time_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{queue_name}}', desc='How long a task waits before a worker picks it up.'),
      tasksSucceeded: sig('Tasks succeeded', 'sum(rate(celery_task_succeeded_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'succeeded', desc='Tasks completing per second.'),
      tasksFailed: sig('Tasks failed', 'sum by (name) (rate(celery_task_failed_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{name}}', desc='Tasks raising per second, per task.'),
      tasksRetried: sig('Tasks retried', 'sum(rate(celery_task_retried_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'retried', desc='Task retries per second.'),
      lag: sig('Consumer group lag', 'sum by (consumergroup, topic) (kafka_consumergroup_lag{%(queriesSelector)s})', 'short', '{{consumergroup}} {{topic}}', desc='Messages a consumer group is behind the log end. Rising lag means consumption is slower than production.'),
      lagSum: sig('Total lag', 'sum(kafka_consumergroup_lag{%(queriesSelector)s})', 'short', 'lag', desc='Lag across all consumer groups in scope.'),
      members: sig('Consumer group members', 'sum by (consumergroup) (kafka_consumergroup_members{%(queriesSelector)s})', 'short', '{{consumergroup}}', desc='Consumers in each group. A drop to zero means nothing is consuming.'),
      offsetRate: sig('Consumption rate', 'sum by (consumergroup, topic) (rate(kafka_consumergroup_current_offset{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{consumergroup}} {{topic}}', desc='Messages consumed per second, from the group offset advancing.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_workers: signals.workers.asStat('Workers up'),
          ov2_active: signals.activeWorkers.asStat('Active workers'),
          ov3_failed: signals.tasksFailed.asStat('Failed tasks/s') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.001 }]),
          ov4_lag: signals.lagSum.asStat('Consumer lag'),
        },
      } + stats,
      {
        title: 'Celery',
        elements: {
          queueLength: signals.queueLength.asTimeSeries('Queue length'),
          queueWait: signals.queueWait.asTimeSeries('Queue wait p95'),
          tasks: signals.tasksSucceeded.asTimeSeries('Tasks/s')
                 + panel.withTargetsMixin([signals.tasksRetried.asTarget()]),
          tasksFailed: signals.tasksFailed.asTimeSeries('Failed tasks/s by task'),
          taskRuntime: signals.taskRuntime.asTimeSeries('Task runtime p95'),
          workers: signals.activeWorkers.asTimeSeries('Workers')
                   + panel.withTargetsMixin([signals.activeConsumers.asTarget(), signals.activeProcesses.asTarget()]),
        },
      } + charts,
    ], [
      alert.rule.group('messaging', [
        alert.rule.new('CeleryWorkersDown',
                       'sum by (job) (celery_worker_up' + rsBrace + ') == 0',
                       '10m',
                       'critical',
                       {},
                       { summary: 'No Celery workers are up for {{ $labels.job }}.' }),
        alert.rule.new('CeleryQueueBacklog',
                       'celery_queue_length' + rsBrace + ' > 100',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Celery queue {{ $labels.queue_name }} has kept more than 100 tasks waiting for 15 minutes.' }),
        alert.rule.new('CeleryTasksFailing',
                       'sum by (job, name) (rate(celery_task_failed_total' + rsBrace + '[10m])) > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Celery task {{ $labels.name }} keeps failing on {{ $labels.job }}.' }),
        alert.rule.new('KafkaConsumerGroupLagGrowing',
                       'sum by (job, consumergroup, topic) (kafka_consumergroup_lag' + rsBrace + ') > 1000 and deriv(sum by (job, consumergroup, topic) (kafka_consumergroup_lag' + rsBrace + ')[15m:1m]) > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Consumer group {{ $labels.consumergroup }} is behind on {{ $labels.topic }} and falling further behind.' }),
        alert.rule.new('KafkaConsumerGroupEmpty',
                       'sum by (job, consumergroup) (kafka_consumergroup_members' + rsBrace + ') == 0',
                       '10m',
                       'critical',
                       {},
                       { summary: 'Consumer group {{ $labels.consumergroup }} has no members; nothing is consuming.' }),
      ]),
    ], [
      alert.rule.group('messaging.rules', [
        alert.rule.record('job_queue:celery_queue_length:max', 'max by (job, queue_name) (celery_queue_length' + rsBrace + ')'),
        alert.rule.record('job_group:kafka_consumergroup_lag:sum', 'sum by (job, consumergroup) (kafka_consumergroup_lag' + rsBrace + ')'),
      ]),
    ], [
      {
        title: 'Kafka consumer groups',
        width: 12,
        height: 7,
        presence: { query: 'kafka_consumergroup_lag{' + cfg.selector + '}', label: 'consumergroup' },
        elements: {
          lag: signals.lag.asTimeSeries('Consumer group lag'),
          offsetRate: signals.offsetRate.asTimeSeries('Consumption rate'),
          members: signals.members.asTimeSeries('Consumer group members'),
        },
      },
    ]),
}
