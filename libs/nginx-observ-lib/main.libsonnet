// observ-viz NGINX pack (hand-written).
// ONE board for every NGINX: open-source NGINX through
// nginx/nginx-prometheus-exporter (stub status: nginx_up, nginx_connections_*,
// nginx_http_requests_total) and the Kubernetes ingress-nginx controller
// (nginx_ingress_controller_*: per-Ingress requests / status / latency, config
// reloads, TLS expiry and its own nginx process). Tabs are presence-gated:
//   Overview         always: the instances of both kinds (server / ingress controller)
//   Server           nginx_up or nginx_ingress_controller_nginx_process_*: the
//                    stub-status view, from whichever source a target has
//   Ingress traffic  nginx_ingress_controller_build_info or _requests
//   Controller       same gate: reloads, certificates, nginx process
// The ingress tabs reuse networking.ingressNginx's element builders
// (ingress() / controller()) and its rules. That lib stays usable on its own
// (the service composer embeds it as its Ingress tab), but this board replaces
// its observ-viz-ingress-nginx board for deployment.
//   g.libs.webservers.nginx.new({}).grafana.dashboard          (uid observ-viz-nginx)
//   g.libs.webservers.nginx.new({ includeIngress: false })     stub status only
//   g.libs.webservers.nginx.elements(ds, 'job=~"x"')           stub-status element map
local panel = import 'custom/panel.libsonnet';
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local ingressLib = import 'libs/ingress-nginx-observ-lib/main.libsonnet';
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

