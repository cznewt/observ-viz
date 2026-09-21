// observ-viz service composer (hand-written).
// One board for "a service, wherever it runs": the service's own (whitebox)
// observ-lib in front, then platform tabs that appear only where that
// platform's metrics exist —
//   Kubernetes    kube-state-metrics pod/workload status vs. requests/limits
//   Containers    cAdvisor per-container resources (kube)
//   Docker        cAdvisor containers on a docker host (system.docker elements)
//   systemd       node_exporter unit state
//   Host process  process-exporter group (namedprocess_*)
//   Process       the app's own process_* metrics
//   Go runtime    runtimes.golang elements
//   Windows       windows_exporter service state + windows_process_*
//   Logs          Loki (pod logs + journal + kubernetes events)
//   Alerts        always shown: alert list, alert-state timeline, firing table
// plus the Signals/Runbooks doc tabs pack.build adds. Annotations: firing
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
  { query: gv.query + cv.query };
local cadvisorLib = import 'libs/cadvisor-observ-lib/main.libsonnet';
local dockerLib = import 'libs/docker-observ-lib/main.libsonnet';
local golangLib = import 'libs/golang-observ-lib/main.libsonnet';
local alertPanels = import 'libs/common-lib/alert/panels.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';

local cap(s) = std.asciiUpper(std.substr(s, 0, 1)) + std.substr(s, 1, std.length(s));
// re-key another pack's elements under a prefix (drops its doc tabs). Element
// keys sort alphabetically inside a tab grid, so the prefix also orders them.
local embed(prefix, elements) =
  { [prefix + k]: elements[k] for k in std.objectFields(elements) if std.substr(k, 0, 4) != 'doc_' };
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
      hostSelector: 'instance=~"$host"',
      ruleSelector: '',
      docTabs: true,
      logs: true,
      golang: true,
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
      // per-platform identity of this service (regexes, PromQL-anchored).
      kubernetes: plat('kubernetes', { enabled: true, workload: app + '.*' }),
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
      docTabs: false,
    } + cfg.whiteboxConfig);
    local wbVarMetric = if std.objectHas(wb.config, 'varMetric') then wb.config.varMetric else 'up';

    // ----- signal helpers per scope -----
    local ksig(name, expr, unit, legend='{{pod}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.kubeSelector).withLegendFormat(legend);
    local wsig(name, expr, unit, legend) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.workloadSelector).withLegendFormat(legend);
    local hsig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.hostSelector).withLegendFormat(legend);
    local jsig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);
    local lsig(name, selector) =
      signal.new(name, 'loki', '${loki_datasource}', '{%(queriesSelector)s}', 'short').filteringSelector(selector);

    local wl = cfg.kubernetes.workload;
    local unit = cfg.systemd.unit;
    local grp = cfg.process.group;
    local wsvc = cfg.windows.service;
    local wproc = cfg.windows.process;

    local signals = {
      // ===== Kubernetes: pod resources vs. requests/limits, status =====
      kube_cpu: ksig('CPU usage', 'sum by (pod) (rate(container_cpu_usage_seconds_total{%(queriesSelector)s, container!=""}[$__rate_interval]))', 'short'),
      kube_cpuRequests: ksig('CPU requests', 'sum by (pod) (kube_pod_container_resource_requests{%(queriesSelector)s, resource="cpu"})', 'short', '{{pod}} requests'),
      kube_cpuLimits: ksig('CPU limits', 'sum by (pod) (kube_pod_container_resource_limits{%(queriesSelector)s, resource="cpu"})', 'short', '{{pod}} limits'),
      kube_mem: ksig('Memory working set', 'sum by (pod) (container_memory_working_set_bytes{%(queriesSelector)s, container!=""})', 'bytes'),
      kube_memRequests: ksig('Memory requests', 'sum by (pod) (kube_pod_container_resource_requests{%(queriesSelector)s, resource="memory"})', 'bytes', '{{pod}} requests'),
      kube_memLimits: ksig('Memory limits', 'sum by (pod) (kube_pod_container_resource_limits{%(queriesSelector)s, resource="memory"})', 'bytes', '{{pod}} limits'),
      kube_restarts: ksig('Container restarts', 'sum by (pod) (kube_pod_container_status_restarts_total{%(queriesSelector)s})', 'short'),
      kube_phase: ksig('Pods by phase', 'sum by (phase) (kube_pod_status_phase{%(queriesSelector)s} == 1)', 'short', '{{phase}}'),
      kube_ready: ksig('Containers ready', 'sum by (pod) (kube_pod_container_status_ready{%(queriesSelector)s})', 'short'),
      kube_waiting: ksig('Containers waiting', 'sum by (pod, reason) (kube_pod_container_status_waiting_reason{%(queriesSelector)s} == 1)', 'short', '{{pod}} {{reason}}'),
      kube_age: ksig('Pod age', 'time() - kube_pod_start_time{%(queriesSelector)s}', 's'),
      // stat-row aggregates
      kube_pods: ksig('Pods', 'count(kube_pod_info{%(queriesSelector)s})', 'short', 'pods'),
      kube_restarts1h: ksig('Restarts (1h)', 'sum(increase(kube_pod_container_status_restarts_total{%(queriesSelector)s}[1h]))', 'short', 'restarts'),
      kube_youngest: ksig('Youngest pod', 'min(time() - kube_pod_start_time{%(queriesSelector)s})', 'dtdurations', 'age'),
      kube_readyTotal: ksig('Containers ready', 'sum(kube_pod_container_status_ready{%(queriesSelector)s})', 'short', 'ready'),
      kube_waitingTotal: ksig('Containers waiting', 'sum(kube_pod_container_status_waiting{%(queriesSelector)s})', 'short', 'waiting'),
      kube_notRunning: ksig('Pods not running', 'sum(kube_pod_status_phase{%(queriesSelector)s, phase!="Running"} == 1) or vector(0)', 'short', 'not running'),
      // workload objects carry no pod label — matched by name regex instead.
      kube_deployDesired: wsig('Deployment desired', 'kube_deployment_spec_replicas{%(queriesSelector)s, deployment=~"' + wl + '"}', 'short', '{{deployment}} desired'),
      kube_deployAvailable: wsig('Deployment available', 'kube_deployment_status_replicas_available{%(queriesSelector)s, deployment=~"' + wl + '"}', 'short', '{{deployment}} available'),
      kube_stsDesired: wsig('StatefulSet desired', 'kube_statefulset_replicas{%(queriesSelector)s, statefulset=~"' + wl + '"}', 'short', '{{statefulset}} desired'),
      kube_stsReady: wsig('StatefulSet ready', 'kube_statefulset_status_replicas_ready{%(queriesSelector)s, statefulset=~"' + wl + '"}', 'short', '{{statefulset}} ready'),
      kube_dsDesired: wsig('DaemonSet desired', 'kube_daemonset_status_desired_number_scheduled{%(queriesSelector)s, daemonset=~"' + wl + '"}', 'short', '{{daemonset}} desired'),
      kube_dsReady: wsig('DaemonSet ready', 'kube_daemonset_status_number_ready{%(queriesSelector)s, daemonset=~"' + wl + '"}', 'short', '{{daemonset}} ready'),
      kube_pvcUsage: wsig('PVC usage', 'kubelet_volume_stats_used_bytes{%(queriesSelector)s} / kubelet_volume_stats_capacity_bytes{%(queriesSelector)s}', 'percentunit', '{{persistentvolumeclaim}}'),

      // ===== systemd (node_exporter systemd collector) =====
      systemd_state: hsig('Unit state', 'max by (instance, name) ((node_systemd_unit_state{name=~"' + unit + '", state="active", %(queriesSelector)s} == 1) * 1 or (node_systemd_unit_state{name=~"' + unit + '", state=~"activating|deactivating", %(queriesSelector)s} == 1) * 2 or (node_systemd_unit_state{name=~"' + unit + '", state="inactive", %(queriesSelector)s} == 1) * 3 or (node_systemd_unit_state{name=~"' + unit + '", state="failed", %(queriesSelector)s} == 1) * 4)', 'short', '{{instance}} {{name}}'),
      systemd_active: hsig('Active units', 'count(node_systemd_unit_state{name=~"' + unit + '", state="active", %(queriesSelector)s} == 1)', 'short', 'active'),
      systemd_failed: hsig('Failed units', 'count(node_systemd_unit_state{name=~"' + unit + '", state="failed", %(queriesSelector)s} == 1) or vector(0)', 'short', 'failed'),
      systemd_hosts: hsig('Hosts', 'count(count by (instance) (node_systemd_unit_state{name=~"' + unit + '", %(queriesSelector)s}))', 'short', 'hosts'),

      // ===== Host process (process-exporter namedprocess_* by groupname) =====
      hproc_cpu: hsig('Process CPU', 'sum by (instance) (rate(namedprocess_namegroup_cpu_seconds_total{groupname=~"' + grp + '", %(queriesSelector)s}[$__rate_interval]))', 'short'),
      hproc_rss: hsig('Process RSS', 'sum by (instance) (namedprocess_namegroup_memory_bytes{groupname=~"' + grp + '", memtype="resident", %(queriesSelector)s})', 'bytes'),
      hproc_procs: hsig('Processes', 'sum by (instance) (namedprocess_namegroup_num_procs{groupname=~"' + grp + '", %(queriesSelector)s})', 'short'),
      hproc_threads: hsig('Threads', 'sum by (instance) (namedprocess_namegroup_num_threads{groupname=~"' + grp + '", %(queriesSelector)s})', 'short'),
      hproc_fds: hsig('Open file descriptors', 'sum by (instance) (namedprocess_namegroup_open_filedesc{groupname=~"' + grp + '", %(queriesSelector)s})', 'short'),
      hproc_fdRatio: hsig('Worst FD ratio', 'max by (instance) (namedprocess_namegroup_worst_fd_ratio{groupname=~"' + grp + '", %(queriesSelector)s})', 'percentunit'),
      hproc_uptime: hsig('Process uptime', 'time() - min by (instance) (namedprocess_namegroup_oldest_start_time_seconds{groupname=~"' + grp + '", %(queriesSelector)s})', 's'),
      hproc_ioRead: hsig('Process read', 'sum by (instance) (rate(namedprocess_namegroup_read_bytes_total{groupname=~"' + grp + '", %(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} read'),
      hproc_ioWrite: hsig('Process write', 'sum by (instance) (rate(namedprocess_namegroup_write_bytes_total{groupname=~"' + grp + '", %(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} write'),
      hproc_majFaults: hsig('Major page faults', 'sum by (instance) (rate(namedprocess_namegroup_major_page_faults_total{groupname=~"' + grp + '", %(queriesSelector)s}[$__rate_interval]))', 'short'),

      // ===== Process (the app's own process_* client metrics) =====
      proc_cpu: jsig('Process CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      proc_rss: jsig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} rss'),
      proc_virt: jsig('Virtual memory', 'process_virtual_memory_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} virtual'),
      proc_fds: jsig('Open file descriptors', 'process_open_fds{%(queriesSelector)s}', 'short'),
      proc_fdRatio: jsig('FD usage', 'process_open_fds{%(queriesSelector)s} / process_max_fds{%(queriesSelector)s}', 'percentunit'),
      proc_uptime: jsig('Uptime', 'time() - process_start_time_seconds{%(queriesSelector)s}', 's'),

      // ===== Windows (windows_exporter service + process collectors) =====
      win_state: hsig('Service state', 'max by (instance, name) ((windows_service_state{name=~"' + wsvc + '", state="running", %(queriesSelector)s} == 1) * 1 or (windows_service_state{name=~"' + wsvc + '", state=~"start pending|continue pending", %(queriesSelector)s} == 1) * 2 or (windows_service_state{name=~"' + wsvc + '", state=~"paused|pause pending|stop pending", %(queriesSelector)s} == 1) * 3 or (windows_service_state{name=~"' + wsvc + '", state="stopped", %(queriesSelector)s} == 1) * 4)', 'short', '{{instance}} {{name}}'),
      win_cpu: hsig('Process CPU', 'sum by (instance) (rate(windows_process_cpu_time_total{process=~"' + wproc + '", %(queriesSelector)s}[$__rate_interval]))', 'short'),
      win_workingSet: hsig('Working set', 'sum by (instance) (windows_process_working_set_private_bytes{process=~"' + wproc + '", %(queriesSelector)s} or windows_process_working_set_bytes{process=~"' + wproc + '", %(queriesSelector)s})', 'bytes'),
      win_handles: hsig('Handles', 'sum by (instance) (windows_process_handles{process=~"' + wproc + '", %(queriesSelector)s})', 'short'),
      win_threads: hsig('Threads', 'sum by (instance) (windows_process_threads{process=~"' + wproc + '", %(queriesSelector)s})', 'short'),
      win_io: hsig('Process IO', 'sum by (instance, mode) (rate(windows_process_io_bytes_total{process=~"' + wproc + '", %(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} {{mode}}'),
      win_uptime: hsig('Process uptime', 'time() - min by (instance) (windows_process_start_time{process=~"' + wproc + '", %(queriesSelector)s})', 's'),

      // ===== Logs (Loki) =====
      logs_pod: lsig('Pod logs', 'cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"'),
      logs_journal: lsig('Journal', 'instance=~"$host", unit=~"' + unit + '"'),
    };

    local unitMappings = stateMappings({
      '1': { text: 'active', color: 'green', index: 0 },
      '2': { text: 'transitioning', color: 'yellow', index: 1 },
      '3': { text: 'inactive', color: 'text', index: 2 },
      '4': { text: 'failed', color: 'red', index: 3 },
    });
    local winMappings = stateMappings({
      '1': { text: 'running', color: 'green', index: 0 },
      '2': { text: 'starting', color: 'yellow', index: 1 },
      '3': { text: 'paused/stopping', color: 'orange', index: 2 },
      '4': { text: 'stopped', color: 'red', index: 3 },
    });
    local timeline(title, sig, mappings) =
      panel.base('state-timeline', title)
      + panel.withTargets([sig.asTarget()])
      + panel.withOptions({ legend: { showLegend: false }, rowHeight: 0.85 })
      + panel.withFieldConfigDefaults({ custom: { fillOpacity: 72, lineWidth: 0 } })
      + panel.withMappings(mappings);

    // events of this service's pods and of the workload objects that own them
    // (deployment / replicaset / statefulset carry the workload name, not a pod).
    local kubeEvents(extra) =
      '{' + cfg.kubeEventsSelector + ', name=~"$pod|' + wl + '"' + extra + '}';

    // ----- annotations: firing alerts by severity + kubernetes events -----
    local alertAnn(sev) = annotations.base.target(cfg.datasource, 'ALERTS{alertstate="firing", severity="' + sev + '", ' + cfg.selector + '}');
    local annList = [
      annotations.critical.new('Critical alerts', alertAnn('critical')) + annotations.base.withTagKeys(['alertname', 'severity', 'pod', 'instance']),
      annotations.warning.new('Warning alerts', alertAnn('warning')) + annotations.base.withTagKeys(['alertname', 'severity', 'pod', 'instance']),
      annotations.info.new('Info alerts', alertAnn('info')) + annotations.base.withTagKeys(['alertname', 'severity', 'pod', 'instance']) + { spec+: { enable: false } },
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
           {
             title: 'Resources',
             elements: {
               k11_cpu: signals.kube_cpu.asTimeSeries('CPU: usage vs requests / limits')
                        + panel.withTargetsMixin([signals.kube_cpuRequests.asTarget(), signals.kube_cpuLimits.asTarget()])
                        + dashed('/ (requests|limits)$/'),
               k12_mem: signals.kube_mem.asTimeSeries('Memory: working set vs requests / limits')
                        + panel.withTargetsMixin([signals.kube_memRequests.asTarget(), signals.kube_memLimits.asTarget()])
                        + dashed('/ (requests|limits)$/'),
               k13_restarts: signals.kube_restarts.asTimeSeries('Container restarts (total)'),
               k14_phase: signals.kube_phase.asTimeSeries('Pods by phase'),
               k15_waiting: signals.kube_waiting.asTimeSeries('Containers waiting by reason'),
               k16_pvc: signals.kube_pvcUsage.asTimeSeries('PVC usage (namespace)'),
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
         ],
       }, {
         title: 'Containers',
         presence: { query: 'container_cpu_usage_seconds_total{' + cfg.kubeSelector + ', container!=""}', label: 'pod' },
         // the cadvisor observ-lib's full element set, scoped to these pods.
         elements: embed('cadvisor_', cadvisorLib.new({ datasource: cfg.datasource, selector: cfg.kubeSelector, docTabs: false }).grafana.elements),
       } + charts] else [])
      + (if cfg.docker.enabled then [{
           title: 'Docker',
           presence: { query: 'container_last_seen{' + cfg.hostSelector + ', name=~"' + cfg.docker.container + '"}', label: 'instance' },
           elements: embed('docker_', dockerLib.new({ datasource: cfg.datasource, selector: cfg.hostSelector + ', name=~"' + cfg.docker.container + '"', docTabs: false }).grafana.elements),
         } + charts] else [])
      + (if cfg.systemd.enabled then [{
           title: 'systemd',
           presence: { query: 'node_systemd_unit_state{' + cfg.hostSelector + ', name=~"' + unit + '"}', label: 'instance' },
           groups: [
             { title: 'State', elements: {
               s01_active: signals.systemd_active.asStat('Active'),
               s02_failed: signals.systemd_failed.asStat('Failed') + red1,
               s03_hosts: signals.systemd_hosts.asStat('Hosts'),
             } } + stats,
             { title: 'Units', elements: {
               s11_state: timeline('Unit state', signals.systemd_state, unitMappings),
             } } + wide,
           ],
         }] else [])
      + (if cfg.process.enabled then [{
           title: 'Host process',
           presence: { query: 'namedprocess_namegroup_num_procs{' + cfg.hostSelector + ', groupname=~"' + grp + '"}', label: 'instance' },
           groups: [
             { title: 'Overview', elements: {
               h01_procs: signals.hproc_procs.asStat('Processes'),
               h02_threads: signals.hproc_threads.asStat('Threads'),
               h03_fds: signals.hproc_fds.asStat('Open file descriptors'),
               h04_fdRatio: signals.hproc_fdRatio.asStat('Worst FD ratio'),
               h05_uptime: signals.hproc_uptime.asStat('Uptime'),
             } } + stats,
             { title: 'Usage', elements: {
               h11_cpu: signals.hproc_cpu.asTimeSeries('CPU (cores)'),
               h12_rss: signals.hproc_rss.asTimeSeries('Resident memory'),
               h13_io: signals.hproc_ioRead.asTimeSeries('Disk read / write')
                       + panel.withTargetsMixin([signals.hproc_ioWrite.asTarget()]),
               h14_majFaults: signals.hproc_majFaults.asTimeSeries('Major page faults/s'),
             } } + charts,
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
      + (if cfg.golang then [{
           title: 'Go runtime',
           presence: { query: 'go_goroutines{' + cfg.selector + '}', label: 'instance' },
           elements: embed('go_', golangLib.new({ datasource: cfg.datasource, selector: cfg.selector }).grafana.elements),
         } + charts] else [])
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
      + (if cfg.logs then [{
           title: 'Logs',
           width: 24,
           height: 10,
           // no marker metric: shown when either query returns lines.
           elements: {
             l01_pod: panel.logs.new('Pod logs') + panel.logs.withTargets([signals.logs_pod.asTarget()]),
             l02_journal: panel.logs.new('Journal') + panel.logs.withTargets([signals.logs_journal.asTarget()]),
             l03_events: panel.logs.new('Kubernetes events')
                         + panel.logs.withTargets([query.loki.new('${loki_datasource}', kubeEvents('') + ' | logfmt | line_format "{{.type}} {{.kind}}/{{.name}} {{.reason}}: {{.msg}}"')]),
           },
         }] else [])
      + [{
        title: 'Alerts',
        alwaysShow: true,
        groups: [
          { title: 'Alerts', width: 12, height: 9, elements: {
            a01_list: alertPanels.list('Alerts', instanceFilter='{job=~"$job"}', groupMode='custom', groupBy=['alertname']),
            a02_timeline: alertPanels.timeline('Alert state', cfg.datasource, cfg.selector),
          } },
          { title: 'Firing', width: 24, height: 8, elements: {
            a11_firing: alertPanels.firingTable('Firing alerts', cfg.datasource, cfg.selector),
          } },
        ],
      }];

    // ----- variables: job + cascading kube identity off the whitebox metric, host off the platform markers -----
    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local multi = variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent;
    local hostIdentity = std.join('|', [unit, wsvc, cfg.docker.container]);
    local extraVars = [
      variable.query.new('cluster') + variable.query.withLabel('Cluster')
      + variable.query.withLabelValues('cluster', wbVarMetric + '{job=~"$job"}') + multi,
      variable.query.new('namespace') + variable.query.withLabel('Namespace')
      + variable.query.withLabelValues('namespace', wbVarMetric + '{job=~"$job", cluster=~"$cluster"}') + multi,
      variable.query.new('pod') + variable.query.withLabel('Pod')
      + variable.query.withLabelValues('pod', wbVarMetric + '{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}') + multi,
      // hosts where this service is a systemd unit, a windows service or a docker container.
      variable.query.new('host') + variable.query.withLabel('Host')
      + variable.query.withLabelValues('instance', '{__name__=~"node_systemd_unit_state|windows_service_state|container_last_seen", name=~"' + hostIdentity + '"}') + multi,
    ];

    local pcfg = cfg { varMetric: wbVarMetric, varLabels: [], lokiDatasource: cfg.logs };
    local built = pack.build(pcfg, wb.signals + signals, wb.grafana.groups, wb.prometheus.alerts, wb.prometheus.rules, tabs);
    built {
      whitebox: wb,
      grafana+: { dashboard: super.dashboard + dashboard.withVariablesMixin(extraVars) + dashboard.withAnnotationsMixin(annList) },
    },
}
