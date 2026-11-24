// observ-viz F5 NGINX Ingress Controller pack (hand-written).
// The open-source NGINX Ingress Controller by F5 (nginx/kubernetes-ingress,
// Helm chart nginx-ingress), not the community ingress-nginx, which is
// networking.ingressNginx. Its metrics on :9113, all prefixed nginx_ingress_:
//   nginx_ingress_nginx_*       nginx's stub status: up, connections, requests
//   nginx_ingress_controller_*  reloads, worker processes, the work queue,
//                               Ingress resources
//   nginx_ingress_controller_upstream_server_response_latency_ms
//                               a histogram, only with -enable-latency-metrics
//                               (chart controller.enableLatencyMetrics): one
//                               series set per backend pod and status code,
//                               labelled service / resource_namespace /
//                               resource_name / pod_name.
// The histogram is the only per-Ingress signal: the open-source controller
// counts no requests per Ingress, and answers nginx gives without a backend
// (redirects, unknown hosts, auth) are not in it. Every series carries the
// controller's own cluster / namespace / pod / instance; the Ingress object is
// resource_namespace / resource_name. WebSocket sessions are recorded with code
// 101 and last as long as the session, so the latency signals and the latency
// alert leave them out (config.latencySelector).
//   g.libs.networking.nginxIngress.new({}).grafana.dashboard      (uid observ-viz-nginx-ingress)
//   g.libs.networking.nginxIngress.upstream(ds, 'resource_namespace=~"x", service=~"y"')
//     -> { stats: {..}, charts: {..} } per-Ingress element maps, for embedding
//   g.libs.networking.nginxIngress.controller(ds, 'cluster=~"$cluster"')
//     -> the same for the controller itself (reloads, workers, work queue)
// The deployed board is the combined NGINX board (webservers.nginx), which
// embeds both maps behind presence-gated tabs (ingressControllers: ['f5']).
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { query: gv.query + cv.query };

local latency = 'nginx_ingress_controller_upstream_server_response_latency_ms';
// a WebSocket session's "response time" is the whole session
local defaultLatencySelector = 'code!="101"';

// per-Ingress signals for a selector over the latency histogram (the board
// uses its variables, a service board its namespace + backend Service name).
local upstreamSignals(datasource, selector, latencySelector=defaultLatencySelector) = {
  local sig(name, expr, unit, legend, desc='') =
    signal.new(name, 'prometheus', datasource, expr, unit).filteringSelector(selector).withLegendFormat(legend).withDescription(desc),
  local reqRate(extra='') = 'rate(' + latency + '_count{%(queriesSelector)s' + extra + '}[$__rate_interval])',
  // no 5xx series at all is 0 %, not an empty panel
  local share(codes) =
    '(sum(' + reqRate(', code=~"' + codes + '"') + ') or 0 * sum(' + reqRate() + ')) / clamp_min(sum(' + reqRate() + '), 1e-9)',
  local quantile(q) =
    'histogram_quantile(' + q + ', sum by (le) (rate(' + latency + '_bucket{%(queriesSelector)s'
    + (if latencySelector != '' then ', ' + latencySelector else '') + '}[$__rate_interval]))) / 1000',
  rate: sig('Requests', 'sum(' + reqRate() + ')', 'reqps', 'requests', desc='Requests per second the controller passed to a backend for the selected Ingress objects, WebSocket handshakes included.'),
  byCode: sig('Requests by status', 'sum by (code) (' + reqRate() + ')', 'reqps', '{{code}}', desc="Requests per second by the backend's HTTP status code. 101 is a WebSocket session."),
  byIngress: sig('Requests by Ingress', 'sum by (resource_namespace, resource_name) (' + reqRate() + ')', 'reqps', '{{resource_namespace}}/{{resource_name}}', desc='Requests per second by Ingress object.'),
  byService: sig('Requests by Service', 'sum by (service) (' + reqRate() + ')', 'reqps', '{{service}}', desc='Requests per second by backend Service.'),
  byBackend: sig('Requests by backend pod', 'topk(10, sum by (service, pod_name) (' + reqRate() + '))', 'reqps', '{{service}} {{pod_name}}', desc='The ten busiest backend pods.'),
  err5xx: sig('5xx ratio', share('5..'), 'percentunit', '5xx', desc='Share of requests answered with a 5xx, including the 502 and 504 nginx records when a backend pod does not answer. The second line is the 4xx share.'),
  err4xx: sig('4xx ratio', share('4..'), 'percentunit', '4xx', desc='Share of requests the backends answered with a 4xx (auth, not found, bad requests).'),
  upstreamErrors: sig('Upstream errors', 'sum by (code) (' + reqRate(', code=~"502|503|504"') + ')', 'reqps', '{{code}}', desc='502 / 503 / 504 answers per second: the backend refused, was unavailable or timed out.'),
  p99: sig('Upstream p99', quantile('0.99'), 's', 'p99', desc="Time from nginx's connection to the backend to the last byte of the response: p99, p95 and p50. WebSocket sessions are left out."),
  p95: sig('Upstream p95', quantile('0.95'), 's', 'p95', desc='95th percentile of the backend response time.'),
  p50: sig('Upstream p50', quantile('0.50'), 's', 'p50', desc='Median backend response time.'),
  ingresses: sig('Ingresses', 'count(count by (resource_namespace, resource_name) (' + latency + '_count{%(queriesSelector)s}))', 'short', 'ingresses', desc='Ingress objects that have passed a request to a backend since the controller started.'),
  services: sig('Services', 'count(count by (service) (' + latency + '_count{%(queriesSelector)s}))', 'short', 'services', desc='Backend Services that have received a request since the controller started.'),
};

