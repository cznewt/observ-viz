// observ-viz Pangolin pack (hand-written).
// Pangolin is a self-hosted tunnelled reverse proxy: the Pangolin server (+
// Gerbil WireGuard gateway + Traefik) runs on a public VPS, and a Newt client
// in each private site dials out to it and proxies the published resources
// (TCP/UDP targets) back into the site. This board watches the Newt side, one
// or more newt pods per cluster.
//
// What it is built on:
//   - kube-state-metrics (ready / restarts / CrashLoopBackOff) and cAdvisor
//     (CPU / memory / network) for the newt containers, per cluster;
//   - the Newt logs in Loki (`INFO: 2026/09/30 07:24:18 <message>`), from which
//     the tunnel events are counted:
//       connected        "Tunnel connection to server established successfully!"
//       websocket        "Websocket connected"                    (control channel up)
//       connecting       "Connecting to endpoint: <host>"
//       lost             "Connection to server lost after N failures"
//       auth failed      "Failed to connect: ..."                 (token / TLS errors)
//       exits            "Exiting..."                             (process shutdown)
//       target errors    "Error connecting to target: ..."        (a proxied service refuses)
//       health failed    "Target N: health check failed: ..."
//   - optionally Newt's own OpenTelemetry metrics (newt >= 1.8: `newt_*` on
//     /metrics, off by default). The "Newt metrics" tab shows only where
//     newt_build_info exists. Enable with
//       NEWT_METRICS_PROMETHEUS_ENABLED=true  NEWT_ADMIN_ADDR=0.0.0.0:2112
//     (the default admin address is 127.0.0.1:2112, not scrapeable) and scrape
//     :2112/metrics.
// Two newt replicas sharing one site ID keep kicking each other off the
// server: the "Exits" and "Tunnel connects" rates climb together.
// Usage:
//   g.libs.networking.pangolin.new({ containerMatcher: 'newt' }).grafana.dashboard
local dashboard = import 'custom/dashboard.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
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
    local cfg = {
      uid: 'observ-viz-pangolin',
      dashboardTitle: 'Pangolin',
      // Platform / Ingress
      folderPath: (import 'libs/common-lib/folders.libsonnet').ingress,
      dashboardTags: ['pangolin', 'newt', 'tunnel', 'ingress', 'cluster-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      primaryTabTitle: 'Overview',
      datasource: '${datasource}',
      lokiDatasource: true,
      // the Newt client container; a regex over the `container` label
      containerMatcher: 'newt',
      groupVar: 'cluster',
      varMetric: 'kube_pod_container_status_ready{container=~"' + self.containerMatcher + '"}',
      selector: 'cluster=~"$cluster", namespace=~"$namespace", container=~"' + self.containerMatcher + '"',
      logsSelector: self.selector,
      // Newt's own metrics (newt_*) carry no container label - they are scraped
      // with whatever the scrape job attaches (cluster / namespace / pod)
      newtSelector: 'cluster=~"$cluster", namespace=~"$namespace"',
      cadvisorSelector: 'job=~".*cadvisor"',
      ksmSelector: 'job=~".*kube-state-metrics"',
      // log lines hidden from the logs panel: one "Started tcp proxy" per
      // resource on every (re)connect, the update-available banner, and the
      // per-connect ICMP warm-up pings
      logsNoise: @'Started tcp proxy to|[╔╚║╠]|Ping attempt [0-9]+ failed|Initial reliable ping failed|Failed to remove health file',
      // static filter for the alerting rules (no dashboard vars)
      ruleSelector: 'container="newt"',
    } + config;

    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local cfgVars = cfg {
      extraVariables: [
        variable.query.new('namespace')
        + variable.query.withLabel('Namespace')
        + variable.query.withLabelValues('namespace', 'kube_pod_container_status_ready{cluster=~"$cluster", container=~"' + cfg.containerMatcher + '"}')
        + variable.query.withMulti()
        + variable.query.withIncludeAll()
        + allCurrent,
      ],
    };

    local legend = '{{cluster}} / {{namespace}}';
    local sig(name, expr, unit, lg=legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit)
      .filteringSelector(cfg.selector).withLegendFormat(lg).withDescription(desc);
    local nsig(name, expr, unit, lg=legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit)
      .filteringSelector(cfg.newtSelector).withLegendFormat(lg).withDescription(desc);
    local lsig(name, expr, lg=legend, desc='') =
      signal.new(name, 'loki', '${loki_datasource}', expr, 'short')
      .filteringSelector(cfg.logsSelector).withLegendFormat(lg).withDescription(desc);
    // count of matching log lines per cluster / namespace
    local lcount(filter, range='$__auto') =
      'sum by (cluster, namespace) (count_over_time({%(queriesSelector)s} |~ `' + filter + '` [' + range + ']))';

    local ev = {
      connected: 'Tunnel connection to server established',
      websocket: 'Websocket connected',
      connecting: 'Connecting to endpoint',
      lost: 'Connection to server lost',
      authFailed: 'Failed to connect:',
      exits: 'Exiting\\.\\.\\.',
      targetErrors: 'Error connecting to target|Error accepting TCP connection',
      healthFailed: 'health check failed',
      problems: '^(ERROR|FATAL)',
    };

    local signals = {
      // status (kube-state-metrics)
      ready: sig('Ready',
                 'max by (cluster, namespace, pod) (kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s})',
                 'short',
                 '{{cluster}} / {{namespace}} / {{pod}}',
                 desc='kube-state-metrics readiness of each newt container. 1 = ready.'),
      readyPerCluster: sig('Ready newt pods',
                           'sum by (cluster) (kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s})',
                           'short',
                           '{{cluster}}',
                           desc='Ready newt containers per cluster. 0 = the cluster has no tunnel: every resource Pangolin publishes from it is down.'),
      readyTotal: sig('Newt ready',
                      'sum(kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s})',
                      'short',
                      'ready',
                      desc='Ready newt containers across the selected clusters.'),
      notReady: sig('Newt not ready',
                    'count(kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s} == 0) or vector(0)',
                    'short',
                    'not ready',
                    desc='Newt containers that exist but are not ready.'),
      restarts: sig('Restarts',
                    'sum by (cluster, namespace, pod) (increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[1h]))',
                    'short',
                    '{{cluster}} / {{namespace}} / {{pod}}',
                    desc='Container restarts in the trailing hour.'),
      restartsRange: sig('Restarts in range',
                         'sum(increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[$__range]))',
                         'short',
                         'restarts',
                         desc='Container restarts over the selected time range.'),
      // resources (cAdvisor)
      cpu: sig('CPU',
               'sum by (cluster, namespace, pod) (rate(container_cpu_usage_seconds_total{' + cfg.cadvisorSelector + ', %(queriesSelector)s}[$__rate_interval]))',
               'short',
               '{{cluster}} / {{namespace}} / {{pod}}',
               desc='CPU cores used by the newt container (cAdvisor). Newt proxies every tunnelled byte in user space, so CPU tracks traffic.'),
      memory: sig('Memory',
                  'sum by (cluster, namespace, pod) (container_memory_working_set_bytes{' + cfg.cadvisorSelector + ', %(queriesSelector)s})',
                  'bytes',
                  '{{cluster}} / {{namespace}} / {{pod}}',
                  desc='Working-set memory of the newt container (cAdvisor).'),
      // tunnel events (Loki)
      connects: lsig('Tunnel connects',
                     lcount(ev.connected),
                     desc='"Tunnel connection to server established": the WireGuard tunnel to the Pangolin server came up. More than one per newt start means it is reconnecting.'),
      websocket: lsig('Websocket connects',
                      lcount(ev.websocket),
                      desc='"Websocket connected": the control channel to the Pangolin server came up.'),
      connecting: lsig('Connect attempts',
                       lcount(ev.connecting),
                       desc='"Connecting to endpoint": a tunnel connect attempt.'),
      lost: lsig('Connection lost',
                 lcount(ev.lost),
                 desc='"Connection to server lost after N failures": the tunnel went down; newt keeps retrying.'),
      authFailed: lsig('Auth / TLS failures',
                       lcount(ev.authFailed),
                       desc='"Failed to connect": getting a token from the Pangolin server failed (bad credentials, TLS certificate, server unreachable).'),
      exits: lsig('Exits',
                  lcount(ev.exits),
                  desc='"Exiting...": the newt process shut down (restart, eviction, or the server replacing this client).'),
      targetErrors: lsig('Target errors',
                         lcount(ev.targetErrors),
                         desc='"Error connecting to target": a published resource refused or timed out when newt proxied a connection to it. The tunnel is fine; the service behind it is not.'),
      healthFailed: lsig('Target health check failures',
                         lcount(ev.healthFailed),
                         desc='"Target N: health check failed": Pangolin health checks newt runs against the targets.'),
      problems: lsig('Errors',
                     lcount(ev.problems),
                     desc='ERROR / FATAL log lines.'),
      connectsRange: lsig('Tunnel connects in range',
                          'sum(count_over_time({%(queriesSelector)s} |~ `' + ev.connected + '` [$__range])) or vector(0)',
                          'connects',
                          desc='Tunnel connects over the time range, all selected newt pods. One per pod start is normal.'),
      lostRange: lsig('Connection lost in range',
                      'sum(count_over_time({%(queriesSelector)s} |~ `' + ev.lost + '|' + ev.authFailed + '` [$__range])) or vector(0)',
                      'lost',
                      desc='Lost tunnels and failed connects over the time range.'),
      targetErrorsRange: lsig('Target errors in range',
                              'sum(count_over_time({%(queriesSelector)s} |~ `' + ev.targetErrors + '` [$__range])) or vector(0)',
                              'errors',
                              desc='Proxied connections that newt could not open to the target service, over the time range.'),
      failingTargets: lsig('Failing targets',
                           'topk(20, sum by (cluster, target) (count_over_time({%(queriesSelector)s} |= `Error connecting to target` | regexp `dial tcp (?P<target>[^:]+:[0-9]+)` | target != "" [$__range])))',
                           '{{cluster}} {{target}}',
                           desc='Target addresses newt failed to reach, by count over the range (ClusterIP:port - map it to a Service).'),
      logs: signal.new('Newt logs', 'loki', '${loki_datasource}', '{%(queriesSelector)s} !~ `' + cfg.logsNoise + '`', 'short')
            .filteringSelector(cfg.logsSelector)
            .withDescription('Newt container logs, minus the per-resource "Started tcp proxy" lines, the update banner and the ICMP warm-up pings.'),
      tunnelLogs: signal.new('Tunnel events',
                             'loki',
                             '${loki_datasource}',
                             '{%(queriesSelector)s} |~ `' + std.join('|', [ev.connected, ev.websocket, ev.lost, ev.authFailed, ev.exits, 'Newt version']) + '`',
                             'short')
                  .filteringSelector(cfg.logsSelector)
                  .withDescription('The tunnel lifecycle lines only: starts, connects, losses, failures, exits.'),

      // Newt's own metrics (optional; see the header)
      wsConnected: nsig('Websocket connected',
                        'max by (cluster, namespace, pod) (newt_websocket_connected{%(queriesSelector)s})',
                        'short',
                        '{{cluster}} / {{namespace}} / {{pod}}',
                        desc='newt_websocket_connected: control channel to the Pangolin server, 1 = connected.'),
      tunnelSessions: nsig('Tunnel sessions',
                           'sum by (cluster, namespace, pod) (newt_tunnel_sessions{%(queriesSelector)s})',
                           'short',
                           '{{cluster}} / {{namespace}} / {{pod}}',
                           desc='newt_tunnel_sessions: active tunnel sessions.'),
      tunnelBytes: nsig('Tunnel traffic',
                        'sum by (cluster, direction) (rate(newt_tunnel_bytes_total{%(queriesSelector)s}[$__rate_interval]))',
                        'Bps',
                        '{{cluster}} {{direction}}',
                        desc='newt_tunnel_bytes_total: bytes through the tunnels, per direction.'),
      proxyConns: nsig('Proxy active connections',
                       'sum by (cluster, protocol) (newt_proxy_active_connections{%(queriesSelector)s})',
                       'short',
                       '{{cluster}} {{protocol}}',
                       desc='newt_proxy_active_connections: open proxied connections per protocol.'),
      tunnelLatency: nsig('Tunnel latency p95',
                          'histogram_quantile(0.95, sum by (cluster, le) (rate(newt_tunnel_latency_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))',
                          's',
                          '{{cluster}}',
                          desc='newt_tunnel_latency_seconds: 95th percentile tunnel latency.'),
      connErrors: nsig('Connection errors',
                       'sum by (cluster, error_type) (rate(newt_connection_errors_total{%(queriesSelector)s}[$__rate_interval]))',
                       'short',
                       '{{cluster}} {{error_type}}',
                       desc='newt_connection_errors_total: connection errors per type.'),
      wsReconnects: nsig('Reconnects',
                         'sum by (cluster, reason) (rate(newt_websocket_reconnects_total{%(queriesSelector)s}[$__rate_interval]) + rate(newt_tunnel_reconnects_total{%(queriesSelector)s}[$__rate_interval]))',
                         'short',
                         '{{cluster}} {{reason}}',
                         desc='newt_websocket_reconnects_total + newt_tunnel_reconnects_total: reconnects per reason.'),
      proxyDrops: nsig('Proxy drops',
                       'sum by (cluster, protocol) (rate(newt_proxy_drops_total{%(queriesSelector)s}[$__rate_interval]))',
                       'short',
                       '{{cluster}} {{protocol}}',
                       desc='newt_proxy_drops_total: proxied writes dropped on errors.'),
    };

    local readyMap = panel.stat.withMappings([{ type: 'value', options: {
      '0': { text: 'DOWN', color: 'red', index: 0 },
    } }]);
    local redBelow(v) = panel.stat.withThresholds([{ color: 'red', value: null }, { color: 'green', value: v }]);
    local redAbove(v) = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: v }]);
    local bars = panel.timeSeries.withFieldConfigDefaults({ custom+: { drawStyle: 'bars', fillOpacity: 80, lineWidth: 1, stacking: { mode: 'normal', group: 'A' } } });
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };

    // one row per newt pod: ready, restarts, CPU, memory, tunnel connects, target errors
    local ptq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local tpl(e) = e % { queriesSelector: cfg.selector, filteringSelector: cfg.selector };
    local podTable =
      panel.table.new('Newt pods')
      + panel.withDescription('One row per newt pod: readiness, restarts over the range, CPU and memory.')
      + panel.table.withTargets([
        ptq(tpl('max by (cluster, namespace, pod) (kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s})')),  // A
        ptq(tpl('sum by (cluster, namespace, pod) (increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[$__range]))')),  // B
        ptq(tpl('max by (cluster, namespace, pod) (kube_pod_container_status_waiting_reason{' + cfg.ksmSelector + ', %(queriesSelector)s} == 1)')),  // C: waiting (with reason below)
        ptq(tpl('sum by (cluster, namespace, pod) (rate(container_cpu_usage_seconds_total{' + cfg.cadvisorSelector + ', %(queriesSelector)s}[5m]))')),  // D
        ptq(tpl('sum by (cluster, namespace, pod) (container_memory_working_set_bytes{' + cfg.cadvisorSelector + ', %(queriesSelector)s})')),  // E
      ])
      + panel.table.withTransformations([
        { id: 'joinByField', options: { byField: 'pod', mode: 'outer' } },
        { id: 'filterFieldsByName', options: { include: { pattern: '^(pod|cluster|namespace|Value.*)$' } } },
        { id: 'organize', options: {
          excludeByName: { 'Value #C': true },
          indexByName: { cluster: 0, namespace: 1, pod: 2, 'Value #A': 3, 'Value #B': 4, 'Value #D': 5, 'Value #E': 6 },
          renameByName: { cluster: 'Cluster', namespace: 'Namespace', pod: 'Pod', 'Value #A': 'Ready', 'Value #B': 'Restarts', 'Value #D': 'CPU', 'Value #E': 'Memory' },
        } },
      ])
      + panel.table.withOverrides([
        ov('Ready', [
          { id: 'mappings', value: [{ type: 'value', options: { '1': { text: 'READY', color: 'green', index: 0 }, '0': { text: 'NOT READY', color: 'red', index: 1 } } }] },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ]),
        ov('Restarts', [
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: null }, { color: 'red', value: 1 }] } },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
          { id: 'decimals', value: 0 },
        ]),
        ov('CPU', [{ id: 'unit', value: 'short' }, { id: 'decimals', value: 3 }]),
        ov('Memory', [{ id: 'unit', value: 'bytes' }]),
      ]);

    local logsPanel(s) =
      panel.logs.new(s._name)
      + panel.withDescription(s._description)
      + panel.logs.withTargets([s.asTarget()]);

    // failing targets as a bar gauge table (instant, over the range)
    local failingTargets =
      panel.table.new('Failing targets')
      + panel.withDescription(signals.failingTargets._description)
      + panel.table.withTargets([
        query.loki.new('${loki_datasource}', tpl(signals.failingTargets._expr))
        + { spec+: { query+: { spec+: { queryType: 'instant' } } } },
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields', options: { mode: 'columns' } },
        { id: 'filterFieldsByName', options: { include: { pattern: '^(cluster|target|Value.*)$' } } },
        { id: 'organize', options: { renameByName: { cluster: 'Cluster', target: 'Target', Value: 'Errors', 'Value #A': 'Errors' } } },
        { id: 'sortBy', options: { sort: [{ field: 'Errors', desc: true }] } },
      ]);

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsWith(m) = '{' + std.join(', ', std.prune([if cfg.ruleSelector != '' then cfg.ruleSelector else null, m])) + '}';

    local podSel = 'cluster=~"$cluster", namespace=~"$namespace", container=~"' + cfg.containerMatcher + '"';
    local annList =
      annotations.alert.bySeverity(cfg.datasource, 'alertname=~"PangolinNewt.*", cluster=~"$cluster"')
      + [
        annotations.restart.newAt('Newt starts', annotations.restart.kubeContainerStart(cfg.datasource, podSel), ['cluster', 'namespace', 'pod'], '{{pod}} started')
        + annotations.base.asToggle(false),
        annotations.restart.new('Newt restarts', annotations.restart.kubeContainer(cfg.datasource, podSel), ['cluster', 'namespace', 'pod'])
        + annotations.base.withTitleFormat('{{pod}} restarted')
        + annotations.base.asToggle(false),
      ];

    local built = pack.build(cfgVars, signals, [
      {
        title: 'Status',
        width: 4,
        height: 5,
        elements: {
          s1_ready: signals.readyTotal.asStat('Newt ready') + redBelow(1),
          s2_notready: signals.notReady.asStat('Newt not ready') + redAbove(1),
          s3_restarts: signals.restartsRange.asStat('Restarts in range') + redAbove(1),
          s4_connects: signals.connectsRange.asStat('Tunnel connects in range'),
          s5_lost: signals.lostRange.asStat('Lost / failed connects in range') + redAbove(1),
          s6_targets: signals.targetErrorsRange.asStat('Target errors in range'),
        },
      },
      {
        title: 'Clusters',
        width: 12,
        height: 8,
        elements: {
          c1_perCluster: signals.readyPerCluster.asTimeSeries('Ready newt pods per cluster'),
          c2_pods: podTable,
        },
      },
    ], [
      alert.rule.group('pangolin-newt', [
        alert.rule.new(
          'PangolinNewtDown',
          // a cluster whose newt Deployment is gone entirely has no series and
          // stays silent: which clusters should run newt is not in the metrics
          'sum by (cluster) (kube_pod_container_status_ready' + rs + ') == 0',
          '5m',
          'critical',
          {},
          {
            summary: 'Pangolin Newt tunnel is down in a cluster.',
            description: 'Cluster {{ $labels.cluster }} has had no ready Newt container for 5 minutes. Every resource Pangolin publishes from it is unreachable from the internet.',
          }
        ),
        alert.rule.new(
          'PangolinNewtCrashLooping',
          '(sum by (cluster, namespace, pod) (increase(kube_pod_container_status_restarts_total' + rs + '[30m])) >= 2)'
          + ' or (max by (cluster, namespace, pod) (kube_pod_container_status_waiting_reason' + rsWith('reason="CrashLoopBackOff"') + ') == 1)',
          '10m',
          'warning',
          {},
          {
            summary: 'Pangolin Newt is restarting repeatedly.',
            description: 'Newt pod {{ $labels.pod }} in {{ $labels.namespace }} ({{ $labels.cluster }}) restarted at least twice in 30 minutes or is in CrashLoopBackOff. Each restart drops the tunnel; two newt pods sharing one site ID replace each other on the server and loop like this.',
          }
        ),
      ]),
    ], [], [
      {
        title: 'Tunnel',
        alwaysShow: true,
        groups: [
          {
            title: 'Connection events',
            width: 12,
            height: 8,
            elements: {
              t1_connects: signals.connects.asTimeSeries('Tunnel connects') + bars,
              t2_lost: signals.lost.asTimeSeries('Connection lost') + bars,
              t3_auth: signals.authFailed.asTimeSeries('Auth / TLS failures') + bars,
              t4_exits: signals.exits.asTimeSeries('Exits (process shutdowns)') + bars,
            },
          },
          {
            title: 'Targets',
            width: 12,
            height: 8,
            elements: {
              t5_targetErrors: signals.targetErrors.asTimeSeries('Target errors') + bars,
              t6_health: signals.healthFailed.asTimeSeries('Target health check failures') + bars,
              t7_failing: failingTargets,
              t8_errors: signals.problems.asTimeSeries('Error lines') + bars,
            },
          },
          {
            title: 'Events',
            width: 24,
            height: 12,
            elements: {
              t9_events: logsPanel(signals.tunnelLogs),
            },
          },
        ],
      },
      {
        title: 'Resources',
        alwaysShow: true,
        width: 12,
        height: 8,
        elements: {
          r1_cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          r2_memory: signals.memory.asTimeSeries('Memory working set'),
          r3_restarts: signals.restarts.asTimeSeries('Restarts / 1h'),
          r4_ready: signals.ready.asTimeSeries('Ready'),
        },
      },
      {
        title: 'Newt metrics',
        // only where newt runs with NEWT_METRICS_PROMETHEUS_ENABLED=true and is scraped
        presence: { label: '__name__', query: 'newt_build_info{' + cfg.newtSelector + '}' },
        width: 12,
        height: 8,
        elements: {
          m1_ws: signals.wsConnected.asTimeSeries('Websocket connected'),
          m2_sessions: signals.tunnelSessions.asTimeSeries('Tunnel sessions'),
          m3_bytes: signals.tunnelBytes.asTimeSeries('Tunnel traffic'),
          m4_conns: signals.proxyConns.asTimeSeries('Proxy active connections'),
          m5_latency: signals.tunnelLatency.asTimeSeries('Tunnel latency p95'),
          m6_errors: signals.connErrors.asTimeSeries('Connection errors / s'),
          m7_reconnects: signals.wsReconnects.asTimeSeries('Reconnects / s'),
          m8_drops: signals.proxyDrops.asTimeSeries('Proxy drops / s'),
        },
      },
      {
        title: 'Logs',
        alwaysShow: true,
        width: 24,
        height: 16,
        elements: {
          l1_logs: logsPanel(signals.logs),
        },
      },
    ]);
    built {
      grafana+: { dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList) },
    },
}
