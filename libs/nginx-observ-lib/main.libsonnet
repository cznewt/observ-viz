// observ-viz NGINX pack (hand-written).
// ONE board for every NGINX: open-source NGINX through
// nginx/nginx-prometheus-exporter (stub status: nginx_up, nginx_connections_*,
// nginx_http_requests_total) and two Kubernetes ingress controllers, chosen
// with config.ingressControllers (default both, each presence-gated):
//   'ingress-nginx'  the community ingress-nginx (nginx_ingress_controller_*:
//                    per-Ingress requests / status / latency, config reloads,
//                    TLS expiry and its own nginx process)
//   'f5'             the F5 NGINX Ingress Controller (nginx_ingress_nginx_*
//                    stub status, nginx_ingress_controller_* reloads / workers /
//                    work queue, per-Ingress backend traffic from its upstream
//                    latency histogram)
// Tabs:
//   Overview         always: the instances of every kind (server / controller)
//   Server           nginx_up or a controller's nginx: the stub-status view,
//                    from whichever source a target has
//   Ingress traffic  per controller kind, on that controller's own metrics
//   Controller       the same: reloads, workers, certificates, nginx process
// With both controllers on, the F5 tabs are "F5 ingress traffic" / "F5
// controller" and filter on their own f5_ingress_namespace / f5_ingress
// variables (the two controllers label the Ingress differently).
// The ingress tabs reuse networking.ingressNginx's and networking.nginxIngress's
// element builders (ingress() / upstream() / controller()) and their rules.
// Those libs stay usable on their own (the service composer embeds them as its
// Ingress tabs), but this board replaces their boards for deployment.
//   g.libs.webservers.nginx.new({}).grafana.dashboard          (uid observ-viz-nginx)
//   g.libs.webservers.nginx.new({ ingressControllers: ['f5'] })
//   g.libs.webservers.nginx.new({ ingressControllers: [] })     stub status only
//   g.libs.webservers.nginx.elements(ds, 'job=~"x"')           stub-status element map
local panel = import 'custom/panel.libsonnet';
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local ingressLib = import 'libs/ingress-nginx-observ-lib/main.libsonnet';
local f5Lib = import 'libs/nginx-ingress-observ-lib/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { query: gv.query + cv.query };

// the stub-status signals of nginx-prometheus-exporter, for a selector.
local stubSignals(datasource, selector, legend='{{instance}}') = {
  local sig(name, expr, unit, lg=legend, desc='') =
    signal.new(name, 'prometheus', datasource, expr, unit).filteringSelector(selector).withLegendFormat(lg).withDescription(desc),
  up: sig('NGINX up', 'sum(nginx_up{%(queriesSelector)s})', 'short', 'up', desc='Instances whose stub status the exporter can read.'),
  requests: sig('Requests', 'sum(rate(nginx_http_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'requests', desc='Requests per second.'),
  requestsByInstance: sig('Requests by instance', 'sum by (instance) (rate(nginx_http_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', desc='Requests per second per instance.'),
  active: sig('Active connections', 'nginx_connections_active{%(queriesSelector)s}', 'short', desc='Connections currently open, including idle keep-alive ones.'),
  accepted: sig('Accepted connections', 'rate(nginx_connections_accepted{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Connections accepted per second.'),
  handled: sig('Handled connections', 'rate(nginx_connections_handled{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Connections handled per second. Lower than accepted means connections were dropped, usually at a resource limit.'),
  dropped: sig('Dropped connections', 'rate(nginx_connections_accepted{%(queriesSelector)s}[$__rate_interval]) - rate(nginx_connections_handled{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Accepted minus handled: connections NGINX let go.'),
  reading: sig('Reading', 'nginx_connections_reading{%(queriesSelector)s}', 'short', desc='Connections where NGINX is reading the request.'),
  writing: sig('Writing', 'nginx_connections_writing{%(queriesSelector)s}', 'short', desc='Connections where NGINX is writing a response.'),
  waiting: sig('Waiting', 'nginx_connections_waiting{%(queriesSelector)s}', 'short', desc='Idle keep-alive connections.'),
  requestsPerConnection: sig('Requests per connection', 'rate(nginx_http_requests_total{%(queriesSelector)s}[$__rate_interval]) / clamp_min(rate(nginx_connections_handled{%(queriesSelector)s}[$__rate_interval]), 0.001)', 'short', desc='Requests served per connection: how well keep-alive is working.'),
};

// the stub-status element map (the standalone NGINX view, for embedding).
local stubElements(s) = {
  ov1_up: s.up.asStat('Instances up'),
  ov2_requests: s.requests.asStat('Requests/s'),
  ov3_active: s.active.asStat('Active connections'),
  ov4_dropped: s.dropped.asStat('Dropped connections/s') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.001 }]),
  requests: s.requestsByInstance.asTimeSeries('Requests/s'),
  connections: s.accepted.asTimeSeries('Connections/s')
               + panel.withTargetsMixin([s.handled.asTarget()]),
  dropped: s.dropped.asTimeSeries('Dropped connections/s'),
  requestsPerConnection: s.requestsPerConnection.asTimeSeries('Requests per connection'),
  states: s.reading.asTimeSeries('Connection states')
          + panel.withTargetsMixin([s.writing.asTarget(), s.waiting.asTarget()]),
  active: s.active.asTimeSeries('Active connections'),
};

