// observ-viz PHP runtime pack (hand-written).
// PHP-FPM through hipages/php-fpm_exporter (phpfpm_*): the worker pool, its
// queue and the slow requests, over the process base. The pool is the thing
// that saturates in PHP, so max_children_reached and the listen queue are the
// signals that matter.
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local processLib = import 'libs/process-observ-lib/main.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-php',
      dashboardTitle: 'PHP runtime',
      dashboardTags: ['php', 'php-fpm', 'runtime'],
      description: 'PHP-FPM as the php-fpm exporter reports it: active, idle and total workers, the listen queue, slow requests and how often the pool hit max_children.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'phpfpm_up',
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
      up: sig('Pools up', 'sum(phpfpm_up{%(queriesSelector)s})', 'short', 'up', desc='PHP-FPM pools the exporter can reach.'),
      active: sig('Active processes', 'phpfpm_active_processes{%(queriesSelector)s}', 'short', desc='Workers currently serving a request.'),
      idle: sig('Idle processes', 'phpfpm_idle_processes{%(queriesSelector)s}', 'short', desc='Workers waiting for work. No idle workers means the next request queues.'),
      total: sig('Total processes', 'phpfpm_total_processes{%(queriesSelector)s}', 'short', desc='Workers the pool currently runs.'),
      maxActive: sig('Peak active processes', 'phpfpm_max_active_processes{%(queriesSelector)s}', 'short', desc='The most workers ever busy at once since the pool started.'),
      poolUtil: sig('Pool usage', '100 * phpfpm_active_processes{%(queriesSelector)s} / clamp_min(phpfpm_total_processes{%(queriesSelector)s}, 1)', 'percent', desc='Busy workers against the pool size.'),
      maxChildren: sig('max_children reached', 'increase(phpfpm_max_children_reached{%(queriesSelector)s}[$__rate_interval])', 'short', desc='Times the pool wanted another worker and was at its limit. Any value here is requests waiting on pool size.'),
      listenQueue: sig('Listen queue', 'phpfpm_listen_queue{%(queriesSelector)s}', 'short', desc='Requests waiting for a free worker right now.'),
      maxListenQueue: sig('Peak listen queue', 'phpfpm_max_listen_queue{%(queriesSelector)s}', 'short', desc='The deepest the queue has been since the pool started.'),
      listenQueueLen: sig('Listen queue limit', 'phpfpm_listen_queue_length{%(queriesSelector)s}', 'short', desc='Size of the socket backlog. A full backlog rejects connections.'),
      slowRequests: sig('Slow requests', 'increase(phpfpm_slow_requests{%(queriesSelector)s}[$__rate_interval])', 'short', desc='Requests that ran longer than request_slowlog_timeout.'),
      accepted: sig('Accepted connections', 'rate(phpfpm_accepted_connections{%(queriesSelector)s}[$__rate_interval])', 'reqps', desc='Requests per second the pool accepted.'),
      uptime: sig('Uptime', 'phpfpm_start_since{%(queriesSelector)s}', 's', desc='Time since the pool started or was reloaded.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_up: signals.up.asStat('Pools up'),
          ov2_active: signals.active.asStat('Active workers'),
          ov3_util: signals.poolUtil.asStat('Pool usage'),
          ov4_queue: signals.listenQueue.asStat('Listen queue') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 1 }]),
          ov5_slow: signals.slowRequests.asStat('Slow requests'),
          ov6_uptime: signals.uptime.asStat('Uptime'),
        },
      } + stats,
      {
        title: 'Worker pool',
        elements: {
          processes: signals.active.asTimeSeries('Workers')
                     + panel.withTargetsMixin([signals.idle.asTarget(), signals.total.asTarget(), signals.maxActive.asTarget()]),
          poolUtil: signals.poolUtil.asTimeSeries('Pool usage'),
          maxChildren: signals.maxChildren.asTimeSeries('max_children reached'),
          accepted: signals.accepted.asTimeSeries('Accepted connections/s'),
        },
      } + charts,
      {
        title: 'Queue and slow requests',
        elements: {
          listenQueue: signals.listenQueue.asTimeSeries('Listen queue')
                       + panel.withTargetsMixin([signals.maxListenQueue.asTarget(), signals.listenQueueLen.asTarget()]),
          slowRequests: signals.slowRequests.asTimeSeries('Slow requests'),
        },
      } + charts,
    ], [
      alert.rule.group('php', [
        alert.rule.new('PhpFpmDown', 'phpfpm_up' + rsBrace + ' == 0', '5m', 'critical', {},
                       { summary: 'PHP-FPM pool on {{ $labels.instance }} is unreachable.' }),
        alert.rule.new('PhpFpmMaxChildrenReached', 'increase(phpfpm_max_children_reached' + rsBrace + '[10m]) > 0', '5m', 'warning', {},
                       { summary: 'PHP-FPM pool on {{ $labels.instance }} hit max_children; requests are waiting for a worker.' }),
        alert.rule.new('PhpFpmListenQueueBacklog', 'phpfpm_listen_queue' + rsBrace + ' > 0', '10m', 'warning', {},
                       { summary: 'PHP-FPM pool on {{ $labels.instance }} has kept requests in its listen queue for 10 minutes.' }),
        alert.rule.new('PhpFpmSlowRequests', 'increase(phpfpm_slow_requests' + rsBrace + '[10m]) > 0', '10m', 'info', {},
                       { summary: 'PHP-FPM pool on {{ $labels.instance }} is logging slow requests.' }),
      ]),
    ], [
      alert.rule.group('php.rules', [
        alert.rule.record('instance:phpfpm_pool_usage:ratio',
                          'phpfpm_active_processes' + rsBrace + ' / clamp_min(phpfpm_total_processes' + rsBrace + ', 1)'),
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