local errThresholds = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]);

// element maps built from those signals: a stat strip + charts.
local upstreamElements(s, prefix='') = {
  signals:: s,
  stats: {
    [prefix + 'u01_rate']: s.rate.asStat('Requests/s'),
    [prefix + 'u02_err5xx']: s.err5xx.asStat('5xx ratio') + errThresholds,
    [prefix + 'u03_err4xx']: s.err4xx.asStat('4xx ratio'),
    [prefix + 'u04_p99']: s.p99.asStat('Upstream p99'),
    [prefix + 'u05_ingresses']: s.ingresses.asStat('Ingresses'),
    [prefix + 'u06_services']: s.services.asStat('Services'),
  },
  charts: {
    [prefix + 'u11_byCode']: s.byCode.asTimeSeries('Requests/s by status'),
    [prefix + 'u12_byIngress']: s.byIngress.asTimeSeries('Requests/s by Ingress'),
    [prefix + 'u13_byService']: s.byService.asTimeSeries('Requests/s by Service'),
    [prefix + 'u14_errors']: s.err5xx.asTimeSeries('Error ratio')
                             + panel.withTargetsMixin([s.err4xx.asTarget()]),
    [prefix + 'u15_latency']: s.p99.asTimeSeries('Upstream response p50 / p95 / p99')
                              + panel.withTargetsMixin([s.p95.asTarget(), s.p50.asTarget()]),
    [prefix + 'u16_upstreamErrors']: s.upstreamErrors.asTimeSeries('Upstream errors (502/503/504)'),
    [prefix + 'u17_byBackend']: s.byBackend.asTimeSeries('Top backend pods'),
  },
};

