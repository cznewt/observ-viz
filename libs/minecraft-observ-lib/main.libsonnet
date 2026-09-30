// observ-viz Minecraft pack (hand-written).
// Minecraft Java servers on Kubernetes (itzg/minecraft-server + a Velocity
// proxy, the minecraft-java catalog component). One board for every server of a
// network, one `server` per app.kubernetes.io/component (gamenu-lobby,
// gamenu-eggwars, gamenu-proxy, ...), whose container is `<containerPrefix><server>`.
//
// There are no Minecraft metrics: no exporter runs next to the servers. So
//   - health comes from kube-state-metrics (ready / restarts / CrashLoopBackOff)
//     and cAdvisor (CPU / memory), keyed by namespace + container;
//   - players come from the server logs in Loki:
//       Paper / Fabric / vanilla   "<name> joined the game" / "<name> left the game"
//                                  (Paper wraps the name in ANSI colour codes, and
//                                  appends "(formerly known as X)" after a rename)
//       Velocity proxy             "[connected player] <name> (/ip:port) has connected"
//                                  / "... has disconnected[: reason]"
//     joins / leaves are counted per server; "online" is the last join/leave
//     event per (server, player) inside `onlineWindow` (1 = joined, 0 = left),
//     summed. A server that dies without logging the leaves keeps its players
//     "online" until the window ages them out, and a player online for longer
//     than the window drops out early.
//   - the proxy counts every network login once; the backend servers count a
//     player again on every server switch. "Players online" sums the backends
//     (a player is on one backend at a time), so it holds with or without a proxy.
// Usage:
//   g.libs.applications.minecraft.new({ namespace: 'gedu-minecraft' }).grafana.dashboard
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
      uid: 'observ-viz-minecraft',
      dashboardTitle: 'Minecraft',
      // Workloads / Gaming
      folderPath: (import 'libs/common-lib/folders.libsonnet').gaming,
      dashboardTags: ['minecraft', 'game', 'app-level'],
      links: [
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      primaryTabTitle: 'Overview',
      datasource: '${datasource}',
      lokiDatasource: true,
      // the servers: pods labelled app.kubernetes.io/part-of=<partOf>, one
      // server per app.kubernetes.io/component, container <containerPrefix><component>
      partOf: 'minecraft-java',
      containerPrefix: 'minecraft-java-',
      // components that are a proxy (Velocity / BungeeCord), not a game server
      proxyMatcher: '.*proxy',
      groupVar: 'cluster',
      varMetric: 'kube_pod_labels{label_app_kubernetes_io_part_of="' + self.partOf + '"}',
      selector: 'cluster=~"$cluster", namespace=~"$namespace", container=~"' + self.containerPrefix + '$server"',
      logsSelector: self.selector,
      cadvisorSelector: 'job=~".*cadvisor"',
      ksmSelector: 'job=~".*kube-state-metrics"',
      // how far back a join/leave event still decides whether a player is online
      onlineWindow: '12h',
      // log lines hidden from the logs panel: the Eggwars stats autosave, the
      // itzg image helper's config copying, chunk-save chatter, blank lines and
      // the HTML body a failing analytics call dumps
      logsNoise: @'Players stats have been saved|\[mc-image-helper\]|\[ChunkHolderManager\]|^\s*$|^</?(html|head|body|hr|center)',
      // static filter for the alerting rules (no dashboard vars)
      ruleSelector: 'container=~"minecraft-java-.*"',
    } + config;

    local pre = cfg.containerPrefix;
    local labelSel(scope) = 'kube_pod_labels{' + scope + 'label_app_kubernetes_io_part_of="' + cfg.partOf + '"}';
    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local kubeVar(name, label, title, scope) =
      variable.query.new(name)
      + variable.query.withLabel(title)
      + variable.query.withLabelValues(label, labelSel(scope))
      + variable.query.withMulti()
      + variable.query.withIncludeAll()
      + allCurrent;
    local cfgVars = cfg {
      extraVariables: [
        kubeVar('namespace', 'namespace', 'Namespace', 'cluster=~"$cluster", '),
        kubeVar('server', 'label_app_kubernetes_io_component', 'Server', 'cluster=~"$cluster", namespace=~"$namespace", '),
      ],
    };

    // container -> server (the component) for legends and table rows; works in
    // PromQL and LogQL alike
    local srv(e) = 'label_replace(' + e + ', "server", "$1", "container", "' + pre + '(.*)")';
    local backends = 'container!~"' + pre + cfg.proxyMatcher + '"';

    local sig(name, expr, unit, legend='{{server}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit)
      .filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local lsig(name, expr, unit='short', legend='{{server}}', desc='') =
      signal.new(name, 'loki', '${loki_datasource}', expr, unit)
      .filteringSelector(cfg.logsSelector).withLegendFormat(legend).withDescription(desc);

    // --- LogQL building blocks (@'' strings: no Jsonnet escapes) ---
    local joinLine = @'|~ `joined the game|\[connected player\] .* has connected`';
    local leaveLine = @'|~ `left the game|\[connected player\] .* has disconnected`';
    // one parser for both formats: `]: [ANSI]name[ (...)] joined|left` and
    // `[connected player] name (/ip:port) has connected|has disconnected`
    local eventParse =
      @'|~ `joined the game|left the game|\[connected player\] .* has (dis)?connected`'
      + @' | regexp `(?:\]: (?:\x1b\[[0-9;]*m)?|\[connected player\] )(?P<player>\w{1,16})(?: \([^)]*\))? (?P<event>joined|left|has connected|has disconnected)`'
      + ' | player != ""';
    local onlineState(stream) =
      'last_over_time(' + stream + ' ' + eventParse
      + @' | label_format online=`{{ if or (eq .event "joined") (eq .event "has connected") }}1{{ else }}0{{ end }}`'
      + ' | unwrap online [' + cfg.onlineWindow + ']) by (container, player)';
    local lastSeen(stream) =
      'max_over_time(' + stream + ' ' + eventParse
      + ' | label_format seen=`{{ __timestamp__ | unixEpoch }}` | unwrap seen [$__range]) by (container, player)';

    local signals = {
      // status (kube-state-metrics)
      containerReady: sig('Server ready',
                          'max by (server) (' + srv('kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s}') + ')',
                          'short',
                          desc='kube-state-metrics readiness of the server container. 1 = ready.'),
      serversReady: sig('Servers ready',
                        'sum(max by (container) (kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s}))',
                        'short',
                        'ready',
                        desc='Server containers currently ready.'),
      serversNotReady: sig('Servers not ready',
                           'count(max by (container) (kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s}) == 0) or vector(0)',
                           'short',
                           'not ready',
                           desc='Server containers that exist but are not ready (starting, crash-looping, failing their probe).'),
      restarts: sig('Restarts',
                    'sum by (server) (' + srv('increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[1h])') + ')',
                    'short',
                    desc='Container restarts in the trailing hour.'),
      restartsRange: sig('Restarts in range',
                         'sum(increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[$__range]))',
                         'short',
                         'restarts',
                         desc='Container restarts over the selected time range.'),
      // resources (cAdvisor)
      cpu: sig('CPU',
               'sum by (server) (' + srv('rate(container_cpu_usage_seconds_total{' + cfg.cadvisorSelector + ', %(queriesSelector)s}[$__rate_interval])') + ')',
               'short',
               desc='CPU cores used by the server container (cAdvisor). A Minecraft server is mostly one busy tick thread, so ~1 core sustained means the server is tick-bound.'),
      memory: sig('Memory',
                  'sum by (server) (' + srv('container_memory_working_set_bytes{' + cfg.cadvisorSelector + ', %(queriesSelector)s}') + ')',
                  'bytes',
                  desc='Working-set memory of the server container (cAdvisor): the JVM heap plus off-heap and native memory.'),
      // players (Loki, derived from the join / leave log lines)
      playersOnline: lsig('Players online',
                          'sum by (server) (' + srv(onlineState('{%(queriesSelector)s}')) + ')',
                          desc='Players online per server: the last join/leave line per player within ' + cfg.onlineWindow + ' (1 = joined, 0 = left), summed. The proxy row counts network logins.'),
      playersTotal: lsig('Players online (network)',
                         'sum(' + onlineState('{%(queriesSelector)s, ' + backends + '}') + ') or vector(0)',
                         'short',
                         'players',
                         desc='Players online across the selected game servers (the proxy excluded: a player sits on one backend at a time).'),
      joins: lsig('Joins',
                  'sum by (server) (' + srv('count_over_time({%(queriesSelector)s} ' + joinLine + ' [$__auto])') + ')',
                  desc='Player joins per server (backend "joined the game", proxy "has connected"). A server switch through the proxy is a leave on one backend and a join on the next.'),
      leaves: lsig('Leaves',
                   'sum by (server) (' + srv('count_over_time({%(queriesSelector)s} ' + leaveLine + ' [$__auto])') + ')',
                   desc='Player leaves per server (backend "left the game", proxy "has disconnected").'),
      joinsRange: lsig('Joins in range',
                       'sum(count_over_time({%(queriesSelector)s, ' + backends + '} ' + joinLine + ' [$__range])) or vector(0)',
                       'short',
                       'joins',
                       desc='Player joins across the selected game servers over the time range (server switches included).'),
      loginsRange: lsig('Network logins in range',
                        'sum(count_over_time({%(queriesSelector)s, container=~"' + pre + cfg.proxyMatcher + '"} ' + joinLine + ' [$__range])) or vector(0)',
                        'short',
                        'logins',
                        desc='Logins through the proxy over the time range: one per player session on the network.'),
      // logs
      problems: lsig('Warnings and errors',
                     'sum by (server) (' + srv('count_over_time({%(queriesSelector)s} |~ `(?:[ /])(?:WARN|ERROR)\\]` [$__auto])') + ')',
                     desc='WARN / ERROR log lines per server.'),
      logs: signal.new('Server logs', 'loki', '${loki_datasource}', '{%(queriesSelector)s} !~ `' + cfg.logsNoise + '`', 'short')
            .filteringSelector(cfg.logsSelector)
            .withDescription('Server container logs, minus the stats-autosave / config-copy / chunk-save noise.'),
      events: signal.new('Join / leave events', 'loki', '${loki_datasource}', '{%(queriesSelector)s} ' + @'|~ `joined the game|left the game|\[connected player\] .* has (dis)?connected`', 'short')
              .filteringSelector(cfg.logsSelector)
              .withDescription('The join / leave lines the player panels count.'),
    };

    local readyMap = panel.stat.withMappings([{ type: 'value', options: {
      '0': { text: 'NOT READY', color: 'red', index: 0 },
      '1': { text: 'READY', color: 'green', index: 1 },
    } }]);
    local redAbove(v) = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: v }]);
    local bars = panel.timeSeries.withFieldConfigDefaults({ custom+: { drawStyle: 'bars', fillOpacity: 80, lineWidth: 1, stacking: { mode: 'normal', group: 'A' } } });

    // instant table queries
    local ptq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ltq(expr) =
      query.loki.new('${loki_datasource}', expr)
      + { spec+: { query+: { spec+: { queryType: 'instant' } } } };
    local tpl(e) = e % { queriesSelector: cfg.selector, filteringSelector: cfg.selector };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };

    // Overview: one row per server - ready, restarts, CPU, memory, joins, online
    local serversTable =
      panel.table.new('Servers')
      + panel.withDescription('One row per server: readiness and restarts (kube-state-metrics), CPU and memory (cAdvisor), joins over the range and players online (from the logs).')
      + panel.table.withTargets([
        ptq(tpl('max by (server) (' + srv('kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s}') + ')')),  // A ready
        ptq(tpl('sum by (server) (' + srv('increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[$__range])') + ')')),  // B restarts
        ptq(tpl('sum by (server) (' + srv('rate(container_cpu_usage_seconds_total{' + cfg.cadvisorSelector + ', %(queriesSelector)s}[5m])') + ')')),  // C cpu
        ptq(tpl('sum by (server) (' + srv('container_memory_working_set_bytes{' + cfg.cadvisorSelector + ', %(queriesSelector)s}') + ')')),  // D memory
        ltq(tpl('sum by (server) (' + srv('count_over_time({%(queriesSelector)s} ' + joinLine + ' [$__range])') + ')')),  // E joins
        ltq(tpl('sum by (server) (' + srv(onlineState('{%(queriesSelector)s}')) + ')')),  // F online
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields', options: { mode: 'columns' } },
        { id: 'filterFieldsByName', options: { include: { pattern: '^(server|Value.*)$' } } },
        { id: 'joinByField', options: { byField: 'server', mode: 'outer' } },
        { id: 'organize', options: {
          indexByName: { server: 0, 'Value #A': 1, 'Value #F': 2, 'Value #E': 3, 'Value #B': 4, 'Value #C': 5, 'Value #D': 6 },
          renameByName: { server: 'Server', 'Value #A': 'Ready', 'Value #B': 'Restarts', 'Value #C': 'CPU', 'Value #D': 'Memory', 'Value #E': 'Joins', 'Value #F': 'Online' },
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
        ov('CPU', [{ id: 'unit', value: 'short' }, { id: 'decimals', value: 2 }]),
        ov('Memory', [{ id: 'unit', value: 'bytes' }]),
        ov('Joins|Online', [{ id: 'decimals', value: 0 }]),
      ]);

    // Players: one row per (player, server) - joins in the range, online now, last seen
    local playersTable =
      panel.table.new('Players')
      + panel.withDescription('Every player seen in the range, per server: joins, whether the last join/leave line says online, and when that line was logged.')
      + panel.table.withTargets([
        ltq(tpl('sum by (server, player) (' + srv('count_over_time({%(queriesSelector)s} ' + eventParse + ' | event=~"joined|has connected" [$__range])') + ')')),  // A joins
        ltq(tpl('sum by (server, player) (' + srv(onlineState('{%(queriesSelector)s}')) + ')')),  // B online
        // no outer `max by (server, player)`: Loki pushes it into max_over_time
        // and drops the label_replace'd server label
        ltq(tpl(srv(lastSeen('{%(queriesSelector)s}')) + ' * 1000')),  // C last seen (ms)
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields', options: { mode: 'columns' } },
        { id: 'filterFieldsByName', options: { include: { pattern: '^(server|player|Value.*)$' } } },
        { id: 'merge' },
        { id: 'organize', options: {
          indexByName: { player: 0, server: 1, 'Value #B': 2, 'Value #A': 3, 'Value #C': 4 },
          renameByName: { player: 'Player', server: 'Server', 'Value #A': 'Joins', 'Value #B': 'Online', 'Value #C': 'Last seen' },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Last seen', desc: true }] } },
      ])
      + panel.table.withOverrides([
        ov('Online', [
          { id: 'mappings', value: [{ type: 'value', options: { '1': { text: 'online', color: 'green', index: 0 }, '0': { text: 'offline', color: 'text', index: 1 } } }] },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ]),
        ov('Joins', [{ id: 'decimals', value: 0 }]),
        ov('Last seen', [{ id: 'unit', value: 'dateTimeFromNow' }]),
      ]);

    local logsPanel(s) =
      panel.logs.new(s._name)
      + panel.withDescription(s._description)
      + panel.logs.withTargets([s.asTarget()]);

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsWith(m) = '{' + std.join(', ', std.prune([if cfg.ruleSelector != '' then cfg.ruleSelector else null, m])) + '}';
    local by = 'max by (cluster, namespace, container)';

    // annotation toggles: firing alerts on; server pod / container starts and
    // restarts off until wanted (a pod is named after its server container)
    local podSel = 'cluster=~"$cluster", namespace=~"$namespace", pod=~"' + pre + '$server-.*"';
    local annList =
      annotations.alert.bySeverity(cfg.datasource, 'namespace=~"$namespace"')
      + [
        annotations.restart.newAt('Pod starts', annotations.restart.kubePodStart(cfg.datasource, podSel), ['namespace', 'node'], '{{pod}} started on {{node}}')
        + annotations.base.asToggle(false),
        annotations.restart.newAt('Server starts', annotations.restart.kubeContainerStart(cfg.datasource, cfg.selector), ['namespace', 'pod'], '{{container}} started')
        + annotations.base.asToggle(false),
        annotations.restart.new('Server restarts', annotations.restart.kubeContainer(cfg.datasource, cfg.selector), ['namespace', 'pod', 'container'])
        + annotations.base.withTitleFormat('{{container}} restarted')
        + annotations.base.asToggle(false),
      ];

    local built = pack.build(cfgVars, signals, [
      {
        title: 'Status',
        width: 4,
        height: 5,
        elements: {
          s1_ready: signals.serversReady.asStat('Servers ready'),
          s2_notready: signals.serversNotReady.asStat('Servers not ready') + redAbove(1),
          s3_players: signals.playersTotal.asStat('Players online'),
          s4_logins: signals.loginsRange.asStat('Network logins in range'),
          s5_joins: signals.joinsRange.asStat('Server joins in range'),
          s6_restarts: signals.restartsRange.asStat('Restarts in range') + redAbove(1),
        },
      },
      {
        title: 'Servers',
        width: 24,
        height: 10,
        elements: {
          t1_servers: serversTable,
        },
      },
    ], [
      alert.rule.group('minecraft', [
        alert.rule.new(
          'MinecraftServerDown',
          by + ' (kube_pod_container_status_ready' + rs + ') == 0',
          '5m',
          'critical',
          {},
          {
            summary: 'Minecraft server is down.',
            description: 'Minecraft server {{ $labels.container }} in {{ $labels.namespace }} ({{ $labels.cluster }}) has not been ready for 5 minutes. Players cannot join it; behind a proxy, sends to it fail.',
          }
        ),
        alert.rule.new(
          'MinecraftServerCrashLooping',
          '(sum by (cluster, namespace, container) (increase(kube_pod_container_status_restarts_total' + rs + '[30m])) >= 2)'
          + ' or (' + by + ' (kube_pod_container_status_waiting_reason' + rsWith('reason="CrashLoopBackOff"') + ') == 1)',
          '5m',
          'warning',
          {},
          {
            summary: 'Minecraft server is restarting repeatedly.',
            description: 'Minecraft server {{ $labels.container }} in {{ $labels.namespace }} ({{ $labels.cluster }}) restarted at least twice in the last 30 minutes, or is in CrashLoopBackOff; every restart kicks the players on it.',
          }
        ),
      ]),
    ], [], [
      {
        title: 'Players',
        alwaysShow: true,
        groups: [
          {
            title: 'Online',
            width: 12,
            height: 8,
            elements: {
              p1_online: signals.playersOnline.asTimeSeries('Players online per server'),
              p2_total: signals.playersTotal.asTimeSeries('Players online (game servers)'),
            },
          },
          {
            title: 'Joins and leaves',
            width: 12,
            height: 8,
            elements: {
              p3_joins: signals.joins.asTimeSeries('Joins') + bars,
              p4_leaves: signals.leaves.asTimeSeries('Leaves') + bars,
            },
          },
          {
            title: 'Who',
            width: 12,
            height: 12,
            elements: {
              p5_players: playersTable,
              p6_events: logsPanel(signals.events),
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
          r4_ready: signals.containerReady.asTimeSeries('Server ready'),
        },
      },
      {
        title: 'Logs',
        alwaysShow: true,
        groups: [
          {
            title: 'Problems',
            width: 24,
            height: 7,
            elements: {
              l1_problems: signals.problems.asTimeSeries('Warnings and errors') + bars,
            },
          },
          {
            title: 'Logs',
            width: 24,
            height: 14,
            elements: {
              l2_logs: logsPanel(signals.logs),
            },
          },
        ],
      },
    ]);
    built {
      grafana+: { dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList) },
    },
}