{
  // for embedding: the stub-status element map for a selector.
  elements(datasource, selector, prefix='')::
    local e = stubElements(stubSignals(datasource, selector));
    { [prefix + k]: e[k] for k in std.objectFields(e) },

  new(config={}):
    local cfg = {
      uid: 'observ-viz-nginx',
      dashboardTitle: 'NGINX',
      dashboardTags: ['nginx', 'ingress-nginx', 'webserver', 'networking'],
      description: 'Every NGINX in one place: servers read through nginx-prometheus-exporter (stub status) and ingress-nginx controllers (their own metrics). The Overview lists both kinds; the Server tab shows requests and connections from whichever source a target has, and the Ingress traffic / Controller tabs appear only where an ingress-nginx controller is scraped.',
      datasource: '${datasource}',
      // one selector for the server view of both kinds: a stub-status series
      // and a controller series both carry job / instance (+ cluster in kube)
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
      // false: the stub-status board alone (no ingress tabs, rules or variables)
      includeIngress: true,
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // the Overview's instances table is this pack's own (both kinds, with a
      // Kind column), swapped in for the generated one below
      overviewSignals: ['ov_up', 'ov_requests', 'ov_active'],
      references: [
        { title: 'nginx-prometheus-exporter', url: 'https://github.com/nginx/nginx-prometheus-exporter', description: 'the stub-status nginx_* metrics' },
        { title: 'ingress-nginx monitoring', url: 'https://kubernetes.github.io/ingress-nginx/user-guide/monitoring/', description: 'the nginx_ingress_controller_* metrics' },
      ],
      folderPath: (import 'libs/common-lib/folders.libsonnet').ingress,
    } + config;
    local ingOn = cfg.includeIngress;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local ds = cfg.datasource;
    local sig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', ds, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    // the identity metrics of the two kinds: scope $job / $cluster / $instance
    local identity = ['nginx_up'] + (if ingOn then ['nginx_ingress_controller_build_info'] else []);
    local idSel(m) = '{__name__=~"' + std.join('|', identity) + '"' + m + '}';

    // ---- the server view, from either source ------------------------------
    // stub status is keyed by instance, a controller by controller_pod; the
    // controller half is relabelled to `instance` so one legend fits both.
    local asInstance(e) = 'label_replace(' + e + ', "instance", "$1", "controller_pod", "(.*)")';
    local either(stub, ctl) = if ingOn then '(' + stub + ') or ' + asInstance(ctl) else stub;
    local ctlConn(state) = 'sum by (controller_pod) (nginx_ingress_controller_nginx_process_connections{%(queriesSelector)s, state="' + state + '"})';
    local ctlConnRate(state) = 'sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_connections_total{%(queriesSelector)s, state="' + state + '"}[$__rate_interval]))';
    local ctlReq = 'sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_requests_total{%(queriesSelector)s}[$__rate_interval]))';
    local stubRate(m) = 'sum by (instance) (rate(' + m + '{%(queriesSelector)s}[$__rate_interval]))';
    local stubGauge(m) = 'sum by (instance) (' + m + '{%(queriesSelector)s})';
    local x = {
      requests: either(stubRate('nginx_http_requests_total'), ctlReq),
      accepted: either(stubRate('nginx_connections_accepted'), ctlConnRate('accepted')),
      handled: either(stubRate('nginx_connections_handled'), ctlConnRate('handled')),
      dropped: either(stubRate('nginx_connections_accepted') + ' - ' + stubRate('nginx_connections_handled'),
                      ctlConnRate('accepted') + ' - ' + ctlConnRate('handled')),
      perConn: either(stubRate('nginx_http_requests_total') + ' / clamp_min(' + stubRate('nginx_connections_handled') + ', 0.001)',
                      ctlReq + ' / clamp_min(' + ctlConnRate('handled') + ', 0.001)'),
      active: either(stubGauge('nginx_connections_active'), ctlConn('active')),
    };
    local srv = {
      up: sig('NGINX up',
              '(sum(nginx_up{%(queriesSelector)s}) or vector(0))'
              + (if ingOn then ' + (count(nginx_ingress_controller_build_info{%(queriesSelector)s}) or vector(0))' else ''),
              'short', 'up', 'NGINX servers whose stub status the exporter can read, plus running ingress-nginx controllers.'),
      requestsTotal: sig('Requests total', 'sum(' + x.requests + ')', 'reqps', 'requests', 'Requests per second over every NGINX shown.'),
      activeTotal: sig('Active connections total', 'sum(' + x.active + ')', 'short', 'active', 'Connections open over every NGINX shown.'),
      droppedTotal: sig('Dropped connections total', 'sum(' + x.dropped + ')', 'ops', 'dropped', 'Connections accepted but not handled, per second, over every NGINX shown.'),
      requests: sig('Requests', x.requests, 'reqps', '{{instance}}', "Requests per second per NGINX: nginx_http_requests_total from the stub status, or the controller's own nginx process counter."),
      accepted: sig('Accepted connections', x.accepted, 'ops', '{{instance}} accepted', 'Connections accepted per second.'),
      handled: sig('Handled connections', x.handled, 'ops', '{{instance}} handled', 'Connections handled per second. Lower than accepted means connections were dropped, usually at a resource limit.'),
      dropped: sig('Dropped connections', x.dropped, 'ops', '{{instance}}', 'Accepted minus handled: connections NGINX let go.'),
      requestsPerConnection: sig('Requests per connection', x.perConn, 'short', '{{instance}}', 'Requests served per connection: how well keep-alive is working.'),
      active: sig('Active connections', x.active, 'short', '{{instance}}', 'Connections currently open, including idle keep-alive ones.'),
      reading: sig('Reading', either(stubGauge('nginx_connections_reading'), ctlConn('reading')), 'short', '{{instance}} reading', 'Connections where NGINX is reading the request.'),
      writing: sig('Writing', either(stubGauge('nginx_connections_writing'), ctlConn('writing')), 'short', '{{instance}} writing', 'Connections where NGINX is writing a response.'),
      waiting: sig('Waiting', either(stubGauge('nginx_connections_waiting'), ctlConn('waiting')), 'short', '{{instance}} waiting', 'Idle keep-alive connections.'),
    };

    // ---- the Overview instances table: one row per NGINX, both kinds ------
    // every column is keyed by kind + target (the stub-status instance, or the
    // controller pod), so the per-query frames merge into one row per NGINX.
    local kinded(e, kind, from) = 'label_replace(label_replace(' + e + ', "target", "$1", "' + from + '", "(.*)"), "kind", "' + kind + '", "", "")';
    local both(stub, ctl) =
      kinded(stub, 'server', 'instance')
      + (if ingOn then ' or ' + kinded(ctl, 'ingress controller', 'controller_pod') else '');
    local ctlOnly(ctl) = kinded(ctl, 'ingress controller', 'controller_pod');
    local ov = {
      ov_up: sig('Up', both('max by (instance) (nginx_up{%(queriesSelector)s})', 'max by (controller_pod) (nginx_ingress_controller_build_info{%(queriesSelector)s})'), 'short', '{{kind}} {{target}}',
                 '1 while the stub status answers (server) or the controller reports its build info (ingress controller).'),
      ov_requests: sig('Req/s', both(stubRate('nginx_http_requests_total'), ctlReq), 'reqps', '{{kind}} {{target}}', 'Requests per second handled by the NGINX.'),
      ov_active: sig('Active connections', both(stubGauge('nginx_connections_active'), ctlConn('active')), 'short', '{{kind}} {{target}}', 'Connections currently open.'),
    } + (if ingOn then {
           ov_err5xx: sig('5xx %',
                          // no 5xx series at all is 0 %, not an empty cell
                          ctlOnly('(sum by (controller_pod) (rate(nginx_ingress_controller_requests{%(queriesSelector)s, status=~"5.."}[$__rate_interval])) or 0 * sum by (controller_pod) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))) / clamp_min(sum by (controller_pod) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval])), 1e-9)'),
                          'percentunit', '{{kind}} {{target}}', 'Share of requests answered with a 5xx (ingress controllers only: stub status has no status codes).'),
           ov_p95: sig('p95',
                       ctlOnly('histogram_quantile(0.95, sum by (le, controller_pod) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))'),
                       's', '{{kind}} {{target}}', '95th percentile request duration (ingress controllers only).'),
         } else {});
    local ovCols = ['ov_up', 'ov_requests', 'ov_active'] + (if ingOn then ['ov_err5xx', 'ov_p95'] else []);
    local nCols = std.length(ovCols);
    local valueName(i) = 'Value #' + std.char(std.codepoint('A') + i);
    local instancesTable =
      panel.table.new('Instances')
      + panel.table.withDescription('One row per NGINX: servers (stub status, keyed by instance) and ingress controllers (keyed by controller pod). 5xx % and p95 exist only for controllers.')
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

    local signals =
      { ['srv_' + k]: srv[k] for k in std.objectFields(srv) } + ov
      + (if ingOn then
           { ['ing_' + k]: ingr.signals[k] for k in std.objectFields(ingr.signals) }
           + { ['ctl_' + k]: ctlr.signals[k] for k in std.objectFields(ctlr.signals) }
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
        presence: presence(['nginx_up'] + (if ingOn then ['nginx_ingress_controller_nginx_process_connections'] else [])),
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
         ] else []);

    // ---- variables: job -> cluster -> instance [-> ingress_namespace -> ingress]
    // built here: the identity is a {__name__=~...} selector, which pack.build's
    // cascade (varMetric + '{...}') cannot extend
    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local qvar(name, title, label, query) =
      variable.query.new(name)
      + variable.query.withLabel(title)
      + variable.query.withLabelValues(label, query)
      + variable.query.withMulti()
      + variable.query.withIncludeAll()
      // .* also matches a series without the label (a server outside Kubernetes has no cluster)
      + variable.query.withAllValue('.*')
      + allCurrent;
    local reqSel(m) = 'nginx_ingress_controller_requests{' + m + '}';
    local vars = [
      qvar('cluster', 'Cluster', 'cluster', idSel(', job=~"$job"')),
      qvar('instance', 'Instance', 'instance', idSel(', job=~"$job", cluster=~"$cluster"')),
    ] + (if ingOn then [
           qvar('ingress_namespace', 'Ingress namespace', 'namespace', reqSel('job=~"$job", cluster=~"$cluster", instance=~"$instance"')),
           qvar('ingress', 'Ingress', 'ingress', reqSel('job=~"$job", cluster=~"$cluster", instance=~"$instance", namespace=~"$ingress_namespace"')),
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
         ] else []);

    local built = pack.build(cfg {
      varMetric: idSel(''),
      varLabels: [],
      extraVariables: vars,
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
    ] + (if ingOn then ingLib.prometheus.alerts else []), [
      alert.rule.group('nginx.rules', [
        alert.rule.record('instance:nginx_http_requests:rate5m', 'rate(nginx_http_requests_total' + rsBrace + '[5m])'),
      ]),
    ] + (if ingOn then ingLib.prometheus.rules else []), optionalTabs);
    built {
      grafana+: {
        // the pack's own instances table (both kinds, with a Kind column)
        elements+: { __instances: instancesTable },
        dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList),
      },
    },
}
