// observ-viz Pushgateway pack (hand-written).
// prometheus/pushgateway: the groups batch jobs push (push_time_seconds /
// push_failure_time_seconds, one series per group), how fresh each group is,
// the push traffic the gateway handles, and the gateway process itself.
//
// Pushed series keep their own grouping labels (job, instance, ...) when the
// gateway is scraped with honor_labels: true, as upstream recommends - so a
// group's `job` is the pushing job, not the gateway's scrape job. The groups
// are filtered by $pushed_job on cfg.pushedJobLabel (`job`; set it to
// `exported_job` when honor_labels is off), the gateway's own series by
// $job / $instance.
//
//   g.libs.monitoring.pushgateway.new({}).grafana.dashboard
//   g.libs.monitoring.pushgateway.new({ groupStaleSeconds: 7200 }).prometheus.alerts
//
// Metric names checked against pushgateway main.go, handler/metrics.go and
// storage/diskmetricstore.go (master, 2026-09).
local dashboard = import 'custom/dashboard.libsonnet';
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { query: gv.query + cv.query };

{
  new(config={}):
    local cfg0 = {
      uid: 'observ-viz-pushgateway',
      dashboardTitle: 'Pushgateway',
      dashboardTags: ['pushgateway', 'collector', 'cluster-level'],
      description: 'Prometheus Pushgateway: the groups batch jobs push and how long ago each last succeeded or failed, stale groups, push traffic (rate, errors, duration, size) and the gateway process. Groups are filtered with **Pushed job**, the gateway itself with **Job** / **Instance**.',
      references: [
        { title: 'Pushgateway', url: 'https://github.com/prometheus/pushgateway', description: 'grouping keys, push_time_seconds and honor_labels' },
        { title: 'When to use the Pushgateway', url: 'https://prometheus.io/docs/practices/pushing/', description: 'service-level batch jobs, and why a gateway never forgets a group' },
      ],
      datasource: '${datasource}',
      // the gateway's own series
      selector: 'cluster=~"$cluster", job=~"$job", instance=~"$instance"',
      varLabels: ['cluster', 'instance'],
      varMetric: 'pushgateway_build_info',
      // the pushed groups: the label that carries the pushing job
      pushedJobLabel: 'job',
      groupSelector: 'cluster=~"$cluster", ' + self.pushedJobLabel + '=~"$pushed_job"',
      alertSelector: 'cluster=~"$cluster"',
      // static label filter for the alerting/recording rules (no dashboard vars)
      ruleSelector: '',
      // a group whose last successful push is older than this is stale
      groupStaleSeconds: 3600,
      docTabs: true,
      tabbed: true,
      overviewSignals: ['pushRate', 'pushErrors', 'pushDurationP90', 'memory'],
      folderPath: (import 'libs/common-lib/folders.libsonnet').monitoringCollectors,
    } + config;
    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local cfg = cfg0 {
      extraVariables+: [
        variable.query.new('pushed_job')
        + variable.query.withLabel('Pushed job')
        + variable.query.withLabelValues(cfg0.pushedJobLabel, 'push_time_seconds{cluster=~"$cluster"}')
        + variable.query.withMulti()
        + variable.query.withIncludeAll()
        + allCurrent,
      ],
    };
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sigWith(sel) = function(name, expr, unit, legend, desc)
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(sel).withLegendFormat(legend).withDescription(desc);
    local sig = sigWith(cfg.selector);
    local grp = sigWith(cfg.groupSelector);
    local q(metric, extra='') = metric + '{%(queriesSelector)s' + extra + '}';
    local rate(metric, extra='') = 'rate(' + q(metric, extra) + '[$__rate_interval])';
    local pj = cfg.pushedJobLabel;
    local groupLegend = '{{' + pj + '}} {{instance}}';

    local signals = {
      // ---- overview (per gateway instance)
      pushRate: sig('Pushes', 'sum by (instance) (' + rate('pushgateway_http_requests_total', ', handler="push"') + ')', 'reqps', '{{instance}}',
                    'Push requests (PUT / POST) per second the gateway accepted or rejected.'),
      pushErrors: sig('Push errors', 'sum by (instance) (' + rate('pushgateway_http_requests_total', ', handler="push", code!~"2.."') + ') or vector(0)', 'reqps', '{{instance}}',
                      'Push requests answered with a non-2xx status: malformed payloads, timestamps in pushed samples, or label clashes.'),
      pushDurationP90: sig('Push duration p90', 'max by (instance) (' + q('pushgateway_http_push_duration_seconds', ', quantile="0.9"') + ')', 's', '{{instance}}',
                           '90th percentile of push request duration (summary quantile, per method).'),
      memory: sig('Resident memory', 'max by (instance) (' + q('process_resident_memory_bytes') + ')', 'bytes', '{{instance}}',
                  'Gateway RSS. Every group ever pushed stays in memory until deleted.'),
      // ---- overview stats (groups)
      groups: grp('Groups', 'count(' + q('push_time_seconds') + ')', 'short', 'groups', 'Groups the gateway holds for the selected pushed jobs.'),
      staleGroups: grp('Stale groups', 'count((time() - ' + q('push_time_seconds') + ') > ' + cfg.groupStaleSeconds + ') or vector(0)', 'short', 'stale',
                       'Groups whose last successful push is older than ' + cfg.groupStaleSeconds + 's.'),
      failingGroups: grp('Failing groups', 'count(' + q('push_failure_time_seconds') + ' > ' + q('push_time_seconds') + ') or vector(0)', 'short', 'failing',
                         'Groups whose most recent push attempt failed (failure newer than the last success).'),
      oldestPush: grp('Oldest push', 'max(time() - ' + q('push_time_seconds') + ')', 's', 'oldest', 'Age of the least recently pushed group.'),
      // ---- freshness
      groupAge: grp('Last push age', 'time() - ' + q('push_time_seconds'), 's', groupLegend,
                    'Seconds since each group was last pushed successfully. A batch job that stopped pushing shows as a line that only climbs.'),
      groupFailureAge: grp('Last failure age', 'time() - (' + q('push_failure_time_seconds') + ' > 0)', 's', groupLegend,
                           'Seconds since a push to each group last failed; groups that never failed are left out.'),
      staleTable: grp('Stale groups', '(time() - ' + q('push_time_seconds') + ') > ' + cfg.groupStaleSeconds, 's', groupLegend,
                      'Groups not pushed for more than ' + cfg.groupStaleSeconds + 's.'),
      // ---- pushes
      requestsByCode: sig('Requests by handler and status', 'sum by (handler, code) (' + rate('pushgateway_http_requests_total') + ')', 'reqps', '{{handler}} {{code}}',
                          'HTTP requests the gateway served (pushes, deletes, API, status page), excluding scrapes.'),
      pushByMethod: sig('Pushes by method', 'sum by (method) (' + rate('pushgateway_http_requests_total', ', handler="push"') + ')', 'reqps', '{{method}}',
                        'PUT replaces a whole group, POST replaces only the metric names pushed.'),
      pushDuration: sig('Push duration', 'max by (method, quantile) (' + q('pushgateway_http_push_duration_seconds') + ')', 's', '{{method}} p{{quantile}}',
                        'Push request duration quantiles (0.1 / 0.5 / 0.9) per method.'),
      pushSize: sig('Push size', 'max by (method, quantile) (' + q('pushgateway_http_push_size_bytes') + ')', 'bytes', '{{method}} p{{quantile}}',
                    'Push request body size quantiles per method.'),
      pushThroughput: sig('Push bytes', 'sum by (method) (' + rate('pushgateway_http_push_size_bytes_sum') + ')', 'Bps', '{{method}}',
                          'Bytes pushed per second.'),
      // ---- process / go
      cpu: sig('CPU', 'sum by (instance) (' + rate('process_cpu_seconds_total') + ')', 'short', '{{instance}}', 'CPU cores the gateway uses.'),
      rss: sig('Memory', 'max by (instance) (' + q('process_resident_memory_bytes') + ')', 'bytes', '{{instance}}', 'Resident set size.'),
      heap: sig('Go heap in use', 'max by (instance) (' + q('go_memstats_heap_inuse_bytes') + ')', 'bytes', '{{instance}}', 'Heap in use; grows with the number of groups and series held.'),
      goroutines: sig('Goroutines', 'max by (instance) (' + q('go_goroutines') + ')', 'short', '{{instance}}', 'Live goroutines.'),
      fds: sig('Open file descriptors', 'max by (instance) (' + q('process_open_fds') + ')', 'short', '{{instance}}', 'Open file descriptors (persistence file, connections).'),
      gcDuration: sig('GC pause', 'max by (instance) (' + q('go_gc_duration_seconds', ', quantile="1"') + ')', 's', '{{instance}}', 'Longest recent GC pause.'),
      version: sig('Version', 'max by (instance, version) (' + q('pushgateway_build_info') + ')', 'short', '{{instance}} {{version}}', 'Running Pushgateway builds.'),
    };

    local instantTable(s) = s.asTableTarget();
    local groupsTable =
      panel.table.new('Groups')
      + panel.withDescription('One row per pushed group with its grouping labels: seconds since the last successful push and since the last failed one (empty when it never failed).')
      + panel.table.withTargets([
        instantTable(grp('Last push age', 'time() - ' + q('push_time_seconds'), 's', '', '')),
        instantTable(grp('Last failure age', 'time() - (' + q('push_failure_time_seconds') + ' > 0)', 's', '', '')),
      ])
      + panel.table.withTransformations([
        { id: 'merge', options: {} },
        { id: 'organize', options: { excludeByName: { Time: true, __name__: true }, renameByName: { 'Value #A': 'Last push age', 'Value #B': 'Last failure age', [pj]: 'Pushed job' } } },
      ])
      + panel.table.withOverrides([
        { matcher: { id: 'byName', options: 'Last push age' }, properties: [
          { id: 'unit', value: 's' },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: null }, { color: 'red', value: cfg.groupStaleSeconds }] } },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ] },
        { matcher: { id: 'byName', options: 'Last failure age' }, properties: [{ id: 'unit', value: 's' }] },
      ])
      + panel.table.withOptions({ sortBy: [{ displayName: 'Last push age', desc: true }] });
    local ageTable(s, title) =
      s.asTable(title)
      + panel.table.withTransformations([
        { id: 'organize', options: { excludeByName: { Time: true, __name__: true }, renameByName: { Value: 'Age', [pj]: 'Pushed job' } } },
      ])
      + panel.table.withOptions({ sortBy: [{ displayName: 'Age', desc: true }] });

    local annList =
      annotations.alert.bySeverity(cfg.datasource, cfg.alertSelector + ', alertname=~"Pushgateway.*"')
      + [
        annotations.restart.newAt('Pushgateway starts', annotations.restart.processStart(cfg.datasource, cfg.selector), ['job', 'instance'], '{{instance}} started')
        + annotations.base.asToggle(false),
      ];

    local built = pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          ov1_groups: signals.groups.asStat('Groups'),
          ov2_stale: signals.staleGroups.asStat('Stale groups')
                     + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 1 }]),
          ov3_failing: signals.failingGroups.asStat('Failing groups')
                       + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]),
          ov4_oldest: signals.oldestPush.asStat('Oldest push')
                      + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: cfg.groupStaleSeconds }]),
          ov5_pushRate: signals.pushRate.asStat('Pushes/s'),
          ov6_pushErrors: signals.pushErrors.asStat('Push errors/s')
                          + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.001 }]),
        },
      },
      {
        title: 'Freshness',
        width: 12,
        height: 8,
        signalKeys: ['groupAge', 'groupFailureAge', 'staleTable'],
        elements: {
          fr1_groups: groupsTable,
          fr2_groupAge: signals.groupAge.asTimeSeries('Last push age by group')
                        + panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'red', value: cfg.groupStaleSeconds }])
                        + panel.timeSeries.withFieldConfigDefaults({ custom+: { thresholdsStyle: { mode: 'dashed' } } }),
          fr3_stale: ageTable(signals.staleTable, 'Stale groups'),
          fr4_failureAge: signals.groupFailureAge.asTimeSeries('Last failure age by group'),
        },
      },
      {
        title: 'Pushes',
        width: 12,
        height: 7,
        elements: {
          pushRate: signals.pushRate.asTimeSeries('Pushes/s'),
          pushErrors: signals.pushErrors.asTimeSeries('Push errors/s'),
          requestsByCode: signals.requestsByCode.asTimeSeries('Requests by handler and status'),
          pushByMethod: signals.pushByMethod.asTimeSeries('Pushes by method'),
          pushDuration: signals.pushDuration.asTimeSeries('Push duration quantiles'),
          pushSize: signals.pushSize.asTimeSeries('Push size quantiles'),
          pushThroughput: signals.pushThroughput.asTimeSeries('Push bytes/s'),
        },
      },
      {
        title: 'Process',
        width: 8,
        height: 7,
        elements: {
          cpu: signals.cpu.asTimeSeries('CPU'),
          rss: signals.rss.asTimeSeries('Resident memory'),
          heap: signals.heap.asTimeSeries('Go heap in use'),
          goroutines: signals.goroutines.asTimeSeries('Goroutines'),
          fds: signals.fds.asTimeSeries('Open file descriptors'),
          gcDuration: signals.gcDuration.asTimeSeries('GC pause (max)'),
          version: signals.version.asTable('Version')
                   + panel.table.withTransformations([
                     { id: 'organize', options: { excludeByName: { Time: true, Value: true } } },
                   ]),
        },
      },
    ], [
      alert.rule.group('pushgateway', [
        alert.rule.new(
          'PushgatewayDown',
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('pushgateway_build_info', cfg.ruleSelector),
          '5m',
          'warning',
          {},
          {
            summary: 'Pushgateway {{ $labels.instance }} is down.',
            description: 'Prometheus cannot scrape the Pushgateway, so every pushed group is missing from queries and batch-job alerts go blind. Batch jobs pushing now get connection errors.',
          }
        ),
        alert.rule.new(
          'PushgatewayGroupStale',
          '(time() - push_time_seconds' + rsBrace + ') > ' + cfg.groupStaleSeconds,
          '5m',
          'warning',
          {},
          {
            summary: 'Pushgateway group {{ $labels.' + pj + ' }} {{ $labels.instance }} has not been pushed for {{ $value | humanizeDuration }}.',
            description: 'The batch job behind this group stopped pushing. The gateway keeps serving its last values, so every metric it pushed looks current while it is not. Check the job; delete the group if it was retired.',
          }
        ),
        alert.rule.new(
          'PushgatewayPushFailures',
          'push_failure_time_seconds' + rsBrace + ' > push_time_seconds' + rsBrace,
          '5m',
          'warning',
          {},
          {
            summary: 'Pushes to group {{ $labels.' + pj + ' }} {{ $labels.instance }} are failing.',
            description: 'The latest push attempt for this group failed after the last successful one - usually a malformed payload, a sample timestamp, or a metric type clashing with what the group already holds. The gateway log has the reason.',
          }
        ),
      ]),
    ], [
      alert.rule.group('pushgateway.rules', [
        alert.rule.record('group:push_time_seconds:age_seconds', 'time() - push_time_seconds' + rsBrace),
        alert.rule.record('job:pushgateway_http_push_requests:rate5m',
                          'sum by (cluster, job, instance, code) (rate(pushgateway_http_requests_total{handler="push"' + rsComma + '}[5m]))'),
      ]),
    ]);
    built {
      grafana+: { dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList) },
    },
}
