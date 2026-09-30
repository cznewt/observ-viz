// observ-viz Apache HTTP Server pack (hand-written).
// Apache httpd through apache_exporter (github.com/Lusitaniae/apache_exporter),
// which reads mod_status (/server-status?auto): requests, traffic, workers,
// the scoreboard, connections and CPU load. The exporter reports whether it
// reached Apache as apache_up, so a dead Apache behind a live exporter still
// shows up as down.
//
//   g.libs.webservers.apache.new({}).grafana.dashboard
//
// ExtendedStatus On (the default since 2.3.6) is needed for accesses, traffic,
// duration and CPU load; workers and the scoreboard come without it.
local dashboard = import 'custom/dashboard.libsonnet';
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-apache',
      dashboardTitle: 'Apache HTTP Server',
      dashboardTags: ['apache', 'httpd', 'webserver', 'cluster-level'],
      description: 'Apache HTTP Server from apache_exporter (mod_status): up, request rate and traffic, average request duration, busy and idle workers, the scoreboard by state, connections and CPU load.',
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      references: [
        { title: 'apache_exporter', url: 'https://github.com/Lusitaniae/apache_exporter', description: 'the apache_* metrics this board reads' },
        { title: 'mod_status', url: 'https://httpd.apache.org/docs/2.4/mod/mod_status.html', description: 'what the scoreboard states mean' },
      ],
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal cannot reach another component's instances where the
      // job label does not discriminate them
      selector: 'cluster=~"$cluster", job=~"$job", instance=~"$instance"',
      varLabels: ['cluster', 'instance'],
      varMetric: 'apache_up',
      // firing-alert annotations: the rules keep cluster/job/instance
      alertSelector: 'cluster=~"$cluster", job=~"$job"',
      // static label filter for the alerting/recording rules (no dashboard vars)
      ruleSelector: '',
      workerSaturation: 0.9,
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table
      overviewSignals: ['up', 'requests', 'traffic', 'workerSaturation', 'busyWorkers', 'uptime'],
      folderPath: (import 'libs/common-lib/folders.libsonnet').ingress,
    } + config;
    local rm(ms) = local f = std.filter(function(x) x != '', ms); if std.length(f) > 0 then '{' + std.join(', ', f) + '}' else '';
    local rs = rm([cfg.ruleSelector]);
    local sig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local q(metric, extra='') = metric + '{%(queriesSelector)s' + extra + '}';
    local rate(metric, extra='') = 'rate(' + q(metric, extra) + '[$__rate_interval])';
    local workers(state) = 'sum by (instance) (' + q('apache_workers', ', state="' + state + '"') + ')';

    local signals = {
      // ---- overview (per instance)
      up: sig('Up', 'min by (instance) (' + q('apache_up') + ')', 'short', '{{instance}}',
              '1 while the exporter can read mod_status; 0 when Apache is down or the status page is unreachable.'),
      requests: sig('Requests', 'sum by (instance) (' + rate('apache_accesses_total') + ')', 'reqps', '{{instance}}',
                    'Requests per second Apache served.'),
      traffic: sig('Traffic', 'sum by (instance) (' + rate('apache_sent_kilobytes_total') + ') * 1024', 'Bps', '{{instance}}',
                   'Bytes per second Apache sent.'),
      busyWorkers: sig('Busy workers', workers('busy'), 'short', 'busy {{instance}}',
                       'Workers serving a request right now.'),
      idleWorkers: sig('Idle workers', workers('idle'), 'short', 'idle {{instance}}',
                       'Workers waiting for a request.'),
      workerSaturation: sig('Worker saturation', workers('busy') + ' / clamp_min(' + workers('busy') + ' + ' + workers('idle') + ', 1)', 'percentunit', '{{instance}}',
                            'Busy workers as a share of busy plus idle. Near 1, new connections queue behind MaxRequestWorkers.'),
      uptime: sig('Uptime', 'max by (instance) (' + q('apache_uptime_seconds_total') + ')', 's', '{{instance}}',
                  'Seconds since the Apache server started.'),
      // ---- requests & traffic
      avgDuration: sig('Average request duration', 'sum by (instance) (' + rate('apache_duration_ms_total') + ') / clamp_min(sum by (instance) (' + rate('apache_accesses_total') + '), 1e-9)', 'ms', '{{instance}}',
                       'Time Apache spent per request, averaged over the interval (mod_status gives a total, not a histogram).'),
      bytesPerRequest: sig('Bytes per request', 'sum by (instance) (' + rate('apache_sent_kilobytes_total') + ') * 1024 / clamp_min(sum by (instance) (' + rate('apache_accesses_total') + '), 1e-9)', 'bytes', '{{instance}}',
                           'Average response size.'),
      cpuLoad: sig('CPU load', 'max by (instance) (' + q('apache_cpuload') + ')', 'percent', '{{instance}}',
                   'CPU load of the Apache processes as mod_status reports it (percent of one CPU).'),
      // ---- workers & scoreboard
      scoreboard: sig('Scoreboard', 'sum by (state) (' + q('apache_scoreboard', ', state!="open_slot"') + ')', 'short', '{{state}}',
                      'Worker slots by what they are doing (reply, keepalive, read, closing, logging, ...); open slots left out.'),
      openSlots: sig('Open slots', 'sum by (instance) (' + q('apache_scoreboard', ', state="open_slot"') + ')', 'short', '{{instance}}',
                     'Scoreboard slots with no process - headroom before MaxRequestWorkers.'),
      processes: sig('Processes', 'sum by (state) (' + q('apache_processes') + ')', 'short', '{{state}}',
                     'Apache child processes (all / stopping); stopping ones linger after a graceful restart.'),
      // ---- connections
      connections: sig('Connections by state', 'sum by (state) (' + q('apache_connections') + ')', 'short', '{{state}}',
                       'Connections by state (total, writing, keepalive, closing) - event MPM only.'),
      connectionsTotal: sig('Connections', 'sum by (instance) (' + q('apache_connections', ', state="total"') + ')', 'short', '{{instance}}',
                            'Open connections per instance (event MPM only).'),
    };
    local upMap = panel.stat.withMappings([{ type: 'value', options: { '0': { text: 'DOWN', color: 'red', index: 0 }, '1': { text: 'up', color: 'green', index: 1 } } }]);

    local annList =
      annotations.alert.bySeverity(cfg.datasource, cfg.alertSelector)
      + [
        // start time from uptime, as the sample saw it (rounded so scrape
        // jitter does not split one start into many markers)
        annotations.restart.newAt('Apache starts', annotations.base.target(cfg.datasource, '1000 * round(max by (cluster, job, instance) (timestamp(apache_uptime_seconds_total{' + cfg.selector + '}) - apache_uptime_seconds_total{' + cfg.selector + '}), 10)'), ['job', 'instance'], '{{instance}} started')
        + annotations.base.asToggle(false),
      ];

    local built = pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          ov1_up: signals.up.asStat('Up') + upMap,
          ov2_requests: signals.requests.asStat('Requests/s'),
          ov3_traffic: signals.traffic.asStat('Traffic'),
          ov4_avgDuration: signals.avgDuration.asStat('Avg request duration'),
          ov5_workerSaturation: signals.workerSaturation.asStat('Worker saturation')
                                + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.75 }, { color: 'red', value: cfg.workerSaturation }]),
          ov6_uptime: signals.uptime.asStat('Uptime'),
        },
      },
      {
        title: 'Requests & traffic',
        width: 12,
        height: 7,
        elements: {
          requests: signals.requests.asTimeSeries('Requests/s'),
          traffic: signals.traffic.asTimeSeries('Traffic sent'),
          avgDuration: signals.avgDuration.asTimeSeries('Average request duration'),
          bytesPerRequest: signals.bytesPerRequest.asTimeSeries('Bytes per request'),
          cpuLoad: signals.cpuLoad.asTimeSeries('CPU load'),
        },
      },
      {
        title: 'Workers',
        width: 12,
        height: 7,
        elements: {
          workers: signals.busyWorkers.asTimeSeries('Busy / idle workers')
                   + panel.withTargetsMixin([signals.idleWorkers.asTarget()]),
          workerSaturation: signals.workerSaturation.asTimeSeries('Worker saturation')
                            + panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'red', value: cfg.workerSaturation }])
                            + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } }),
          scoreboard: signals.scoreboard.asTimeSeries('Scoreboard by state'),
          openSlots: signals.openSlots.asTimeSeries('Open slots'),
          processes: signals.processes.asTimeSeries('Processes'),
        },
      },
      {
        title: 'Connections',
        width: 12,
        height: 7,
        elements: {
          connections: signals.connections.asTimeSeries('Connections by state'),
          connectionsTotal: signals.connectionsTotal.asTimeSeries('Connections per instance'),
        },
      },
    ], [
      alert.rule.group('apache', [
        alert.rule.new(
          'ApacheDown',
          'apache_up' + rs + ' == 0',
          '5m',
          'critical',
          {},
          {
            summary: 'Apache on {{ $labels.instance }} is down.',
            description: 'apache_exporter cannot read mod_status: Apache is not running, or its /server-status page is no longer reachable from the exporter.',
          }
        ),
        alert.rule.new(
          'ApacheWorkersSaturated',
          'sum by (cluster, job, instance) (apache_workers' + rm(['state="busy"', cfg.ruleSelector]) + ')'
          + ' / clamp_min(sum by (cluster, job, instance) (apache_workers' + rm(['state=~"busy|idle"', cfg.ruleSelector]) + '), 1) > ' + cfg.workerSaturation,
          '10m',
          'warning',
          {},
          {
            summary: 'Apache on {{ $labels.instance }} has more than ' + (cfg.workerSaturation * 100) + '% of its workers busy.',
            description: 'When no worker is idle, new connections wait in the listen backlog. Raise MaxRequestWorkers (and ServerLimit) or find what keeps workers busy - slow backends, keepalive.',
          }
        ),
      ]),
    ], [
      alert.rule.group('apache.rules', [
        alert.rule.record('instance:apache_accesses:rate5m', 'sum by (cluster, job, instance) (rate(apache_accesses_total' + rs + '[5m]))'),
        alert.rule.record('instance:apache_workers_busy:ratio',
                          'sum by (cluster, job, instance) (apache_workers' + rm(['state="busy"', cfg.ruleSelector]) + ')'
                          + ' / clamp_min(sum by (cluster, job, instance) (apache_workers' + rm(['state=~"busy|idle"', cfg.ruleSelector]) + '), 1)'),
      ]),
    ]);
    built {
      grafana+: { dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList) },
    },
}
