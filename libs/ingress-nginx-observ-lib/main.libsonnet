// observ-viz ingress-nginx pack (hand-written).
// Two views of the same controller metrics: per Ingress (requests, status
// codes, latency, bytes — series carry namespace/ingress/service/host/path)
// and the controller itself (config reloads, connections, nginx process).
//   g.libs.networking.ingressNginx.new({}).grafana.dashboard
//   g.libs.networking.ingressNginx.ingress(ds, 'namespace=~"x", service=~"y"')
//     -> { stats: {..}, charts: {..} } element maps for embedding in a service board
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

// per-Ingress signals for a selector (the board uses its variables, a service
// board its namespace + backend service name).
local ingressSignals(datasource, selector) = {
  local sig(name, expr, unit, legend, desc='') =
    signal.new(name, 'prometheus', datasource, expr, unit).filteringSelector(selector).withLegendFormat(legend).withDescription(desc),
  rate: sig('Requests', 'sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'requests', desc='Requests per second arriving through ingress-nginx for the selected Ingress objects.'),
  byStatus: sig('Requests by status', 'sum by (status) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{status}}', desc='Requests per second by HTTP status code returned to the client.'),
  byHost: sig('Requests by host', 'sum by (host) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{host}}', desc='Requests per second by Ingress host name.'),
  byIngress: sig('Requests by ingress', 'sum by (namespace, ingress) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{namespace}}/{{ingress}}', desc='Requests per second by Ingress object.'),
  byPath: sig('Requests by path', 'topk(10, sum by (host, path) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval])))', 'reqps', '{{host}}{{path}}', desc='The ten busiest host and path combinations.'),
  byMethod: sig('Requests by method', 'sum by (method) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{method}}', desc='Requests per second by HTTP method.'),
  err5xx: sig('5xx ratio', 'sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s, status=~"5.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '5xx', desc='Share of requests answered with a 5xx as seen at the ingress (includes upstream failures and nginx 502/503/504). The second line is the 4xx share.'),
  err4xx: sig('4xx ratio', 'sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s, status=~"4.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '4xx', desc='Share of requests answered with a 4xx (client errors: auth, not found, bad requests).'),
  upstreamErrors: sig('Upstream errors', 'sum by (status) (rate(nginx_ingress_controller_requests{%(queriesSelector)s, status=~"502|503|504"}[$__rate_interval]))', 'reqps', '{{status}}', desc='502/503/504 answers per second: the backend refused, was unavailable or timed out.'),
  p99: sig('Request p99', 'histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Request duration as measured by nginx from first byte in to last byte out: p99, p95 and p50.'),
  p95: sig('Request p95', 'histogram_quantile(0.95, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='95th percentile of request duration at the ingress.'),
  p50: sig('Request p50', 'histogram_quantile(0.50, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p50', desc='Median request duration at the ingress.'),
  upstreamP99: sig('Upstream p99', 'histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_response_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'upstream p99', desc='Slowest 1 percent of upstream (backend) response times as seen by nginx. Compare with the request p99: a gap is time spent in nginx or on the client side.'),
  bytesIn: sig('Request bytes', 'sum(rate(nginx_ingress_controller_request_size_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'in', desc='Request bytes received per second (in) and response bytes sent per second (out).'),
  bytesOut: sig('Response bytes', 'sum(rate(nginx_ingress_controller_response_size_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'out', desc='Response bytes sent to clients per second.'),
  hosts: sig('Hosts', 'count(count by (host) (nginx_ingress_controller_requests{%(queriesSelector)s}))', 'short', 'hosts', desc='Distinct host names currently serving traffic.'),
  ingresses: sig('Ingresses', 'count(count by (namespace, ingress) (nginx_ingress_controller_requests{%(queriesSelector)s}))', 'short', 'ingresses', desc='Distinct Ingress objects currently serving traffic.'),
};

// element maps built from those signals: a stat strip + charts.
local ingressElements(signals, prefix='') = {
  signals:: signals,
  stats: {
    [prefix + 'i01_rate']: signals.rate.asStat('Requests/s'),
    [prefix + 'i02_err5xx']: signals.err5xx.asStat('5xx ratio')
                             + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]),
    [prefix + 'i03_err4xx']: signals.err4xx.asStat('4xx ratio'),
    [prefix + 'i04_p99']: signals.p99.asStat('Request p99'),
    [prefix + 'i05_hosts']: signals.hosts.asStat('Hosts'),
    [prefix + 'i06_ingresses']: signals.ingresses.asStat('Ingresses'),
  },
  charts: {
    [prefix + 'i11_byStatus']: signals.byStatus.asTimeSeries('Requests/s by status'),
    [prefix + 'i12_byHost']: signals.byHost.asTimeSeries('Requests/s by host'),
    [prefix + 'i13_byPath']: signals.byPath.asTimeSeries('Top paths'),
    [prefix + 'i14_errors']: signals.err5xx.asTimeSeries('Error ratio')
                             + panel.withTargetsMixin([signals.err4xx.asTarget()]),
    [prefix + 'i15_latency']: signals.p99.asTimeSeries('Request duration p50 / p95 / p99')
                              + panel.withTargetsMixin([signals.p95.asTarget(), signals.p50.asTarget()]),
    [prefix + 'i16_upstream']: signals.upstreamP99.asTimeSeries('Upstream response p99'),
    [prefix + 'i17_upstreamErrors']: signals.upstreamErrors.asTimeSeries('Upstream errors (502/503/504)'),
    [prefix + 'i18_bytes']: signals.bytesIn.asTimeSeries('Bytes in / out')
                            + panel.withTargetsMixin([signals.bytesOut.asTarget()]),
  },
};

{
  // for embedding: the per-Ingress element maps for a selector.
  ingress(datasource, selector, prefix='')::
    ingressElements(ingressSignals(datasource, selector), prefix),

  new(config={}):
    local cfg = {
      uid: 'observ-viz-ingress-nginx',
      dashboardTitle: 'Ingress NGINX',
      dashboardTags: ['ingress-nginx', 'networking', 'kubernetes', 'app-level'],
      description: 'ingress-nginx: traffic per Ingress (requests, status codes, latency, bytes) and the controller itself (config reloads, connections, nginx process).',
      datasource: '${datasource}',
      // per-Ingress series: cluster -> namespace -> ingress cascade off the requests series.
      selector: 'cluster=~"$cluster", namespace=~"$namespace", ingress=~"$ingress"',
      varMetric: 'nginx_ingress_controller_requests',
      varLabels: ['cluster', 'namespace', 'ingress'],
      // controller-level series carry the controller pod, not an ingress.
      controllerSelector: 'cluster=~"$cluster"',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-networking',
      folderTitle: 'Networking',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local csig(name, expr, unit, legend='{{controller_pod}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.controllerSelector).withLegendFormat(legend).withDescription(desc);
    local ing = ingressSignals(cfg.datasource, cfg.selector);
    local ctl = {
      reloadOk: csig('Config reload ok', 'min(nginx_ingress_controller_config_last_reload_successful{%(queriesSelector)s})', 'short', 'ok', desc='1 while the last nginx configuration reload succeeded on every controller. 0 means a broken Ingress object left the controller serving a stale config.'),
      reloadAge: csig('Last reload', 'time() - max(nginx_ingress_controller_config_last_reload_successful_timestamp_seconds{%(queriesSelector)s})', 'dtdurations', 'since reload', desc='Time since the last successful configuration reload.'),
      controllers: csig('Controllers', 'count(nginx_ingress_controller_build_info{%(queriesSelector)s})', 'short', 'pods', desc='Running controller pods.'),
      connActive: csig('Connections', 'sum by (state) (nginx_ingress_controller_nginx_process_connections{%(queriesSelector)s})', 'short', '{{state}}', desc='Current nginx connections by state (active, reading, writing, waiting).'),
      connRate: csig('Connections accepted / handled', 'sum by (state) (rate(nginx_ingress_controller_nginx_process_connections_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{state}}', desc='Connections accepted and handled per second. Accepted above handled means nginx is refusing connections.'),
      nginxRequests: csig('nginx requests', 'sum(rate(nginx_ingress_controller_nginx_process_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'requests', desc='Requests per second handled by the nginx workers, all Ingress objects included.'),
      cpu: csig('Controller CPU', 'sum by (controller_pod) (rate(nginx_ingress_controller_nginx_process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='CPU cores used by the nginx worker processes per controller pod.'),
      rss: csig('Controller memory', 'sum by (controller_pod) (nginx_ingress_controller_nginx_process_resident_memory_bytes{%(queriesSelector)s})', 'bytes', desc='Resident memory of the nginx worker processes per controller pod.'),
      workers: csig('nginx workers', 'sum by (controller_pod) (nginx_ingress_controller_nginx_process_num_procs{%(queriesSelector)s})', 'short', desc='nginx worker processes per controller pod.'),
      certExpiry: csig('Certificate expiry', 'min by (host) (nginx_ingress_controller_ssl_expire_time_seconds{%(queriesSelector)s}) - time()', 'dtdurations', '{{host}}', desc='Time until each TLS certificate served by the controller expires (only for certificates the controller loads itself).'),
    };
    local els = ingressElements(ing);

    pack.build(cfg, ing + { ['controller_' + k]: ctl[k] for k in std.objectFields(ctl) }, [
      { title: 'Overview', width: 4, height: 4, elements: els.stats {
        i07_reloadOk: ctl.reloadOk.asStat('Config reload')
                      + panel.stat.withMappings([{ type: 'value', options: { '0': { text: 'FAILED', color: 'red', index: 0 }, '1': { text: 'ok', color: 'green', index: 1 } } }]),
        i08_reloadAge: ctl.reloadAge.asStat('Since last reload'),
        i09_controllers: ctl.controllers.asStat('Controllers'),
      } },
      { title: 'Traffic', width: 12, height: 7, elements: els.charts {
        i10_byIngress: ing.byIngress.asTimeSeries('Requests/s by ingress'),
        i19_byMethod: ing.byMethod.asTimeSeries('Requests/s by method'),
      } },
      { title: 'Controller', width: 12, height: 7, elements: {
        c01_connections: ctl.connActive.asTimeSeries('Connections by state'),
        c02_connRate: ctl.connRate.asTimeSeries('Connections accepted / handled'),
        c03_requests: ctl.nginxRequests.asTimeSeries('nginx requests/s'),
        c04_cpu: ctl.cpu.asTimeSeries('Controller CPU (cores)'),
        c05_rss: ctl.rss.asTimeSeries('Controller memory'),
        c06_workers: ctl.workers.asTimeSeries('nginx workers'),
        c07_certs: ctl.certExpiry.asTable('Certificate expiry'),
      } },
    ], [
      alert.rule.group('ingress-nginx', [
        alert.rule.new(
          'IngressNginxHigh5xxRatio',
          'sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{status=~"5.."' + rsComma + '}[5m])) / sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests' + rsBrace + '[5m])) > 0.05',
          '10m',
          'warning',
          {},
          { summary: 'Ingress {{ $labels.namespace }}/{{ $labels.ingress }} answers more than 5% of requests with a 5xx.' }
        ),
        alert.rule.new(
          'IngressNginxHighLatency',
          'histogram_quantile(0.99, sum by (le, cluster, namespace, ingress) (rate(nginx_ingress_controller_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 2',
          '15m',
          'warning',
          {},
          { summary: 'Ingress {{ $labels.namespace }}/{{ $labels.ingress }} request p99 latency is above 2s.' }
        ),
        alert.rule.new(
          'IngressNginxUpstreamErrors',
          'sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{status=~"502|503|504"' + rsComma + '}[5m])) > 0.1',
          '10m',
          'warning',
          {},
          { summary: 'Ingress {{ $labels.namespace }}/{{ $labels.ingress }} backend is failing: sustained 502/503/504 answers.' }
        ),
        alert.rule.new(
          'IngressNginxConfigReloadFailed',
          'nginx_ingress_controller_config_last_reload_successful' + rsBrace + ' == 0',
          '5m',
          'critical',
          {},
          { summary: 'ingress-nginx {{ $labels.controller_pod }} failed to reload its configuration; it is serving a stale config.' }
        ),
        alert.rule.new(
          'IngressNginxCertificateExpiringSoon',
          'nginx_ingress_controller_ssl_expire_time_seconds' + rsBrace + ' - time() < 14 * 24 * 3600',
          '1h',
          'warning',
          {},
          { summary: 'Certificate for {{ $labels.host }} served by ingress-nginx expires in less than 14 days.' }
        ),
      ]),
    ], [
      alert.rule.group('ingress-nginx.rules', [
        alert.rule.record('ingress:nginx_ingress_controller_requests:rate5m', 'sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests' + rsBrace + '[5m]))'),
        alert.rule.record('ingress:nginx_ingress_controller_5xx:ratio_rate5m', 'sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{status=~"5.."' + rsComma + '}[5m])) / sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests' + rsBrace + '[5m]))'),
        alert.rule.record('ingress:nginx_ingress_controller_request_duration_seconds:p99_5m', 'histogram_quantile(0.99, sum by (le, cluster, namespace, ingress) (rate(nginx_ingress_controller_request_duration_seconds_bucket' + rsBrace + '[5m])))'),
      ]),
    ]),
}