local controllerKinds = ['ingress-nginx', 'f5'];

{
  // for embedding: the stub-status element map for a selector.
  elements(datasource, selector, prefix='')::
    local e = stubElements(stubSignals(datasource, selector));
    { [prefix + k]: e[k] for k in std.objectFields(e) },

  new(config={}):
    local cfg = {
      uid: 'observ-viz-nginx',
      dashboardTitle: 'NGINX',
      dashboardTags: ['nginx', 'ingress-nginx', 'nginx-ingress', 'webserver', 'networking'],
      description: 'Every NGINX in one place: servers read through nginx-prometheus-exporter (stub status) and the ingress controllers ingress-nginx and F5 NGINX Ingress (their own metrics). The Overview lists every kind; the Server tab shows requests and connections from whichever source a target has, and each controller kind gets Ingress traffic / Controller tabs that appear only where that controller is scraped.',
      datasource: '${datasource}',
      // one selector for the server view of every kind: a stub-status series
      // and a controller series all carry job / instance (+ cluster in kube)
      selector: 'job=~"$job", cluster=~"$cluster", instance=~"$instance"',
      // per-Ingress series add the Ingress object's namespace / name. The
      // variable is ingress_namespace, not namespace: a link carrying the
      // controller's own namespace (var-namespace) must not empty these tabs.
      ingressSelector: self.selector + ', namespace=~"$ingress_namespace", ingress=~"$ingress"',
      // firing-alert annotations: every alert this pack owns, by name (the
      // ingress alerts carry no job / instance to scope on)
      alertSelector: 'alertname=~"Nginx.*|IngressNginx.*"',
      // static label filter for the alerting/recording rules (no dashboard vars)
      ruleSelector: '',
      // the ingress controllers this board covers: 'ingress-nginx' (community)
      // and/or 'f5' (F5 NGINX Ingress Controller); [] = the stub-status board
      // alone (no ingress tabs, rules or variables). includeIngress: false is
      // the old spelling of [].
      ingressControllers: controllerKinds,
      // F5: which latency histogram series count for latency (WebSocket
      // sessions, code 101, last as long as the session)
      f5LatencySelector: 'code!="101"',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // the Overview's instances table is this pack's own (every kind, with a
      // Kind column), swapped in for the generated one below
      overviewSignals: ['ov_up', 'ov_requests', 'ov_active'],
      references: [
        { title: 'nginx-prometheus-exporter', url: 'https://github.com/nginx/nginx-prometheus-exporter', description: 'the stub-status nginx_* metrics' },
        { title: 'ingress-nginx monitoring', url: 'https://kubernetes.github.io/ingress-nginx/user-guide/monitoring/', description: 'the nginx_ingress_controller_* metrics' },
        { title: 'NGINX Ingress Controller metrics', url: 'https://docs.nginx.com/nginx-ingress-controller/logging-and-monitoring/prometheus/', description: 'the F5 controller nginx_ingress_* metrics, latency metrics included' },
      ],
      folderPath: (import 'libs/common-lib/folders.libsonnet').ingress,
    } + config;
    local ctrls =
      if std.objectHas(cfg, 'includeIngress') && !cfg.includeIngress then [] else cfg.ingressControllers;
    assert std.length([c for c in ctrls if std.count(controllerKinds, c) == 0]) == 0 :
           'webservers.nginx: ingressControllers takes ' + std.join(' and ', controllerKinds) + ', got ' + std.toString(ctrls);
    local ingOn = std.count(ctrls, 'ingress-nginx') > 0;
    local f5On = std.count(ctrls, 'f5') > 0;
    local anyIng = ingOn || f5On;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local ds = cfg.datasource;
    local sig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', ds, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    // the identity metrics of the kinds: scope $job / $cluster / $instance
    local identity =
      ['nginx_up']
      + (if ingOn then ['nginx_ingress_controller_build_info'] else [])
      + (if f5On then ['nginx_ingress_nginx_up'] else []);
    local idSel(m) = '{__name__=~"' + std.join('|', identity) + '"' + m + '}';
    // the F5 controller exports nginx's stub status under its own prefix
    local f5(m) = 'nginx_ingress_' + m;
    local f5Latency = f5Lib.latencyMetric;
    local f5LatSel = if cfg.f5LatencySelector != '' then ', ' + cfg.f5LatencySelector else '';

    // ---- the server view, from any source ---------------------------------
    // stub status (F5 included) is keyed by instance, an ingress-nginx
    // controller by controller_pod; that half is relabelled to `instance` so
    // one legend fits all.
    local asInstance(e) = 'label_replace(' + e + ', "instance", "$1", "controller_pod", "(.*)")';
    local stubRate(m) = 'sum by (instance) (rate(' + m + '{%(queriesSelector)s}[$__rate_interval]))';
    local stubGauge(m) = 'sum by (instance) (' + m + '{%(queriesSelector)s})';
    // stub(name-mapper) builds the stub-status form for nginx_* or F5's names
    local any(stub, ctl) =
      std.join(' or ', ['(' + stub(function(m) m) + ')']
                       + (if ingOn then [asInstance(ctl)] else [])
                       + (if f5On then ['(' + stub(f5) + ')'] else []));
    local ctlConn(state) = 'sum by (controller_pod) (nginx_ingress_controller_nginx_process_connections{%(queriesSelector)s, state="' + state + '"})';
    local ctlConnRate(state) = 'sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_connections_total{%(queriesSelector)s, state="' + state + '"}[$__rate_interval]))';
    local ctlReq = 'sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_requests_total{%(queriesSelector)s}[$__rate_interval]))';
    local x = {
      requests: any(function(n) stubRate(n('nginx_http_requests_total')), ctlReq),
      accepted: any(function(n) stubRate(n('nginx_connections_accepted')), ctlConnRate('accepted')),
      handled: any(function(n) stubRate(n('nginx_connections_handled')), ctlConnRate('handled')),
      dropped: any(function(n) stubRate(n('nginx_connections_accepted')) + ' - ' + stubRate(n('nginx_connections_handled')),
                   ctlConnRate('accepted') + ' - ' + ctlConnRate('handled')),
      perConn: any(function(n) stubRate(n('nginx_http_requests_total')) + ' / clamp_min(' + stubRate(n('nginx_connections_handled')) + ', 0.001)',
                   ctlReq + ' / clamp_min(' + ctlConnRate('handled') + ', 0.001)'),
      active: any(function(n) stubGauge(n('nginx_connections_active')), ctlConn('active')),
      reading: any(function(n) stubGauge(n('nginx_connections_reading')), ctlConn('reading')),
      writing: any(function(n) stubGauge(n('nginx_connections_writing')), ctlConn('writing')),
      waiting: any(function(n) stubGauge(n('nginx_connections_waiting')), ctlConn('waiting')),
    };
    local srv = {
      up: sig('NGINX up',
              '(sum(nginx_up{%(queriesSelector)s}) or vector(0))'
              + (if ingOn then ' + (count(nginx_ingress_controller_build_info{%(queriesSelector)s}) or vector(0))' else '')
              + (if f5On then ' + (sum(nginx_ingress_nginx_up{%(queriesSelector)s}) or vector(0))' else ''),
              'short', 'up', 'NGINX servers whose stub status the exporter can read, plus running ingress-nginx controllers and F5 controllers whose nginx answers.'),
      requestsTotal: sig('Requests total', 'sum(' + x.requests + ')', 'reqps', 'requests', 'Requests per second over every NGINX shown.'),
      activeTotal: sig('Active connections total', 'sum(' + x.active + ')', 'short', 'active', 'Connections open over every NGINX shown.'),
      droppedTotal: sig('Dropped connections total', 'sum(' + x.dropped + ')', 'ops', 'dropped', 'Connections accepted but not handled, per second, over every NGINX shown.'),
      requests: sig('Requests', x.requests, 'reqps', '{{instance}}', "Requests per second per NGINX: nginx_http_requests_total from the stub status (the F5 controller's nginx_ingress_nginx_http_requests_total), or the ingress-nginx controller's own nginx process counter."),
      accepted: sig('Accepted connections', x.accepted, 'ops', '{{instance}} accepted', 'Connections accepted per second.'),
      handled: sig('Handled connections', x.handled, 'ops', '{{instance}} handled', 'Connections handled per second. Lower than accepted means connections were dropped, usually at a resource limit.'),
      dropped: sig('Dropped connections', x.dropped, 'ops', '{{instance}}', 'Accepted minus handled: connections NGINX let go.'),
      requestsPerConnection: sig('Requests per connection', x.perConn, 'short', '{{instance}}', 'Requests served per connection: how well keep-alive is working.'),
      active: sig('Active connections', x.active, 'short', '{{instance}}', 'Connections currently open, including idle keep-alive ones.'),
      reading: sig('Reading', x.reading, 'short', '{{instance}} reading', 'Connections where NGINX is reading the request.'),
      writing: sig('Writing', x.writing, 'short', '{{instance}} writing', 'Connections where NGINX is writing a response.'),
      waiting: sig('Waiting', x.waiting, 'short', '{{instance}} waiting', 'Idle keep-alive connections.'),
    };

    // ---- the Overview instances table: one row per NGINX, every kind ------
    // every column is keyed by kind + target (the stub-status instance, the
    // ingress-nginx controller pod or the F5 controller instance), so the
    // per-query frames merge into one row per NGINX.
    local kinded(e, kind, from) = 'label_replace(label_replace(' + e + ', "target", "$1", "' + from + '", "(.*)"), "kind", "' + kind + '", "", "")';
    local ingKind = 'ingress-nginx';
    local f5Kind = 'F5 NGINX Ingress';
    local all(stub, ctl) =
      std.join(' or ', [kinded(stub(function(m) m), 'server', 'instance')]
                       + (if ingOn then [kinded(ctl, ingKind, 'controller_pod')] else [])
                       + (if f5On then [kinded(stub(f5), f5Kind, 'instance')] else []));
    // the controller-only columns (stub status has no status codes or latency)
    local ctlOnly(ing, f5e) =
      std.join(' or ', (if ingOn then [kinded(ing, ingKind, 'controller_pod')] else [])
                       + (if f5On then [kinded(f5e, f5Kind, 'instance')] else []));
    local f5Rate(extra) = 'sum by (instance) (rate(' + f5Latency + '_count{%(queriesSelector)s' + extra + '}[$__rate_interval]))';
    local ov = {
      ov_up: sig('Up', all(function(n) 'max by (instance) (' + n('nginx_up') + '{%(queriesSelector)s})', 'max by (controller_pod) (nginx_ingress_controller_build_info{%(queriesSelector)s})'), 'short', '{{kind}} {{target}}',
                 '1 while the stub status answers (server, F5 controller) or the controller reports its build info (ingress-nginx).'),
      ov_requests: sig('Req/s', all(function(n) stubRate(n('nginx_http_requests_total')), ctlReq), 'reqps', '{{kind}} {{target}}', 'Requests per second handled by the NGINX.'),
      ov_active: sig('Active connections', all(function(n) stubGauge(n('nginx_connections_active')), ctlConn('active')), 'short', '{{kind}} {{target}}', 'Connections currently open.'),
    } + (if anyIng then {
           ov_err5xx: sig('5xx %',
                          // no 5xx series at all is 0 %, not an empty cell
                          ctlOnly('(sum by (controller_pod) (rate(nginx_ingress_controller_requests{%(queriesSelector)s, status=~"5.."}[$__rate_interval])) or 0 * sum by (controller_pod) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))) / clamp_min(sum by (controller_pod) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval])), 1e-9)',
                                  '(' + f5Rate(', code=~"5.."') + ' or 0 * ' + f5Rate('') + ') / clamp_min(' + f5Rate('') + ', 1e-9)'),
                          'percentunit', '{{kind}} {{target}}', 'Share of requests answered with a 5xx (ingress controllers only: stub status has no status codes; on F5, backend answers from its latency histogram).'),
           ov_p95: sig('p95',
                       ctlOnly('histogram_quantile(0.95, sum by (le, controller_pod) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))',
                               'histogram_quantile(0.95, sum by (le, instance) (rate(' + f5Latency + '_bucket{%(queriesSelector)s' + f5LatSel + '}[$__rate_interval]))) / 1000'),
                       's', '{{kind}} {{target}}', '95th percentile request duration (ingress controllers only; on F5, the backend response time, WebSocket sessions left out).'),
         } else {});
    local ovCols = ['ov_up', 'ov_requests', 'ov_active'] + (if anyIng then ['ov_err5xx', 'ov_p95'] else []);
    local nCols = std.length(ovCols);
    local valueName(i) = 'Value #' + std.char(std.codepoint('A') + i);
    local instancesTable =
      panel.table.new('Instances')
      + panel.table.withDescription('One row per NGINX: servers (stub status, keyed by instance), ingress-nginx controllers (keyed by controller pod) and F5 controllers (keyed by instance). 5xx % and p95 exist only for controllers.')
      + panel.table.withTargets([ov[k].asTableTarget() for k in ovCols])
      + panel.table.withTransformations([
        { id: 'filterFieldsByName', options: { include: { names: ['kind', 'target'] + [valueName(i) for i in std.range(0, nCols - 1)] } } },
        // the frames share kind + target: merge them into one row per NGINX
        { id: 'merge', options: {} },
        { id: 'organize', options: {
          excludeByName: {},
          renameByName: { kind: 'Kind', target: 'Instance / pod' } + { [valueName(i)]: ov[ovCols[i]]._name for i in std.range(0, nCols - 1) },
          indexByName: { target: 0, kind: 1 } + { [valueName(i)]: 2 + i for i in std.range(0, nCols - 1) },
        } },
      ])
      + panel.table.withOverrides(
        [{ matcher: { id: 'byName', options: ov[k]._name }, properties: [{ id: 'unit', value: ov[k]._unit }] } for k in ovCols]
        + [{ matcher: { id: 'byName', options: 'Up' }, properties: [
          { id: 'mappings', value: [{ type: 'value', options: { '0': { text: 'down', color: 'red', index: 0 }, '1': { text: 'up', color: 'green', index: 1 } } }] },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ] }]
      );

    // ---- the ingress-nginx tabs (networking.ingressNginx builders) --------
    local ingr = ingressLib.ingress(ds, cfg.ingressSelector);
    local ctlr = ingressLib.controller(ds, cfg.selector);
    local ingLib = ingressLib.new({ datasource: ds, ruleSelector: cfg.ruleSelector, docTabs: false });

    // ---- the F5 tabs (networking.nginxIngress builders) -------------------
    // the F5 histogram names the Ingress resource_namespace / resource_name;
    // next to ingress-nginx it filters on variables of its own
    local f5Vars = if ingOn
    then { ns: 'f5_ingress_namespace', ing: 'f5_ingress', nsTitle: 'F5 Ingress namespace', ingTitle: 'F5 Ingress' }
    else { ns: 'ingress_namespace', ing: 'ingress', nsTitle: 'Ingress namespace', ingTitle: 'Ingress' };
    local f5Selector = cfg.selector + ', resource_namespace=~"$' + f5Vars.ns + '", resource_name=~"$' + f5Vars.ing + '"';
    local f5Up = f5Lib.upstream(ds, f5Selector, latencySelector=cfg.f5LatencySelector);
    local f5Ctl = f5Lib.controller(ds, cfg.selector);
    local f5Rules = f5Lib.new({ datasource: ds, ruleSelector: cfg.ruleSelector, latencySelector: cfg.f5LatencySelector, docTabs: false });
    // with both controllers the F5 tabs say so (two tabs of one title clash)
    local f5Title(t) = if ingOn then 'F5 ' + std.asciiLower(std.substr(t, 0, 1)) + std.substr(t, 1, std.length(t)) else t;

    local signals =
      { ['srv_' + k]: srv[k] for k in std.objectFields(srv) } + ov
      + (if ingOn then
           { ['ing_' + k]: ingr.signals[k] for k in std.objectFields(ingr.signals) }
           + { ['ctl_' + k]: ctlr.signals[k] for k in std.objectFields(ctlr.signals) }
         else {})
      + (if f5On then
           { ['f5u_' + k]: f5Up.signals[k] for k in std.objectFields(f5Up.signals) }
           + { ['f5c_' + k]: f5Ctl.signals[k] for k in std.objectFields(f5Ctl.signals) }
         else {});
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };
    local droppedStat(s, title) = s.asStat(title) + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.001 }]);
    // the hidden has_<tab> variable: label_values() over the tab's marker metrics
    local presence(metrics) = { label: 'job', query: '{__name__=~"' + std.join('|', metrics) + '", job=~"$job"}' };
    local ingressPresence = presence(['nginx_ingress_controller_build_info', 'nginx_ingress_controller_requests']);

    local optionalTabs = [
      {
        title: 'Server',
        presence: presence(['nginx_up']
                           + (if ingOn then ['nginx_ingress_controller_nginx_process_connections'] else [])
                           + (if f5On then ['nginx_ingress_nginx_connections_active'] else [])),
        groups: [
          { title: 'Summary', elements: {
            s01_up: srv.up.asStat('NGINX up'),
            s02_requests: srv.requestsTotal.asStat('Requests/s'),
            s03_active: srv.activeTotal.asStat('Active connections'),
            s04_dropped: droppedStat(srv.droppedTotal, 'Dropped connections/s'),
          } } + stats,
          { title: 'Traffic', elements: {
            s11_requests: srv.requests.asTimeSeries('Requests/s'),
            s12_connections: srv.accepted.asTimeSeries('Connections/s') + panel.withTargetsMixin([srv.handled.asTarget()]),
            s13_dropped: srv.dropped.asTimeSeries('Dropped connections/s'),
            s14_requestsPerConnection: srv.requestsPerConnection.asTimeSeries('Requests per connection'),
          } } + charts,
          { title: 'Connection states', elements: {
            s21_states: srv.reading.asTimeSeries('Connection states') + panel.withTargetsMixin([srv.writing.asTarget(), srv.waiting.asTarget()]),
            s22_active: srv.active.asTimeSeries('Active connections'),
          } } + charts,
        ],
      },
    ] + (if ingOn then [
           {
             title: 'Ingress traffic',
             presence: ingressPresence,
             groups: [
               { title: 'Summary', elements: ingr.stats } + stats,
               { title: 'Traffic', elements: ingr.charts {
                 i10_byIngress: ingr.signals.byIngress.asTimeSeries('Requests/s by ingress'),
                 i19_byMethod: ingr.signals.byMethod.asTimeSeries('Requests/s by method'),
               } } + charts,
             ],
           },
           {
             title: 'Controller',
             presence: ingressPresence,
             groups: [
               { title: 'Summary', elements: ctlr.stats } + stats,
               { title: 'Process', elements: ctlr.charts } + charts,
             ],
           },
         ] else [])
    + (if f5On then [
         {
           title: f5Title('Ingress traffic'),
           // only where the controller runs with its latency metrics on
           presence: presence([f5Latency + '_count']),
           groups: [
             { title: 'Summary', elements: f5Up.stats } + stats,
             { title: 'Traffic', elements: f5Up.charts } + charts,
           ],
         },
         {
           title: f5Title('Controller'),
           presence: presence(['nginx_ingress_nginx_up']),
           groups: [
             { title: 'Summary', elements: f5Ctl.stats } + stats,
             { title: 'Controller', elements: f5Ctl.charts } + charts,
           ],
         },
       ] else []);

    // ---- variables: job -> cluster -> instance [-> ingress_namespace -> ingress]
    // built here: the identity is a {__name__=~...} selector, which pack.build's
    // cascade (varMetric + '{...}') cannot extend
    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local qvar(name, title, label, query) =
      variable.query.new(name)
      + variable.query.withLabel(title)
      + variable.query.withRangeValues(label, query)
      + variable.query.withMulti()
      + variable.query.withIncludeAll()
      // .* also matches a series without the label (a server outside Kubernetes has no cluster)
      + variable.query.withAllValue('.*')
      + allCurrent;
    local reqSel(m) = 'nginx_ingress_controller_requests{' + m + '}';
    local f5Sel(m) = f5Latency + '_count{' + m + '}';
    local base = 'job=~"$job", cluster=~"$cluster", instance=~"$instance"';
    local vars = [
      qvar('cluster', 'Cluster', 'cluster', idSel(', job=~"$job"')),
      qvar('instance', 'Instance', 'instance', idSel(', job=~"$job", cluster=~"$cluster"')),
    ] + (if ingOn then [
           qvar('ingress_namespace', 'Ingress namespace', 'namespace', reqSel(base)),
           qvar('ingress', 'Ingress', 'ingress', reqSel(base + ', namespace=~"$ingress_namespace"')),
         ] else [])
    + (if f5On then [
         qvar(f5Vars.ns, f5Vars.nsTitle, 'resource_namespace', f5Sel(base)),
         qvar(f5Vars.ing, f5Vars.ingTitle, 'resource_name', f5Sel(base + ', resource_namespace=~"$' + f5Vars.ns + '"')),
       ] else []);

    // ---- annotations (viewer toggles): firing alerts by severity; controller
    // config reloads off until wanted
    local annList =
      annotations.alert.bySeverity(ds, cfg.alertSelector)
      + (if ingOn then [
           annotations.restart.new('Config reloads',
                                   annotations.base.target(ds, 'changes(nginx_ingress_controller_config_last_reload_successful_timestamp_seconds{' + cfg.selector + '}[$__interval]) > 0'),
                                   ['controller_pod'])
           + annotations.base.asToggle(false),
         ] else [])
      + (if f5On then [
           annotations.restart.new(if ingOn then 'F5 config reloads' else 'Config reloads',
                                   annotations.base.target(ds, 'sum by (instance, reason) (increase(nginx_ingress_controller_nginx_reloads_total{' + cfg.selector + '}[$__interval])) > 0'),
                                   ['instance', 'reason'])
           + annotations.base.asToggle(false),
         ] else []);

    local built = pack.build(cfg {
      varMetric: idSel(''),
      varLabels: [],
      extraVariables: vars,
      // the pods behind $job for the shared pod rows: pack.build would append
      // {job=~...} to the {__name__=~...} identity, which is no selector at all
      podMetric: idSel(', job=~"$job", pod!=""'),
    }, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_up: srv.up.asStat('NGINX up'),
          ov2_requests: srv.requestsTotal.asStat('Requests/s'),
          ov3_active: srv.activeTotal.asStat('Active connections'),
          ov4_dropped: droppedStat(srv.droppedTotal, 'Dropped connections/s'),
        } + (if ingOn then {
               ov5_err5xx: ingr.signals.err5xx.asStat('Ingress 5xx ratio')
                           + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]),
               ov6_reload: ctlr.stats.i07_reloadOk,
             } else {})
        + (if f5On then {
             ov7_f5Err5xx: f5Up.stats.u02_err5xx { spec+: { title: if ingOn then 'F5 5xx ratio' else 'Ingress 5xx ratio' } },
             ov8_f5Reload: f5Ctl.stats.f01_reloadOk { spec+: { title: if ingOn then 'F5 config reload' else 'Config reload' } },
           } else {}),
      } + stats,
    ], [
      alert.rule.group('nginx', [
        alert.rule.new('NginxDown',
                       'nginx_up' + rsBrace + ' == 0',
                       '5m',
                       'critical',
                       {},
                       { summary: 'NGINX on {{ $labels.instance }} is not answering its status endpoint.' }),
        alert.rule.new('NginxDroppingConnections',
                       'rate(nginx_connections_accepted' + rsBrace + '[5m]) - rate(nginx_connections_handled' + rsBrace + '[5m]) > 0',
                       '10m',
                       'warning',
                       {},
                       { summary: 'NGINX on {{ $labels.instance }} is dropping connections it accepted.' }),
      ]),
    ] + (if ingOn then ingLib.prometheus.alerts else [])
    + (if f5On then f5Rules.prometheus.alerts else []), [
      alert.rule.group('nginx.rules', [
        alert.rule.record('instance:nginx_http_requests:rate5m', 'rate(nginx_http_requests_total' + rsBrace + '[5m])'),
      ]),
    ] + (if ingOn then ingLib.prometheus.rules else [])
    + (if f5On then f5Rules.prometheus.rules else []), optionalTabs);
    built {
      grafana+: {
        // the pack's own instances table (every kind, with a Kind column)
        elements+: { __instances: instancesTable },
        dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList),
      },
    },
}
