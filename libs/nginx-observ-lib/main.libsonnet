// observ-viz NGINX pack (hand-written).
// Open-source NGINX through nginx/nginx-prometheus-exporter (nginx_*): the
// stub status connection counters, which is all open-source NGINX exposes.
// Per-route request metrics need NGINX Plus or the ingress controller, which
// networking.ingressNginx covers.
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  elements(datasource, selector, prefix='')::
    local p = $.new({ datasource: datasource, selector: selector, docTabs: false });
    { [prefix + k]: p.grafana.elements[k] for k in std.objectFields(p.grafana.elements) },

  new(config={}):
    local cfg = {
      uid: 'observ-viz-nginx',
      dashboardTitle: 'NGINX',
      dashboardTags: ['nginx', 'webserver'],
      description: 'NGINX from its stub status: requests handled, connections accepted, handled and active, and the reading, writing and waiting breakdown. A gap between accepted and handled connections means NGINX is dropping them.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'nginx_up',
      ruleSelector: '',
      legend: '{{instance}}',
      docTabs: true,
      folderUid: 'software-webservers',
      folderTitle: 'Web servers',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
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
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_up: signals.up.asStat('Instances up'),
          ov2_requests: signals.requests.asStat('Requests/s'),
          ov3_active: signals.active.asStat('Active connections'),
          ov4_dropped: signals.dropped.asStat('Dropped connections/s') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.001 }]),
        },
      } + stats,
      {
        title: 'Traffic',
        elements: {
          requests: signals.requestsByInstance.asTimeSeries('Requests/s'),
          connections: signals.accepted.asTimeSeries('Connections/s')
                       + panel.withTargetsMixin([signals.handled.asTarget()]),
          dropped: signals.dropped.asTimeSeries('Dropped connections/s'),
          requestsPerConnection: signals.requestsPerConnection.asTimeSeries('Requests per connection'),
        },
      } + charts,
      {
        title: 'Connection states',
        elements: {
          states: signals.reading.asTimeSeries('Connection states')
                  + panel.withTargetsMixin([signals.writing.asTarget(), signals.waiting.asTarget()]),
          active: signals.active.asTimeSeries('Active connections'),
        },
      } + charts,
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
    ], [
      alert.rule.group('nginx.rules', [
        alert.rule.record('instance:nginx_http_requests:rate5m', 'rate(nginx_http_requests_total' + rsBrace + '[5m])'),
      ]),
    ]),
}
