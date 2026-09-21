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
//   Ingress       ingress-nginx requests, status codes, latency and bytes for the
//                 Ingress objects that route to this service
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
      // legend for the whitebox / app-process panels: the pod on kube. Set
      // '{{instance}}' for a host deployment.
      legend: '{{pod}}',
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
      description: def('description', cap(app) + ' as a service, wherever it runs: its own metrics first, then only the platform tabs that have data (Kubernetes, containers, Docker, systemd, process, ingress, Windows, logs), alerts and Kubernetes event annotations.'),
      // per-platform identity of this service (regexes, PromQL-anchored).
      kubernetes: plat('kubernetes', { enabled: true, workload: app + '.*' }),
      // ingress-nginx labels its series with the backend Service name.
      ingress: plat('ingress', { enabled: true, service: app + '.*' }),
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
      // ===== systemd (node_exporter systemd collector) =====
      systemd_state: hsig('Unit state', 'max by (instance, name) ((node_systemd_unit_state{name=~"' + unit + '", state="active", %(queriesSelector)s} == 1) * 1 or (node_systemd_unit_state{name=~"' + unit + '", state=~"activating|deactivating", %(queriesSelector)s} == 1) * 2 or (node_systemd_unit_state{name=~"' + unit + '", state="inactive", %(queriesSelector)s} == 1) * 3 or (node_systemd_unit_state{name=~"' + unit + '", state="failed", %(queriesSelector)s} == 1) * 4)', 'short', '{{instance}} {{name}}', desc='State of the systemd unit on every host where it exists: active, transitioning (activating/deactivating), inactive or failed (node_exporter systemd collector).'),
      systemd_active: hsig('Active units', 'count(node_systemd_unit_state{name=~"' + unit + '", state="active", %(queriesSelector)s} == 1)', 'short', 'active', desc='Hosts where the unit is active.'),
      systemd_failed: hsig('Failed units', 'count(node_systemd_unit_state{name=~"' + unit + '", state="failed", %(queriesSelector)s} == 1) or vector(0)', 'short', 'failed', desc='Hosts where the unit is in the failed state.'),
      systemd_hosts: hsig('Hosts', 'count(count by (instance) (node_systemd_unit_state{name=~"' + unit + '", %(queriesSelector)s}))', 'short', 'hosts', desc='Hosts that have the unit installed at all.'),
      // ===== Host process (process-exporter namedprocess_* by groupname) =====
      hproc_cpu: hsig('Process CPU', 'sum by (instance) (rate(namedprocess_namegroup_cpu_seconds_total{groupname=~"' + grp + '", %(queriesSelector)s}[$__rate_interval]))', 'short', desc='CPU cores used by the process group on each host (process-exporter, all processes of the group summed).'),
      hproc_rss: hsig('Process RSS', 'sum by (instance) (namedprocess_namegroup_memory_bytes{groupname=~"' + grp + '", memtype="resident", %(queriesSelector)s})', 'bytes', desc='Resident memory of the process group on each host.'),
      hproc_procs: hsig('Processes', 'sum by (instance) (namedprocess_namegroup_num_procs{groupname=~"' + grp + '", %(queriesSelector)s})', 'short', desc='Processes in the group per host. More than expected usually means forks or workers piling up.'),
      hproc_threads: hsig('Threads', 'sum by (instance) (namedprocess_namegroup_num_threads{groupname=~"' + grp + '", %(queriesSelector)s})', 'short', desc='Threads across the process group.'),
      hproc_fds: hsig('Open file descriptors', 'sum by (instance) (namedprocess_namegroup_open_filedesc{groupname=~"' + grp + '", %(queriesSelector)s})', 'short', desc='Open file descriptors across the process group.'),
      hproc_fdRatio: hsig('Worst FD ratio', 'max by (instance) (namedprocess_namegroup_worst_fd_ratio{groupname=~"' + grp + '", %(queriesSelector)s})', 'percentunit', desc='Open descriptors of the worst process divided by its soft limit. Near 1 the process starts failing with too many open files.'),
      hproc_uptime: hsig('Process uptime', 'time() - min by (instance) (namedprocess_namegroup_oldest_start_time_seconds{groupname=~"' + grp + '", %(queriesSelector)s})', 's', desc='Time since the oldest process of the group started.'),
      hproc_ioRead: hsig('Process read', 'sum by (instance) (rate(namedprocess_namegroup_read_bytes_total{groupname=~"' + grp + '", %(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} read', desc='Bytes read from storage by the process group per second.'),
      hproc_ioWrite: hsig('Process write', 'sum by (instance) (rate(namedprocess_namegroup_write_bytes_total{groupname=~"' + grp + '", %(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} write', desc='Bytes written to storage by the process group per second.'),
      hproc_majFaults: hsig('Major page faults', 'sum by (instance) (rate(namedprocess_namegroup_major_page_faults_total{groupname=~"' + grp + '", %(queriesSelector)s}[$__rate_interval]))', 'short', desc='Major page faults per second: the process is reading pages back from disk, a sign of memory pressure.'),
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
      // ===== Ingress (ingress-nginx, series carry the backend service name) =====
      ing_rate: isig('Requests', 'sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'requests', desc='Requests per second arriving through ingress-nginx for the Ingress objects that route to this service.'),
      ing_byStatus: isig('Requests by status', 'sum by (status) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{status}}', desc='Requests per second by HTTP status code returned to the client.'),
      ing_byHost: isig('Requests by host', 'sum by (host) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{host}}', desc='Requests per second by Ingress host name.'),
      ing_byPath: isig('Requests by path', 'topk(10, sum by (host, path) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval])))', 'reqps', '{{host}}{{path}}', desc='The ten busiest host and path combinations.'),
      ing_err5xx: isig('5xx ratio', 'sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s, status=~"5.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '5xx', desc='Share of requests answered with a 5xx as seen at the ingress (includes upstream failures and nginx 502/504 timeouts). The second line is the 4xx share.'),
      ing_err4xx: isig('4xx ratio', 'sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s, status=~"4.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '4xx', desc='Share of requests answered with a 4xx (client errors: auth, not found, bad requests).'),
      ing_p99: isig('Request p99', 'histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Request duration as measured by nginx from first byte in to last byte out: p99, p95 and p50.'),
      ing_p95: isig('Request p95', 'histogram_quantile(0.95, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='95th percentile of request duration at the ingress.'),
      ing_p50: isig('Request p50', 'histogram_quantile(0.50, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p50', desc='Median request duration at the ingress.'),
      ing_upstreamP99: isig('Upstream p99', 'histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_response_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'upstream p99', desc='Slowest 1 percent of upstream (backend) response times as seen by nginx. Compare with the request p99: a gap is time spent in nginx or on the client side.'),
      ing_bytesIn: isig('Request bytes', 'sum(rate(nginx_ingress_controller_request_size_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'in', desc='Request bytes received per second (in) and response bytes sent per second (out).'),
      ing_bytesOut: isig('Response bytes', 'sum(rate(nginx_ingress_controller_response_size_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'out', desc='Response bytes sent to clients per second.'),
      ing_hosts: isig('Hosts', 'count(count by (host) (nginx_ingress_controller_requests{%(queriesSelector)s}))', 'short', 'hosts', desc='Distinct host names currently serving traffic for this service.'),
      ing_ingresses: isig('Ingresses', 'count(count by (ingress) (nginx_ingress_controller_requests{%(queriesSelector)s}))', 'short', 'ingresses', desc='Distinct Ingress objects routing to this service.'),

      // ===== Logs (Loki) =====
      logs_pod: lsig('Pod logs', 'cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"', desc='Log lines of the selected pods, from Loki.'),
      logs_journal: lsig('Journal', 'instance=~"$host", unit=~"' + unit + '"', desc='Journal lines of the systemd unit on the selected hosts, from Loki.'),
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
      + panel.withDescription(sig._description)
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
      + (if cfg.ingress.enabled then [{
           title: 'Ingress',
           presence: { query: 'nginx_ingress_controller_requests{' + ingressSelector + '}', label: 'ingress' },
           groups: [
             { title: 'Overview', elements: {
               i01_rate: signals.ing_rate.asStat('Requests/s'),
               i02_err5xx: signals.ing_err5xx.asStat('5xx ratio'),
               i03_err4xx: signals.ing_err4xx.asStat('4xx ratio'),
               i04_p99: signals.ing_p99.asStat('Request p99'),
               i05_hosts: signals.ing_hosts.asStat('Hosts'),
               i06_ingresses: signals.ing_ingresses.asStat('Ingresses'),
             } } + stats,
             { title: 'Traffic', elements: {
               i11_byStatus: signals.ing_byStatus.asTimeSeries('Requests/s by status'),
               i12_byHost: signals.ing_byHost.asTimeSeries('Requests/s by host'),
               i13_byPath: signals.ing_byPath.asTimeSeries('Top paths'),
               i14_errors: signals.ing_err5xx.asTimeSeries('Error ratio')
                           + panel.withTargetsMixin([signals.ing_err4xx.asTarget()]),
               i15_latency: signals.ing_p99.asTimeSeries('Request duration p50 / p95 / p99')
                            + panel.withTargetsMixin([signals.ing_p95.asTarget(), signals.ing_p50.asTarget()]),
               i16_upstream: signals.ing_upstreamP99.asTimeSeries('Upstream response p99'),
               i17_bytes: signals.ing_bytesIn.asTimeSeries('Bytes in / out')
                          + panel.withTargetsMixin([signals.ing_bytesOut.asTarget()]),
             } } + charts,
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
