// observ-viz service composer (hand-written).
// One board for "a service, wherever it runs": the service's own (whitebox)
// observ-lib in front, then platform tabs that appear only where that
// platform's metrics exist —
//   Kubernetes    kube-state-metrics pod/workload status vs. requests/limits
//   Containers    cAdvisor per-container resources (kube)
//   Docker        cAdvisor containers on a docker host (system.docker elements)
//   systemd       system.systemd elements for the unit
//   Host process  system.processExporter elements for the process group
//   Process       the app's own process_* metrics
//   Go runtime    runtimes.golang elements
//   Windows       windows_exporter service state + windows_process_*
//   Ingress       networking.ingressNginx elements for the Ingress objects that
//                 route to this service
//   Logs          Loki (pod logs + journal + kubernetes events)
//   Component     Backstage catalog entry through the Infinity datasource
//   Alerts        always shown: alert list, alert-state timeline, firing table
// plus the Signals/Runbooks doc tabs pack.build adds. The alert and recording
// rules of every embedded platform pack are merged in, scoped to this service
// with a static selector per platform and renamed <app>-<group> so several
// service boards can share one ruler namespace. Annotations: firing
// alerts by severity (ALERTS, scoped like the whitebox) and Kubernetes events
// for this service's pods/workload from Loki (warnings on by default, all
// events as a toggle).
//
// Joins. Kube-scraped whitebox series carry cluster/namespace/pod/container
// (alloy's kubernetes annotation scrape adds them), so the Kubernetes and
// Containers tabs filter on the same $cluster/$namespace/$pod the whitebox
// variables resolve to. Those variables list only what the whitebox metric
// carries: on a host deployment they are empty and interpolate to "()", which
// matches the missing label — the kube tabs stay hidden, the whitebox rows keep
// working. The whitebox selector tolerates missing namespace/pod ("$namespace|")
// so a mixed fleet (kube + hosts) shows every instance under All.
// Host-level tabs filter on $host (node/windows/cadvisor `instance`) and a
// static identity from config: systemd unit, windows service/process name,
// process-exporter group, docker container name regex. $host lists only hosts
// where that identity is present.
//
// Usage:
//   local svc = import 'libs/service-observ-lib/main.libsonnet';
//   svc.new({ app: 'grafana', whitebox: g.libs.monitoring.grafana,
//             systemd: { unit: 'grafana-server.service' } }).grafana.dashboard
// Ready presets: g.libs.services.{alloy,grafana,mimir}.
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { query: gv.query + cv.query, datasource: gv.datasource + cv.datasource };
local cadvisorLib = import 'libs/cadvisor-observ-lib/main.libsonnet';
local dockerLib = import 'libs/docker-observ-lib/main.libsonnet';
local beamLib = import 'libs/beam-observ-lib/main.libsonnet';
local golangLib = import 'libs/golang-observ-lib/main.libsonnet';
local jvmLib = import 'libs/jvm-observ-lib/main.libsonnet';
local nodejsLib = import 'libs/nodejs-observ-lib/main.libsonnet';
local phpLib = import 'libs/php-observ-lib/main.libsonnet';
local pythonLib = import 'libs/python-observ-lib/main.libsonnet';
local rubyLib = import 'libs/ruby-observ-lib/main.libsonnet';
local rustLib = import 'libs/rust-observ-lib/main.libsonnet';
local dotnetLib = import 'libs/dotnet-observ-lib/main.libsonnet';
local podLib = import 'libs/kubernetes-observ-lib/main.libsonnet';
local ingressLib = import 'libs/ingress-nginx-observ-lib/main.libsonnet';
local systemdLib = import 'libs/systemd-observ-lib/main.libsonnet';
local processLib = import 'libs/process-exporter-observ-lib/main.libsonnet';
local backstageLib = import 'libs/backstage-observ-lib/main.libsonnet';
local alertPanels = import 'libs/common-lib/alert/panels.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';

local cap(s) = std.asciiUpper(std.substr(s, 0, 1)) + std.substr(s, 1, std.length(s));
// re-key another pack's elements under a prefix (drops its doc tabs). Element
// keys sort alphabetically inside a tab grid, so the prefix also orders them.
local embed(prefix, elements) =
  { [prefix + k]: elements[k] for k in std.objectFields(elements) if std.substr(k, 0, 4) != 'doc_' };
// a pack's own groups (rows), prefixed: keeps 'telemetry first, resources
// after' instead of flattening a pack into one wall of panels. Only the main
// groups, so a pack's optional tabs (its embedded process rows) stay out.
local embedGroups(prefix, pack, skip=['Process']) =
  local rows(t) = if std.objectHas(t, 'groups') then t.groups else [t];
  [
    g { elements: embed(prefix, g.elements) }
    for g in pack.grafana.groups + std.flattenArrays([rows(t) for t in pack.grafana.optionalTabs if !std.member(skip, t.title)])
  ];
