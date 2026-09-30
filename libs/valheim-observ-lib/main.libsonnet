// observ-viz Valheim pack (hand-written).
// Valheim dedicated servers on Kubernetes (mbround18/valheim image: odin +
// huginn, exporter on :2459). One board for every server in the namespace, one
// `server` per container (valheim-prime, valheim-vanilla, ...).
//
// What is trustworthy, and what is not:
//   - huginn's valheim_online / valheim_current_player_count / version stay at
//     0 / "Unknown" when the Steam query port is not answered, and
//     valheim_sys_memory_* reads ~1024x too high. None of them is a signal here;
//     only the exporter's scrape `up` is.
//   - players come from `valheim:connections`, a Loki recording rule over the
//     server log (one sample per ~10 min, labels cluster/namespace/pod/
//     container), so the players queries bridge the gaps with last_over_time.
//   - health comes from kube-state-metrics (ready / restarts) and cAdvisor
//     (CPU / memory), keyed by the same namespace + container.
// Usage:
//   g.libs.applications.valheim.new({ namespaceMatcher: 'gedu-valheim' }).grafana.dashboard
local dashboard = import 'custom/dashboard.libsonnet';
local panel = import 'custom/panel.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { query: gv.query + cv.query };

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-valheim',
      dashboardTitle: 'Valheim',
      // Workloads / Gaming
      folderPath: (import 'libs/common-lib/folders.libsonnet').gaming,
      dashboardTags: ['valheim', 'game', 'app-level'],
      links: [
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      lokiDatasource: true,
      // the server containers; a regex over the `container` label
      containerMatcher: 'valheim-.*',
      // $cluster is the pack's group variable; $namespace / $server are built below
      groupVar: 'cluster',
      varMetric: 'kube_pod_container_status_ready',
      selector: 'cluster=~"$cluster", namespace=~"$namespace", container=~"$server"',
      // valheim:connections (Loki ruler); drop cluster here if your ruler omits it
      playersSelector: 'cluster=~"$cluster", namespace=~"$namespace", container=~"$server"',
      logsSelector: 'cluster=~"$cluster", namespace=~"$namespace", container=~"$server"',
      cadvisorSelector: 'job=~".*cadvisor"',
      ksmSelector: 'job=~".*kube-state-metrics"',
      // log lines hidden from the logs panel: odin's once-a-minute status poll
      // of the (unanswered) query port, the per-10-min connection count the
      // recording rule reads, and shader warm-up spam.
      logsNoise: 'Failed to request server information|Connections [0-9]+|[Ss]hader',
      // static filter for the alerting rules (no dashboard vars)
      ruleSelector: 'container=~"valheim-.*"',
    } + config;

    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local kubeVar(name, label, title, scope) =
      variable.query.new(name)
      + variable.query.withLabel(title)
      + variable.query.withLabelValues(label, cfg.varMetric + '{' + scope + 'container=~"' + cfg.containerMatcher + '"}')
      + variable.query.withMulti()
      + variable.query.withIncludeAll()
      + allCurrent;
    local cfgVars = cfg {
      extraVariables: [
        kubeVar('namespace', 'namespace', 'Namespace', 'cluster=~"$cluster", '),
        kubeVar('server', 'container', 'Server', 'cluster=~"$cluster", namespace=~"$namespace", '),
      ],
    };

    local sig(name, expr, unit, legend='{{container}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit)
      .filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local psig(name, expr, legend='{{container}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, 'short')
      .filteringSelector(cfg.playersSelector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      // status
      exporterUp: sig('Exporter up',
                      'max by (container) (up{%(queriesSelector)s})',
                      'short',
                      desc='Scrape of the odin/huginn exporter (:2459). 1 = scraped, 0 = target down.'),
      containerReady: sig('Container ready',
                          'max by (container) (kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s})',
                          'short',
                          desc='kube-state-metrics readiness of the server container. 1 = ready.'),
      serversReady: sig('Servers ready',
                        'sum(max by (container) (kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s}))',
                        'short',
                        'ready',
                        desc='Server containers currently ready.'),
      // players (Loki recording rule, ~10 min cadence)
      players: psig('Players',
                    'max by (container) (last_over_time(valheim:connections{%(queriesSelector)s}[15m]))',
                    desc='Connected players per server, from the valheim:connections Loki recording rule (one sample per ~10 min).'),
      playersTotal: psig('Players online',
                         'sum(max by (container) (last_over_time(valheim:connections{%(queriesSelector)s}[15m])))',
                         'players',
                         desc='Connected players across the selected servers.'),
      // resources
      cpu: sig('CPU',
               'sum by (container) (rate(container_cpu_usage_seconds_total{' + cfg.cadvisorSelector + ', %(queriesSelector)s}[$__rate_interval]))',
               'short',
               desc='CPU cores used by the server container (cAdvisor).'),
      memory: sig('Memory',
                  'sum by (container) (container_memory_working_set_bytes{' + cfg.cadvisorSelector + ', %(queriesSelector)s})',
                  'bytes',
                  desc='Working-set memory of the server container (cAdvisor).'),
      // restarts
      restarts: sig('Restarts',
                    'sum by (container) (increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[1h]))',
                    'short',
                    desc='Container restarts in the trailing hour.'),
      restartsRange: sig('Restarts in range',
                         'sum(increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[$__range]))',
                         'short',
                         'restarts',
                         desc='Container restarts over the selected time range.'),
      // logs
      logs: signal.new('Server logs', 'loki', '${loki_datasource}', '{%(queriesSelector)s} !~ "' + cfg.logsNoise + '"', 'short')
            .filteringSelector(cfg.logsSelector)
            .withDescription('Server container logs, minus the status-poll / connection-count / shader noise.'),
    };

    local upDown = panel.stat.withMappings([{ type: 'value', options: {
      '0': { text: 'DOWN', color: 'red', index: 0 },
      '1': { text: 'UP', color: 'green', index: 1 },
    } }]);
    local readyMap = panel.stat.withMappings([{ type: 'value', options: {
      '0': { text: 'NOT READY', color: 'red', index: 0 },
      '1': { text: 'READY', color: 'green', index: 1 },
    } }]);
    local redAbove(v) = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: v }]);

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local by = 'max by (cluster, namespace, container)';

    // annotation toggles: firing alerts on; server pod / container starts and
    // restarts off until wanted (a pod is named after its server container)
    local podSel = 'cluster=~"$cluster", namespace=~"$namespace", pod=~"$server-.*"';
    local annList =
      annotations.alert.bySeverity(cfg.datasource, cfg.selector)
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
        width: 6,
        height: 5,
        elements: {
          s1_ready: signals.containerReady.asStat('Container ready') + readyMap,
          s2_up: signals.exporterUp.asStat('Exporter up') + upDown,
          s3_players: signals.playersTotal.asStat('Players online'),
          s4_restarts: signals.restartsRange.asStat('Restarts in range') + redAbove(1),
        },
      },
      {
        title: 'Players',
        width: 24,
        height: 8,
        elements: {
          p1_players: signals.players.asTimeSeries('Connected players per server'),
        },
      },
      {
        title: 'Resources',
        width: 12,
        height: 8,
        elements: {
          r1_cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          r2_memory: signals.memory.asTimeSeries('Memory working set'),
          r3_restarts: signals.restarts.asTimeSeries('Restarts / 1h'),
          r4_ready: signals.containerReady.asTimeSeries('Container ready'),
        },
      },
      {
        title: 'Logs',
        width: 24,
        height: 12,
        elements: {
          l1_logs: panel.logs.new('Server logs')
                   + panel.withDescription(signals.logs._description)
                   + panel.logs.withTargets([signals.logs.asTarget()]),
        },
      },
    ], [
      alert.rule.group('valheim', [
        alert.rule.new(
          'ValheimServerDown',
          '(' + by + ' (kube_pod_container_status_ready' + rs + ') == 0) or (' + by + ' (up' + rs + ') == 0)',
          '5m',
          'critical',
          {},
          {
            summary: 'Valheim server is down.',
            description: 'Valheim server {{ $labels.container }} in {{ $labels.namespace }} ({{ $labels.cluster }}) has been not ready, or its exporter unreachable, for 5 minutes. Players cannot join.',
          }
        ),
        alert.rule.new(
          'ValheimServerCrashLooping',
          'sum by (cluster, namespace, container) (increase(kube_pod_container_status_restarts_total' + rs + '[30m])) >= 2',
          '5m',
          'warning',
          {},
          {
            summary: 'Valheim server is restarting repeatedly.',
            description: 'Valheim server {{ $labels.container }} in {{ $labels.namespace }} ({{ $labels.cluster }}) restarted {{ $value | printf "%.0f" }} times in the last 30 minutes; every restart kicks connected players.',
          }
        ),
      ]),
    ]);
    built {
      grafana+: { dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList) },
    },
}