// controller-level signals: the series carry the controller pod (instance),
// not an Ingress, so they take their own selector.
local controllerSignals(datasource, selector) = {
  local csig(name, expr, unit, legend='{{instance}}', desc='') =
    signal.new(name, 'prometheus', datasource, expr, unit).filteringSelector(selector).withLegendFormat(legend).withDescription(desc),
  nginxUp: csig('NGINX up', 'min(nginx_ingress_nginx_up{%(queriesSelector)s})', 'short', 'up', desc="1 while every controller reads its nginx's stub status. 0 means nginx is not running or not answering in that pod."),
  controllers: csig('Controllers', 'count(nginx_ingress_nginx_up{%(queriesSelector)s})', 'short', 'pods', desc='Controller pods reporting metrics.'),
  reloadOk: csig('Config reload ok', 'min(nginx_ingress_controller_nginx_last_reload_status{%(queriesSelector)s})', 'short', 'ok', desc='1 while the last nginx reload succeeded on every controller. 0 means nginx rejected the configuration the controller generated and keeps serving the previous one.'),
  reloadDuration: csig('Last reload duration', 'max(nginx_ingress_controller_nginx_last_reload_milliseconds{%(queriesSelector)s})', 'ms', 'last reload', desc='How long the last nginx reload took.'),
  reloads: csig('Reloads', 'sum by (reason) (increase(nginx_ingress_controller_nginx_reloads_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{reason}}', desc='Successful nginx reloads: endpoints (the pods behind a Service changed) or other (an Ingress, Secret or ConfigMap changed).'),
  reloadErrors: csig('Reload errors', 'sum by (instance) (increase(nginx_ingress_controller_nginx_reload_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='Failed nginx reloads per controller pod.'),
  workers: csig('Worker processes', 'sum by (generation) (nginx_ingress_controller_nginx_worker_processes_total{%(queriesSelector)s})', 'short', '{{generation}}', desc='nginx worker processes: current, and old ones still finishing their connections after a reload. Old workers that stay are held by long-lived connections such as WebSockets.'),
  queueDepth: csig('Work queue depth', 'sum by (instance) (nginx_ingress_controller_workqueue_depth{%(queriesSelector)s})', 'short', desc='Changes waiting for the controller to turn them into nginx configuration.'),
  queueWait: csig('Work queue wait p99', 'histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_workqueue_queue_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'wait p99', desc='How long a change waits in the queue before the controller takes it (p99). The second line is the time to process one change.'),
  queueWork: csig('Work item p99', 'histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_workqueue_work_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'work p99', desc='How long the controller takes to process one change, nginx reload included (p99).'),
  // every replica reports the same objects: max, not sum, over the pods
  resources: csig('Ingress resources', 'max by (cluster, type) (nginx_ingress_controller_ingress_resources_total{%(queriesSelector)s})', 'short', '{{cluster}} {{type}}', desc='Ingress objects the controller serves: regular, and master / minion for mergeable Ingresses.'),
  resourcesTotal: csig('Ingresses served', 'sum(max by (cluster, type) (nginx_ingress_controller_ingress_resources_total{%(queriesSelector)s}))', 'short', 'ingresses', desc='Ingress objects the controller serves.'),
};

local okMapping(bad) = panel.stat.withMappings([{ type: 'value', options: { '0': { text: bad, color: 'red', index: 0 }, '1': { text: 'ok', color: 'green', index: 1 } } }]);

// the controller's element maps: reload / nginx stats + controller charts.
local controllerElements(c, prefix='') = {
  signals:: c,
  stats: {
    [prefix + 'f01_reloadOk']: c.reloadOk.asStat('Config reload') + okMapping('FAILED'),
    [prefix + 'f02_nginxUp']: c.nginxUp.asStat('NGINX') + okMapping('DOWN'),
    [prefix + 'f03_controllers']: c.controllers.asStat('Controllers'),
    [prefix + 'f04_reloadDuration']: c.reloadDuration.asStat('Last reload took'),
    [prefix + 'f05_resources']: c.resourcesTotal.asStat('Ingresses served'),
  },
  charts: {
    [prefix + 'f11_reloads']: c.reloads.asTimeSeries('Reloads'),
    [prefix + 'f12_reloadErrors']: c.reloadErrors.asTimeSeries('Reload errors'),
    [prefix + 'f13_workers']: c.workers.asTimeSeries('Worker processes'),
    [prefix + 'f14_queueDepth']: c.queueDepth.asTimeSeries('Work queue depth'),
    [prefix + 'f15_queueLatency']: c.queueWait.asTimeSeries('Work queue wait / work p99')
                                   + panel.withTargetsMixin([c.queueWork.asTarget()]),
    [prefix + 'f16_resources']: c.resources.asTimeSeries('Ingress resources'),
  },
};

// nginx's own stub status (all traffic, with or without a backend), for the
// standalone board; the NGINX board reads the same series in its Server tab.
local nginxSignals(datasource, selector) = {
  local sig(name, expr, unit, legend='{{instance}}', desc='') =
    signal.new(name, 'prometheus', datasource, expr, unit).filteringSelector(selector).withLegendFormat(legend).withDescription(desc),
  local byPod(m) = 'sum by (instance) (' + m + '{%(queriesSelector)s})',
  local ratePod(m) = 'sum by (instance) (rate(' + m + '{%(queriesSelector)s}[$__rate_interval]))',
  requests: sig('nginx requests', ratePod('nginx_ingress_nginx_http_requests_total'), 'reqps', desc='Requests per second nginx handled, all of them: also the redirects, unknown hosts and other answers it gives without a backend.'),
  active: sig('Active connections', byPod('nginx_ingress_nginx_connections_active'), 'short', desc='Client connections currently open, idle keep-alive ones included.'),
  reading: sig('Reading', byPod('nginx_ingress_nginx_connections_reading'), 'short', '{{instance}} reading', desc='Connections where nginx is reading the request.'),
  writing: sig('Writing', byPod('nginx_ingress_nginx_connections_writing'), 'short', '{{instance}} writing', desc='Connections where nginx is writing a response.'),
  waiting: sig('Waiting', byPod('nginx_ingress_nginx_connections_waiting'), 'short', '{{instance}} waiting', desc='Idle keep-alive connections.'),
  accepted: sig('Accepted connections', ratePod('nginx_ingress_nginx_connections_accepted'), 'ops', '{{instance}} accepted', desc='Connections accepted per second.'),
  handled: sig('Handled connections', ratePod('nginx_ingress_nginx_connections_handled'), 'ops', '{{instance}} handled', desc='Connections handled per second. Lower than accepted means nginx dropped connections, usually at a resource limit.'),
  dropped: sig('Dropped connections', ratePod('nginx_ingress_nginx_connections_accepted') + ' - ' + ratePod('nginx_ingress_nginx_connections_handled'), 'ops', desc='Accepted minus handled: connections nginx let go.'),
};

local nginxElements(n) = {
  n01_requests: n.requests.asTimeSeries('nginx requests/s'),
  n02_connections: n.accepted.asTimeSeries('Connections/s') + panel.withTargetsMixin([n.handled.asTarget()]),
  n03_states: n.reading.asTimeSeries('Connection states') + panel.withTargetsMixin([n.writing.asTarget(), n.waiting.asTarget()]),
  n04_active: n.active.asTimeSeries('Active connections'),
  n05_dropped: n.dropped.asTimeSeries('Dropped connections/s'),
};

// the alerting + recording rules, for a static label filter (no dashboard vars)
local ruleGroups(ruleSelector, latencySelector) = {
  local rsBrace = if ruleSelector != '' then '{' + ruleSelector + '}' else '',
  local rsComma = if ruleSelector != '' then ', ' + ruleSelector else '',
  local latSel = std.join(', ', [s for s in [latencySelector, ruleSelector] if s != '']),
  local latBrace = if latSel != '' then '{' + latSel + '}' else '',
  local by = 'cluster, resource_namespace, resource_name',
  local ratio5xx = 'sum by (' + by + ') (rate(' + latency + '_count{code=~"5.."' + rsComma + '}[5m])) / sum by (' + by + ') (rate(' + latency + '_count' + rsBrace + '[5m]))',
  local p99 = 'histogram_quantile(0.99, sum by (le, ' + by + ') (rate(' + latency + '_bucket' + latBrace + '[5m])))',
  alerts: [
    alert.rule.group('nginx-ingress', [
      alert.rule.new(
        'NginxIngressReloadFailed',
        'nginx_ingress_controller_nginx_last_reload_status' + rsBrace + ' == 0',
        '5m',
        'critical',
        {},
        {
          summary: 'NGINX Ingress Controller {{ $labels.instance }} failed its last nginx reload and serves the previous configuration.',
          description: 'nginx rejected the configuration the controller generated, so every change since the last good reload (Ingresses, certificates, backend pods) is not live.',
        }
      ) + alert.rule.withRunbook(std.join('\n', [
        '### Meaning',
        '',
        'nginx refused the configuration the controller generated from the Ingress objects, Secrets and its ConfigMap. The controller keeps serving the last configuration that loaded, so every change since then is not live.',
        '',
        '### Impact',
        '',
        'Routes that worked keep working on the old configuration. New or changed Ingresses and renewed certificates are not served, and requests to pods that moved since the last good reload can fail with 502.',
        '',
        '### Diagnosis',
        '',
        '- The controller log names the directive nginx rejected: `kubectl -n <namespace> logs <pod> | grep -iE "reload|emerg|error"`.',
        '- The Ingress behind the change usually carries a warning event from the controller (`Rejected`, `AddedOrUpdatedWithError`): `kubectl get events -A --field-selector type=Warning`.',
        '- `kubectl -n <namespace> exec <pod> -- nginx -T` prints the configuration nginx is running.',
        '',
        '### Mitigation',
        '',
        '- Fix or revert the Ingress, Secret or ConfigMap change the log names. The controller reloads on the next change.',
        '- Check `kubectl describe ingress` on recently changed Ingresses: an invalid `nginx.org/*` annotation value rejects the whole Ingress.',
      ])),
      alert.rule.new(
        'NginxIngressReloadErrors',
        'increase(nginx_ingress_controller_nginx_reload_errors_total' + rsBrace + '[15m]) > 0',
        '5m',
        'warning',
        {},
        {
          summary: 'NGINX Ingress Controller {{ $labels.instance }} had failed nginx reloads in the last 15 minutes.',
          description: 'A reload failed even if a later one succeeded: a change was rejected at least once. NginxIngressReloadFailed fires as well while the last reload is still the failed one.',
        }
      ),
      alert.rule.new(
        'NginxIngressNginxDown',
        'nginx_ingress_nginx_up' + rsBrace + ' == 0',
        '5m',
        'critical',
        {},
        {
          summary: 'nginx in NGINX Ingress Controller {{ $labels.instance }} is not answering its status endpoint.',
          description: 'The controller cannot read the stub status of its own nginx: nginx is not running or not answering in that pod, so it cannot serve traffic either.',
        }
      ) + alert.rule.withRunbook(std.join('\n', [
        '### Meaning',
        '',
        'The controller process is running, but it cannot read the stub status of the nginx it manages in the same pod.',
        '',
        '### Impact',
        '',
        'An nginx that does not answer its status endpoint does not serve requests either: every Ingress this pod carries is down, unless another replica takes the traffic.',
        '',
        '### Diagnosis',
        '',
        '- `kubectl -n <namespace> logs <pod>`: nginx start errors (`emerg`, `bind() ... failed`) appear in the same log as the controller.',
        '- `kubectl -n <namespace> exec <pod> -- ps`: is there an `nginx: master process`?',
        '',
        '### Mitigation',
        '',
        '- If nginx cannot bind its ports (on CRI-O: the `net.ipv4.ip_unprivileged_port_start` sysctl, or a host port taken by another pod), fix that first.',
        '- Deleting the pod restarts nginx with a fresh configuration.',
      ])),
      alert.rule.new(
        'NginxIngressDroppingConnections',
        'rate(nginx_ingress_nginx_connections_accepted' + rsBrace + '[5m]) - rate(nginx_ingress_nginx_connections_handled' + rsBrace + '[5m]) > 0',
        '10m',
        'warning',
        {},
        {
          summary: 'nginx in NGINX Ingress Controller {{ $labels.instance }} is dropping connections it accepted.',
          description: 'nginx accepted connections it could not handle, usually at the worker_connections or file descriptor limit.',
        }
      ),
      alert.rule.new(
        'NginxIngressUpstream5xxRatio',
        ratio5xx + ' > 0.05',
        '10m',
        'warning',
        {},
        {
          summary: 'Ingress {{ $labels.resource_namespace }}/{{ $labels.resource_name }} answers more than 5% of requests with a 5xx.',
          description: 'The backends behind this Ingress answer with 5xx, or nginx records 502 / 504 because a backend pod does not answer. Requires the controller latency metrics (controller.enableLatencyMetrics).',
        }
      ),
      alert.rule.new(
        'NginxIngressUpstreamHighLatency',
        p99 + ' > 2000',
        '15m',
        'warning',
        {},
        {
          summary: 'Ingress {{ $labels.resource_namespace }}/{{ $labels.resource_name }} backend response p99 is above 2s.',
          description: 'The slowest 1% of backend responses behind this Ingress take more than 2 seconds (WebSocket sessions left out). Long polling or streaming endpoints also count as slow: leave them out with the latencySelector config. Requires the controller latency metrics (controller.enableLatencyMetrics).',
        }
      ),
    ]),
  ],
  rules: [
    alert.rule.group('nginx-ingress.rules', [
      alert.rule.record('ingress:nginx_ingress_upstream_requests:rate5m', 'sum by (' + by + ') (rate(' + latency + '_count' + rsBrace + '[5m]))'),
      alert.rule.record('ingress:nginx_ingress_upstream_5xx:ratio_rate5m', ratio5xx),
      alert.rule.record('ingress:nginx_ingress_upstream_latency_seconds:p99_5m', p99 + ' / 1000'),
    ]),
  ],
};

{
  // for embedding: the per-Ingress element maps for a selector over the
  // latency histogram (its own labels: resource_namespace / resource_name / service).
  upstream(datasource, selector, prefix='', latencySelector=defaultLatencySelector)::
    upstreamElements(upstreamSignals(datasource, selector, latencySelector), prefix),
  // for embedding: the controller element maps (reload / nginx stats +
  // controller charts) for a controller-level selector.
  controller(datasource, selector, prefix='')::
    controllerElements(controllerSignals(datasource, selector), prefix),
  // the latency histogram's name, for presence checks in a composing board
  latencyMetric:: latency,

  new(config={}):
    local cfg = {
      uid: 'observ-viz-nginx-ingress',
      dashboardTitle: 'NGINX Ingress Controller',
      dashboardTags: ['nginx-ingress', 'nginx', 'networking', 'kubernetes', 'app-level'],
      description: 'The F5 NGINX Ingress Controller (open source): backend traffic per Ingress from its upstream latency histogram (status codes, latency), nginx connections and requests, and the controller itself (config reloads, worker processes, work queue). The Traffic tab needs controller.enableLatencyMetrics.',
      datasource: '${datasource}',
      // controller-level series: job -> cluster -> instance (the controller pods)
      selector: 'job=~"$job", cluster=~"$cluster", instance=~"$instance"',
      varMetric: 'nginx_ingress_nginx_up',
      varLabels: ['cluster', 'instance'],
      // per-Ingress series add the Ingress object. The variable is
      // ingress_namespace, not namespace: the controller's own series carry
      // namespace (where the controller runs).
      upstreamSelector: self.selector + ', resource_namespace=~"$ingress_namespace", resource_name=~"$ingress"',
      // which histogram series count for latency (WebSocket sessions are not responses)
      latencySelector: defaultLatencySelector,
      // static label filter for the alerting/recording rules (no dashboard vars)
      ruleSelector: '',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table (one row per controller pod)
      overviewSignals: ['nginx_requests', 'nginx_active', 'upstream_rate', 'upstream_err5xx', 'upstream_p99', 'controller_reloadOk'],
      references: [
        { title: 'NGINX Ingress Controller metrics', url: 'https://docs.nginx.com/nginx-ingress-controller/logging-and-monitoring/prometheus/', description: 'the nginx_ingress_* metrics, latency metrics included' },
      ],
      folderPath: (import 'libs/common-lib/folders.libsonnet').ingress,
    } + config;

    local up = upstreamSignals(cfg.datasource, cfg.upstreamSelector, cfg.latencySelector);
    local ctl = controllerSignals(cfg.datasource, cfg.selector);
    local ngx = nginxSignals(cfg.datasource, cfg.selector);
    local upEls = upstreamElements(up);
    local ctlEls = controllerElements(ctl);
    local rules = ruleGroups(cfg.ruleSelector, cfg.latencySelector);

    // the per-Ingress variables, off the latency histogram ('.*' for All, so
    // the controller tabs keep working where the histogram is off)
    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local qvar(name, title, label, query) =
      variable.query.new(name)
      + variable.query.withLabel(title)
      + variable.query.withRangeValues(label, query)
      + variable.query.withMulti()
      + variable.query.withIncludeAll()
      + variable.query.withAllValue('.*')
      + allCurrent;
    local hist(m) = latency + '_count{' + m + '}';

    pack.build(cfg {
      extraVariables: [
        qvar('ingress_namespace', 'Ingress namespace', 'resource_namespace', hist(cfg.selector)),
        qvar('ingress', 'Ingress', 'resource_name', hist(cfg.selector + ', resource_namespace=~"$ingress_namespace"')),
      ],
    }, { ['upstream_' + k]: up[k] for k in std.objectFields(up) }
       + { ['controller_' + k]: ctl[k] for k in std.objectFields(ctl) }
       + { ['nginx_' + k]: ngx[k] for k in std.objectFields(ngx) }, [
      { title: 'Overview', width: 4, height: 4, elements: upEls.stats + ctlEls.stats },
      { title: 'Traffic', width: 12, height: 7, elements: upEls.charts },
      { title: 'NGINX', width: 12, height: 7, elements: nginxElements(ngx) },
      { title: 'Controller', width: 12, height: 7, elements: ctlEls.charts },
    ], rules.alerts, rules.rules),
}