local stateMappings(m) = [{ type: 'value', options: m }];

{
  new(config):
    local base = {
      app: error 'service-observ-lib: config.app is required (short service name, e.g. "grafana")',
      whitebox: error 'service-observ-lib: config.whitebox is required (an observ-lib with new(config))',
      whiteboxConfig: {},
      datasource: '${datasource}',
      // whitebox scope: job + the kube identity (tolerant of missing labels).
      selector: 'job=~"$job", cluster=~"$cluster", namespace=~"$namespace|", pod=~"$pod|"',
      kubeSelector: 'cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"',
      workloadSelector: 'cluster=~"$cluster", namespace=~"$namespace"',
      // legend for the whitebox / app-process panels: the pod on kube. Set
      // '{{instance}}' for a host deployment.
      legend: '{{pod}}',
      hostSelector: 'instance=~"$host"',
      ruleSelector: '',
      docTabs: true,
      logs: true,
      golang: true,
      // runtime tabs, each shown only where its own metrics exist. 'go' stays
      // on by default for compatibility with the golang flag.
      runtimes: ['go', 'python', 'jvm', 'dotnet', 'nodejs', 'rust', 'php', 'ruby', 'beam'],
      // merge the embedded platform packs' alert/recording rules, scoped per
      // platform (kubernetes.ruleSelector, docker.ruleSelector, ...; defaults
      // derive from the identity fields). Whitebox + Go rules use ruleSelector.
      platformRules: true,
      // narrow the cluster / namespace / pod variable menus to this deployment
      // (regexes). All = the listed options only, so the board is scoped.
      scope: { cluster: '', namespace: '', pod: '' },
      // Kubernetes events land in Loki as one line per event (alloy
      // loki.source.kubernetes_events): job + cluster/namespace + the object's
      // `name` + `reason`/`level` labels, logfmt body with kind/type/msg.
      kubeEventsSelector: 'job="integrations/kubernetes/eventhandler", cluster=~"$cluster", namespace=~"$namespace"',
      // deploy target: Software / Services (nested Grafana folders; loader creates both).
      folderUid: 'software-services',
      folderTitle: 'Services',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local app = base.app;
    local def(k, v) = if std.objectHas(base, k) then base[k] else v;
    local plat(k, v) = v + def(k, {});
    local cfg = base {
      uid: def('uid', 'observ-viz-svc-' + app),
      dashboardTitle: def('dashboardTitle', cap(app) + ' service'),
      primaryTabTitle: def('primaryTabTitle', cap(app)),
      dashboardTags: def('dashboardTags', ['service', app, 'app-level']),
      description: def('description', cap(app) + ' as a service, wherever it runs: its own metrics first, then only the platform tabs that have data (Kubernetes, containers, Docker, systemd, process, ingress, Windows, logs, the Backstage catalog entry), alerts and Kubernetes event annotations.'),
      // per-platform identity of this service (regexes, PromQL-anchored).
      kubernetes: plat('kubernetes', { enabled: true, workload: app + '.*' }),
      // ingress-nginx labels its series with the backend Service name.
      ingress: plat('ingress', { enabled: true, service: app + '.*' }),
      // Backstage catalog entry (an Infinity datasource pointed at the Backstage
      // backend). api: 'rest' | 'graphql'; uiUrl adds Backstage/TechDocs links.
      backstage: plat('backstage', { enabled: true, name: app, kind: 'component', namespace: 'default', api: 'rest', backendUrl: '', uiUrl: '' }),
      docker: plat('docker', { enabled: true, container: '.*' + app + '.*' }),
      systemd: plat('systemd', { enabled: true, unit: app + '.service' }),
      process: plat('process', { enabled: true, group: app }),
      windows: plat('windows', { enabled: true, service: '(?i)' + app + '.*', process: '(?i)' + app + '.*' }),
    };

    // ----- the whitebox pack, scoped like this board -----
    local wb = cfg.whitebox.new({
      datasource: cfg.datasource,
      selector: cfg.selector,
      ruleSelector: cfg.ruleSelector,
      legend: cfg.legend,
      docTabs: false,
    } + cfg.whiteboxConfig);
    local wbVarMetric = if std.objectHas(wb.config, 'varMetric') then wb.config.varMetric else 'up';

    // ----- signal helpers per scope -----
    // ingress-nginx series carry the backend Service name, not the pod.
    local ingressSelector = cfg.workloadSelector + ', service=~"' + cfg.ingress.service + '"';
    local ksig(name, expr, unit, legend='{{pod}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.kubeSelector).withLegendFormat(legend).withDescription(desc);
    local wsig(name, expr, unit, legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.workloadSelector).withLegendFormat(legend).withDescription(desc);
    local hsig(name, expr, unit, legend='{{instance}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.hostSelector).withLegendFormat(legend).withDescription(desc);
    local jsig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local isig(name, expr, unit, legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(ingressSelector).withLegendFormat(legend).withDescription(desc);
    local lsig(name, selector, desc='') =
      signal.new(name, 'loki', '${loki_datasource}', '{%(queriesSelector)s}', 'short').filteringSelector(selector).withDescription(desc);

    local wl = cfg.kubernetes.workload;
    local unit = cfg.systemd.unit;
    local grp = cfg.process.group;
    local wsvc = cfg.windows.service;
    local wproc = cfg.windows.process;

    local signals = {
      // ===== Kubernetes: pod resources vs. requests/limits, status =====
      kube_cpu: ksig('CPU usage', 'sum by (pod) (rate(container_cpu_usage_seconds_total{%(queriesSelector)s, container!=""}[$__rate_interval]))', 'short', desc='CPU cores used by all containers of each pod (cAdvisor). Dashed lines are the requests and limits from kube-state-metrics: usage above the request means the pod competes for CPU, usage at the limit means it is being throttled.'),
      kube_cpuRequests: ksig('CPU requests', 'sum by (pod) (kube_pod_container_resource_requests{%(queriesSelector)s, resource="cpu"})', 'short', '{{pod}} requests', desc='CPU requested by the pod containers (what the scheduler reserved).'),
      kube_cpuLimits: ksig('CPU limits', 'sum by (pod) (kube_pod_container_resource_limits{%(queriesSelector)s, resource="cpu"})', 'short', '{{pod}} limits', desc='CPU limit of the pod containers (above it the kernel throttles).'),
      kube_mem: ksig('Memory working set', 'sum by (pod) (container_memory_working_set_bytes{%(queriesSelector)s, container!=""})', 'bytes', desc='Working-set memory of each pod (what the kernel would OOM-kill on). Dashed lines are requests and limits: a working set near the limit means an OOM kill is close.'),
      kube_memRequests: ksig('Memory requests', 'sum by (pod) (kube_pod_container_resource_requests{%(queriesSelector)s, resource="memory"})', 'bytes', '{{pod}} requests', desc='Memory requested by the pod containers.'),
      kube_memLimits: ksig('Memory limits', 'sum by (pod) (kube_pod_container_resource_limits{%(queriesSelector)s, resource="memory"})', 'bytes', '{{pod}} limits', desc='Memory limit of the pod containers (the OOM-kill threshold).'),
      kube_restarts: ksig('Container restarts', 'sum by (pod) (kube_pod_container_status_restarts_total{%(queriesSelector)s})', 'short', desc='Cumulative container restarts per pod. A rising line is a crash loop or a failing liveness probe.'),
      kube_phase: ksig('Pods by phase', 'sum by (phase) (kube_pod_status_phase{%(queriesSelector)s} == 1)', 'short', '{{phase}}', desc='Number of pods in each phase (Running, Pending, Succeeded, Failed, Unknown).'),
      kube_ready: ksig('Containers ready', 'sum by (pod) (kube_pod_container_status_ready{%(queriesSelector)s})', 'short', desc='Containers that pass their readiness probe, per pod.'),
      kube_waiting: ksig('Containers waiting', 'sum by (pod, reason) (kube_pod_container_status_waiting_reason{%(queriesSelector)s} == 1)', 'short', '{{pod}} {{reason}}', desc='Containers stuck in Waiting and why (CrashLoopBackOff, ImagePullBackOff, ContainerCreating...).'),
      kube_age: ksig('Pod age', 'time() - kube_pod_start_time{%(queriesSelector)s}', 's', desc='Time since each pod started.'),
      // stat-row aggregates
      kube_pods: ksig('Pods', 'count(kube_pod_info{%(queriesSelector)s})', 'short', 'pods', desc='Pods matching the selection.'),
      kube_restarts1h: ksig('Restarts (1h)', 'sum(increase(kube_pod_container_status_restarts_total{%(queriesSelector)s}[1h]))', 'short', 'restarts', desc='Container restarts in the last hour across the selected pods. Anything above zero deserves a look at the Waiting reasons.'),
      kube_youngest: ksig('Youngest pod', 'min(time() - kube_pod_start_time{%(queriesSelector)s})', 'dtdurations', 'age', desc='Age of the most recently started pod. A young pod on a long-running service means a restart or a rollout.'),
      kube_readyTotal: ksig('Containers ready', 'sum(kube_pod_container_status_ready{%(queriesSelector)s})', 'short', 'ready', desc='Containers currently passing their readiness probe.'),
      kube_waitingTotal: ksig('Containers waiting', 'sum(kube_pod_container_status_waiting{%(queriesSelector)s})', 'short', 'waiting', desc='Containers currently in the Waiting state (not running, not terminated).'),
      kube_notRunning: ksig('Pods not running', 'sum(kube_pod_status_phase{%(queriesSelector)s, phase!="Running"} == 1) or vector(0)', 'short', 'not running', desc='Pods in any phase other than Running.'),
      // workload objects carry no pod label — matched by name regex instead.
      kube_deployDesired: wsig('Deployment desired', 'kube_deployment_spec_replicas{%(queriesSelector)s, deployment=~"' + wl + '"}', 'short', '{{deployment}} desired', desc='Replicas the Deployment spec asks for (dashed) versus replicas actually available.'),
      kube_deployAvailable: wsig('Deployment available', 'kube_deployment_status_replicas_available{%(queriesSelector)s, deployment=~"' + wl + '"}', 'short', '{{deployment}} available', desc='Deployment replicas that are available (ready for minReadySeconds).'),
      kube_stsDesired: wsig('StatefulSet desired', 'kube_statefulset_replicas{%(queriesSelector)s, statefulset=~"' + wl + '"}', 'short', '{{statefulset}} desired', desc='Replicas the StatefulSet spec asks for (dashed) versus replicas that are ready.'),
      kube_stsReady: wsig('StatefulSet ready', 'kube_statefulset_status_replicas_ready{%(queriesSelector)s, statefulset=~"' + wl + '"}', 'short', '{{statefulset}} ready', desc='StatefulSet replicas that are ready.'),
      kube_dsDesired: wsig('DaemonSet desired', 'kube_daemonset_status_desired_number_scheduled{%(queriesSelector)s, daemonset=~"' + wl + '"}', 'short', '{{daemonset}} desired', desc='Nodes that should run the DaemonSet pod (dashed) versus nodes where it is ready.'),
      kube_dsReady: wsig('DaemonSet ready', 'kube_daemonset_status_number_ready{%(queriesSelector)s, daemonset=~"' + wl + '"}', 'short', '{{daemonset}} ready', desc='Nodes where the DaemonSet pod is ready.'),
      kube_pvcUsage: wsig('PVC usage', 'kubelet_volume_stats_used_bytes{%(queriesSelector)s} / kubelet_volume_stats_capacity_bytes{%(queriesSelector)s}', 'percentunit', '{{persistentvolumeclaim}}', desc='Used share of every PersistentVolumeClaim in the namespace, from kubelet volume stats. Not tied to a pod: the whole namespace is shown.'),
      // ===== Process (the app's own process_* client metrics) =====
      proc_cpu: jsig('Process CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='CPU cores used by the process, from its own /metrics (process_cpu_seconds_total).'),
      proc_rss: jsig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes', cfg.legend + ' rss', desc='Resident set size reported by the process itself. The dashed line is the virtual address space size.'),
      proc_virt: jsig('Virtual memory', 'process_virtual_memory_bytes{%(queriesSelector)s}', 'bytes', cfg.legend + ' virtual', desc='Virtual memory size of the process (address space, not RAM used).'),
      proc_fds: jsig('Open file descriptors', 'process_open_fds{%(queriesSelector)s}', 'short', desc='File descriptors the process has open.'),
      proc_fdRatio: jsig('FD usage', 'process_open_fds{%(queriesSelector)s} / process_max_fds{%(queriesSelector)s}', 'percentunit', desc='Open file descriptors divided by the process limit. Near 1 new connections and files start failing.'),
      proc_uptime: jsig('Uptime', 'time() - process_start_time_seconds{%(queriesSelector)s}', 's', desc='Time since the process started (process_start_time_seconds).'),
      // ===== Windows (windows_exporter service + process collectors) =====
      win_state: hsig('Service state', 'max by (instance, name) ((windows_service_state{name=~"' + wsvc + '", state="running", %(queriesSelector)s} == 1) * 1 or (windows_service_state{name=~"' + wsvc + '", state=~"start pending|continue pending", %(queriesSelector)s} == 1) * 2 or (windows_service_state{name=~"' + wsvc + '", state=~"paused|pause pending|stop pending", %(queriesSelector)s} == 1) * 3 or (windows_service_state{name=~"' + wsvc + '", state="stopped", %(queriesSelector)s} == 1) * 4)', 'short', '{{instance}} {{name}}', desc='State of the Windows service on every host where it exists: running, starting, paused or stopping, stopped (windows_exporter service collector).'),
      win_cpu: hsig('Process CPU', 'sum by (instance) (rate(windows_process_cpu_time_total{process=~"' + wproc + '", %(queriesSelector)s}[$__rate_interval]))', 'short', desc='CPU cores used by the matching Windows processes on each host.'),
      win_workingSet: hsig('Working set', 'sum by (instance) (windows_process_working_set_private_bytes{process=~"' + wproc + '", %(queriesSelector)s} or windows_process_working_set_bytes{process=~"' + wproc + '", %(queriesSelector)s})', 'bytes', desc='Working set of the matching Windows processes (private bytes where the exporter reports them, otherwise the shared working set).'),
      win_handles: hsig('Handles', 'sum by (instance) (windows_process_handles{process=~"' + wproc + '", %(queriesSelector)s})', 'short', desc='Handles held by the matching Windows processes. Steadily growing means a handle leak.'),
      win_threads: hsig('Threads', 'sum by (instance) (windows_process_threads{process=~"' + wproc + '", %(queriesSelector)s})', 'short', desc='Threads of the matching Windows processes.'),
      win_io: hsig('Process IO', 'sum by (instance, mode) (rate(windows_process_io_bytes_total{process=~"' + wproc + '", %(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} {{mode}}', desc='Bytes read and written by the matching Windows processes per second, by IO mode.'),
      win_uptime: hsig('Process uptime', 'time() - min by (instance) (windows_process_start_time{process=~"' + wproc + '", %(queriesSelector)s})', 's', desc='Time since the oldest matching Windows process started.'),
      // ===== Logs (Loki) =====
      logs_pod: lsig('Pod logs', 'cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"', desc='Log lines of the selected pods, from Loki.'),
      logs_journal: lsig('Journal', 'instance=~"$host", unit=~"' + unit + '"', desc='Journal lines of the systemd unit on the selected hosts, from Loki.'),
    };

    local winMappings = stateMappings({
      '1': { text: 'running', color: 'green', index: 0 },
      '2': { text: 'starting', color: 'yellow', index: 1 },
      '3': { text: 'paused/stopping', color: 'orange', index: 2 },
      '4': { text: 'stopped', color: 'red', index: 3 },
    });
    local timeline(title, sig, mappings) =
      panel.base('state-timeline', title)
      + panel.withDescription(sig._description)
      + panel.withTargets([sig.asTarget()])
      + panel.withOptions({ legend: { showLegend: false }, rowHeight: 0.85 })
      + panel.withFieldConfigDefaults({ custom: { fillOpacity: 72, lineWidth: 0 } })
      + panel.withMappings(mappings);

    // events of this service's pods and of the workload objects that own them
    // (deployment / replicaset / statefulset carry the workload name, not a pod).
    local kubeEvents(extra) =
      '{' + cfg.kubeEventsSelector + ', name=~"$pod|' + wl + '"' + extra + '}';

    // ----- platform packs embedded for this service -----
    local sysd = systemdLib.units(cfg.datasource, cfg.hostSelector, unit);
    local hproc = processLib.group(cfg.datasource, cfg.hostSelector, grp);
    local ingr = ingressLib.ingress(cfg.datasource, ingressSelector);
    local bs = backstageLib.component('${backstage_datasource}', cfg.backstage.name, cfg.backstage.kind, cfg.backstage.namespace, cfg.backstage.api, cfg.backstage.backendUrl, cfg.backstage.uiUrl);
    local platformSignals =
      { ['systemd_' + k]: sysd.signals[k] for k in std.objectFields(sysd.signals) }
      + { ['hproc_' + k]: hproc.signals[k] for k in std.objectFields(hproc.signals) }
      + { ['ing_' + k]: ingr.signals[k] for k in std.objectFields(ingr.signals) };

    // static per-platform scopes for the merged rules (the dashboard variables
    // do not exist in a ruler). Kube pods are matched by the workload regex.
    local rs(block, default) = if std.objectHas(block, 'ruleSelector') then block.ruleSelector else default;
    local scopes = {
      kube: rs(cfg.kubernetes, 'pod=~"' + wl + '"'),
      docker: rs(cfg.docker, 'name=~"' + cfg.docker.container + '"'),
      systemd: rs(cfg.systemd, 'name=~"' + unit + '"'),
      process: rs(cfg.process, 'groupname=~"' + grp + '"'),
      ingress: rs(cfg.ingress, 'service=~"' + cfg.ingress.service + '"'),
    };
    local scoped(lib, ruleSelector) = lib.new({ datasource: cfg.datasource, ruleSelector: ruleSelector, docTabs: false }).prometheus;
    local rename(groups) = [g { name: app + '-' + g.name } for g in groups];
    local platformPacks =
      (if cfg.kubernetes.enabled then [scoped(podLib, scopes.kube), scoped(cadvisorLib, scopes.kube)] else [])
      + (if cfg.docker.enabled then [scoped(dockerLib, scopes.docker)] else [])
      + (if cfg.systemd.enabled then [scoped(systemdLib, scopes.systemd)] else [])
      + (if cfg.process.enabled then [scoped(processLib, scopes.process)] else [])
      + (if cfg.ingress.enabled then [scoped(ingressLib, scopes.ingress)] else [])
      // Go rules alert on `up == 0` and friends: only with a static job scope.
      + (if cfg.golang && cfg.ruleSelector != '' then [scoped(golangLib, cfg.ruleSelector)] else []);
    local platformAlerts = if cfg.platformRules then std.flattenArrays([rename(p.alerts) for p in platformPacks]) else [];
    local platformRules = if cfg.platformRules then std.flattenArrays([rename(p.rules) for p in platformPacks]) else [];

    // ----- annotations: firing alerts by severity + kubernetes events -----
    local alertAnn(sev) = annotations.base.target(cfg.datasource, 'ALERTS{alertstate="firing", severity="' + sev + '", ' + cfg.selector + '}');
    local annList = [
      annotations.critical.new('Critical alerts', alertAnn('critical')) + annotations.base.withTagKeys(['alertname', 'severity', 'pod', 'instance']),
      annotations.warning.new('Warning alerts', alertAnn('warning')) + annotations.base.withTagKeys(['alertname', 'severity', 'pod', 'instance']),
      annotations.info.new('Info alerts', alertAnn('info')) + annotations.base.withTagKeys(['alertname', 'severity', 'pod', 'instance']) + { spec+: { enable: false } },
      // restarts: the process start time moving, and a container restarting
      annotations.restart.new('Restarts', annotations.restart.process(cfg.datasource, cfg.selector), ['instance', 'pod']),
      annotations.restart.new('Container restarts', annotations.restart.kubeContainer(cfg.datasource, cfg.kubeSelector), ['pod', 'container']),
    ] + (if cfg.logs then [
           annotations.warning.new('Kube events (warning)', annotations.base.target('${loki_datasource}', kubeEvents(', level="Warning"'), 'loki')),
           annotations.info.new('Kube events (all)', annotations.base.target('${loki_datasource}', kubeEvents(''), 'loki')) + { spec+: { enable: false } },
         ] else []);

    // ----- optional tabs (each gated on a presence marker) -----
    // Layout follows the upstream packs: a row of small stat tiles (4x4), then
    // charts two per row (12x7); related series share one panel (usage with
    // its requests/limits drawn dashed, desired vs ready, read vs write).
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };
    local wide = { width: 24, height: 6 };
    local dashed(regex) = panel.withOverrides([{
      matcher: { id: 'byRegexp', options: regex },
      properties: [
        { id: 'custom.lineStyle', value: { fill: 'dash', dash: [10, 10] } },
        { id: 'custom.fillOpacity', value: 0 },
      ],
    }]);
    local red1 = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]);
    local tabs =
      (if cfg.kubernetes.enabled then [{
         title: 'Kubernetes',
         presence: { query: 'kube_pod_info{' + cfg.kubeSelector + '}', label: 'pod' },
         groups: [
           {
             title: 'Status',
             elements: {
               k01_pods: signals.kube_pods.asStat('Pods'),
               k02_notRunning: signals.kube_notRunning.asStat('Not running') + red1,
               k03_restarts: signals.kube_restarts1h.asStat('Restarts (1h)') + red1,
               k04_ready: signals.kube_readyTotal.asStat('Containers ready'),
               k05_waiting: signals.kube_waitingTotal.asStat('Containers waiting') + red1,
               k06_age: signals.kube_youngest.asStat('Youngest pod'),
             },
           } + stats,
           // pod telemetry first: what the pods are doing, then what they use
           {
             title: 'Pods',
             elements: {
               k11_phase: signals.kube_phase.asTimeSeries('Pods by phase'),
               k12_restarts: signals.kube_restarts.asTimeSeries('Container restarts (total)'),
               k13_waiting: signals.kube_waiting.asTimeSeries('Containers waiting by reason'),
             },
           } + charts,
           {
             title: 'Workload',
             elements: {
               k21_deploy: signals.kube_deployDesired.asTimeSeries('Deployment: desired vs available')
                           + panel.withTargetsMixin([signals.kube_deployAvailable.asTarget()])
                           + dashed('/ desired$/'),
               k22_sts: signals.kube_stsDesired.asTimeSeries('StatefulSet: desired vs ready')
                        + panel.withTargetsMixin([signals.kube_stsReady.asTarget()])
                        + dashed('/ desired$/'),
               k23_ds: signals.kube_dsDesired.asTimeSeries('DaemonSet: desired vs ready')
                       + panel.withTargetsMixin([signals.kube_dsReady.asTarget()])
                       + dashed('/ desired$/'),
             },
           } + charts,
           {
             title: 'Resources',
             elements: {
               k31_cpu: signals.kube_cpu.asTimeSeries('CPU: usage vs requests / limits')
                        + panel.withTargetsMixin([signals.kube_cpuRequests.asTarget(), signals.kube_cpuLimits.asTarget()])
                        + dashed('/ (requests|limits)$/'),
               k32_mem: signals.kube_mem.asTimeSeries('Memory: working set vs requests / limits')
                        + panel.withTargetsMixin([signals.kube_memRequests.asTarget(), signals.kube_memLimits.asTarget()])
                        + dashed('/ (requests|limits)$/'),
               k33_pvc: signals.kube_pvcUsage.asTimeSeries('PVC usage (namespace)'),
             },
           } + charts,
         ],
       }, {
         title: 'Containers',
         presence: { query: 'container_cpu_usage_seconds_total{' + cfg.kubeSelector + ', container!=""}', label: 'pod' },
         // the cadvisor observ-lib, scoped to these pods, keeping its rows
         groups: embedGroups('cadvisor_', cadvisorLib.new({ datasource: cfg.datasource, selector: cfg.kubeSelector, docTabs: false })),
       }] else [])
      + (if cfg.docker.enabled then [{
           title: 'Docker',
           presence: { query: 'container_last_seen{' + cfg.hostSelector + ', name=~"' + cfg.docker.container + '"}', label: 'instance' },
           groups: embedGroups('docker_', dockerLib.new({ datasource: cfg.datasource, selector: cfg.hostSelector + ', name=~"' + cfg.docker.container + '"', docTabs: false })),
         }] else [])
      + (if cfg.systemd.enabled then [{
           title: 'systemd',
           presence: { query: 'node_systemd_unit_state{' + cfg.hostSelector + ', name=~"' + unit + '"}', label: 'instance' },
           groups: [
             { title: 'State', elements: sysd.stats } + stats,
             { title: 'Units', elements: sysd.wide } + wide,
             { title: 'Detail', elements: sysd.charts } + charts,
           ],
         }] else [])
      + (if cfg.process.enabled then [{
           title: 'Host process',
           presence: { query: 'namedprocess_namegroup_num_procs{' + cfg.hostSelector + ', groupname=~"' + grp + '"}', label: 'instance' },
           groups: [
             { title: 'Overview', elements: hproc.stats } + stats,
             { title: 'Usage', elements: hproc.charts } + charts,
           ],
         }] else [])
      + [{
        title: 'Process',
        presence: { query: 'process_cpu_seconds_total{' + cfg.selector + '}', label: 'instance' },
        groups: [
          { title: 'Overview', elements: {
            p01_fds: signals.proc_fds.asStat('Open file descriptors'),
            p02_fdRatio: signals.proc_fdRatio.asStat('FD usage'),
            p03_uptime: signals.proc_uptime.asStat('Uptime'),
          } } + stats,
          { title: 'Usage', elements: {
            p11_cpu: signals.proc_cpu.asTimeSeries('CPU (cores)'),
            p12_mem: signals.proc_rss.asTimeSeries('Resident / virtual memory')
                     + panel.withTargetsMixin([signals.proc_virt.asTarget()])
                     + dashed('/ virtual$/'),
          } } + charts,
        ],
      }]
      // one tab per runtime, each gated on that runtime's own marker metric, so
      // a service written in any of them lights up the right tab and no other.
      + local runtimeTabs = {
        go: { title: 'Go runtime', marker: 'go_goroutines', prefix: 'go_', lib: golangLib },
        python: { title: 'Python runtime', marker: 'python_info', prefix: 'py_', lib: pythonLib },
        jvm: { title: 'JVM runtime', marker: 'jvm_info', prefix: 'jvm_', lib: jvmLib },
        dotnet: { title: '.NET runtime', marker: 'dotnet_build_info', prefix: 'net_', lib: dotnetLib },
        nodejs: { title: 'Node.js runtime', marker: 'nodejs_version_info', prefix: 'node_', lib: nodejsLib },
        rust: { title: 'Rust runtime', marker: 'tokio_workers_count', prefix: 'rs_', lib: rustLib },
        php: { title: 'PHP runtime', marker: 'phpfpm_up', prefix: 'php_', lib: phpLib },
        ruby: { title: 'Ruby runtime', marker: 'puma_workers', prefix: 'rb_', lib: rubyLib },
        beam: { title: 'BEAM runtime', marker: 'erlang_vm_processes', prefix: 'beam_', lib: beamLib },
      };
      local wanted = if cfg.golang then cfg.runtimes else [r for r in cfg.runtimes if r != 'go'];
      [
        {
          title: runtimeTabs[r].title,
          presence: { query: runtimeTabs[r].marker + '{' + cfg.selector + '}', label: 'instance' },
          groups: embedGroups(runtimeTabs[r].prefix, runtimeTabs[r].lib.new({ datasource: cfg.datasource, selector: cfg.selector, docTabs: false })),
        }
        for r in wanted
        if std.objectHas(runtimeTabs, r)
      ]
      + (if cfg.windows.enabled then [{
           title: 'Windows',
           presence: { query: 'windows_service_state{' + cfg.hostSelector + ', name=~"' + wsvc + '"}', label: 'instance' },
           groups: [
             { title: 'Overview', elements: {
               w01_uptime: signals.win_uptime.asStat('Uptime'),
               w02_handles: signals.win_handles.asStat('Handles'),
               w03_threads: signals.win_threads.asStat('Threads'),
             } } + stats,
             { title: 'Service', elements: {
               w11_state: timeline('Service state', signals.win_state, winMappings),
             } } + wide,
             { title: 'Usage', elements: {
               w21_cpu: signals.win_cpu.asTimeSeries('CPU (cores)'),
               w22_workingSet: signals.win_workingSet.asTimeSeries('Working set'),
               w23_io: signals.win_io.asTimeSeries('IO'),
             } } + charts,
           ],
         }] else [])
      + (if cfg.ingress.enabled then [{
           title: 'Ingress',
           presence: { query: 'nginx_ingress_controller_requests{' + ingressSelector + '}', label: 'ingress' },
           groups: [
             { title: 'Overview', elements: ingr.stats } + stats,
             { title: 'Traffic', elements: ingr.charts } + charts,
           ],
         }] else [])
      + (if cfg.logs then [{
           title: 'Logs',
           width: 24,
           height: 10,
           // no marker metric: shown when either query returns lines.
           elements: {
             l01_pod: panel.logs.new('Pod logs') + panel.withDescription(signals.logs_pod._description) + panel.logs.withTargets([signals.logs_pod.asTarget()]),
             l02_journal: panel.logs.new('Journal') + panel.withDescription(signals.logs_journal._description) + panel.logs.withTargets([signals.logs_journal.asTarget()]),
             l03_events: panel.logs.new('Kubernetes events')
                         + panel.withDescription('Kubernetes events for the selected pods and the workload objects that own them, one line per event: type, kind/name, reason and message.')
                         + panel.withDescription('Kubernetes events for the selected pods and the workload objects that own them, one line per event: type, kind/name, reason and message.')
                         + panel.logs.withTargets([query.loki.new('${loki_datasource}', kubeEvents('') + ' | logfmt | line_format "{{.type}} {{.kind}}/{{.name}} {{.reason}}: {{.msg}}"')]),
           },
         }] else [])
      + (if cfg.backstage.enabled then [{
           title: 'Component',
           // no marker metric: the catalog query returns nothing when the
           // entity does not exist, so the tab shows only where it does.
           groups: [
             { title: 'Catalog', elements: bs.stats } + stats,
             { title: 'Entity', elements: bs.tables, width: 12, height: 8 },
           ],
         }] else [])
      + [{
        title: 'Alerts',
        alwaysShow: true,
        groups: [
          { title: 'Alerts', width: 12, height: 9, elements: {
            a01_list: alertPanels.list('Alerts', instanceFilter='{job=~"$job"}', groupMode='custom', groupBy=['alertname'])
                      + panel.withDescription('Alert instances for this job as Grafana sees them, grouped by rule.'),
            a02_timeline: alertPanels.timeline('Alert state', cfg.datasource, cfg.selector)
                          + panel.withDescription('Every alert rule touching this service over time: pending, then firing coloured by severity (ALERTS series from the rule evaluator).'),
          } },
          { title: 'Firing', width: 24, height: 8, elements: {
            a11_firing: alertPanels.firingTable('Firing alerts', cfg.datasource, cfg.selector)
                        + panel.withDescription('Alerts firing right now for this service, counted by rule and severity.'),
          } },
        ],
      }];

    // ----- variables: job + cascading kube identity off the whitebox metric, host off the platform markers -----
    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local multi = variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent;
    local hostIdentity = std.join('|', [unit, wsvc, cfg.docker.container]);
    local scopeSel(label) = if std.objectHas(cfg.scope, label) && cfg.scope[label] != '' then ', ' + label + '=~"' + cfg.scope[label] + '"' else '';
    local extraVars = [
      // Infinity datasource for the Component tab.
    ] + (if cfg.backstage.enabled then [
           variable.datasource.new('backstage_datasource', 'yesoreyeram-infinity-datasource') + { spec+: { label: 'Backstage' } },
         ] else []) + [
      variable.query.new('cluster') + variable.query.withLabel('Cluster')
      + variable.query.withLabelValues('cluster', wbVarMetric + '{job=~"$job"' + scopeSel('cluster') + '}') + multi,
      variable.query.new('namespace') + variable.query.withLabel('Namespace')
      + variable.query.withLabelValues('namespace', wbVarMetric + '{job=~"$job", cluster=~"$cluster"' + scopeSel('namespace') + '}') + multi,
      variable.query.new('pod') + variable.query.withLabel('Pod')
      + variable.query.withLabelValues('pod', wbVarMetric + '{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"' + scopeSel('pod') + '}') + multi,
      // hosts where this service is a systemd unit, a windows service or a docker container.
      variable.query.new('host') + variable.query.withLabel('Host')
      + variable.query.withLabelValues('instance', '{__name__=~"node_systemd_unit_state|windows_service_state|container_last_seen", name=~"' + hostIdentity + '"}') + multi,
    ];

    local pcfg = cfg { varMetric: wbVarMetric, varLabels: [], lokiDatasource: cfg.logs };
    local built = pack.build(pcfg, wb.signals + signals + platformSignals, wb.grafana.groups, wb.prometheus.alerts + platformAlerts, wb.prometheus.rules + platformRules, tabs);
    built {
      whitebox: wb,
      grafana+: { dashboard: super.dashboard + dashboard.withVariablesMixin(extraVars) + dashboard.withAnnotationsMixin(annList) },
    },
}
