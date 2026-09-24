// observ-viz Caddy pack (hand-written).
// Caddy's built-in metrics endpoint (caddy_http_*): requests, errors,
// duration and payload sizes per handler and host, plus requests in flight.
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
      uid: 'observ-viz-caddy',
      dashboardTitle: 'Caddy',
      dashboardTags: ['caddy', 'webserver'],
      description: 'Caddy from its own metrics: request rate by status and handler, duration percentiles, requests in flight, handler errors and payload sizes.',
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal (process_*, go_*) cannot reach another component's
      // instances where the job label does not discriminate them
      selector: 'job=~"$job", instance=~"$instance"',
      varLabels: ['instance'],
      varMetric: 'caddy_http_requests_total',
      ruleSelector: '',
      legend: '{{handler}}',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-webservers',
      folderTitle: 'Web servers',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      requests: sig('Requests', 'sum(rate(caddy_http_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'requests', desc='Requests per second Caddy served.'),
      byCode: sig('Requests by status', 'sum by (code) (rate(caddy_http_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{code}}', desc='Requests per second by response status.'),
      byHandler: sig('Requests by handler', 'topk(10, sum by (handler) (rate(caddy_http_requests_total{%(queriesSelector)s}[$__rate_interval])))', 'reqps', desc='The ten busiest handlers.'),
      errorRate: sig('Error ratio', 'sum(rate(caddy_http_requests_total{%(queriesSelector)s, code=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(caddy_http_requests_total{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'percentunit', 'errors', desc='Share of requests answered with a server error.'),
      handlerErrors: sig('Handler errors', 'sum by (handler) (rate(caddy_http_request_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', desc='Errors raised inside a handler, before a response was written.'),
      p95: sig('Duration p95', 'histogram_quantile(0.95, sum by (le) (rate(caddy_http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='Slowest 5 percent of requests.'),
      p99: sig('Duration p99', 'histogram_quantile(0.99, sum by (le) (rate(caddy_http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Slowest 1 percent of requests.'),
      inFlight: sig('Requests in flight', 'sum(caddy_http_requests_in_flight{%(queriesSelector)s})', 'short', 'in flight', desc='Requests being served right now.'),
      requestSize: sig('Request size', 'sum(rate(caddy_http_request_size_bytes_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'requests', desc='Bytes of requests read per second.'),
      responseSize: sig('Response size', 'sum(rate(caddy_http_response_size_bytes_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'responses', desc='Bytes of responses written per second.'),
      handlerTable: sig('Handlers', 'topk(20, sum by (handler, code) (rate(caddy_http_requests_total{%(queriesSelector)s}[$__rate_interval])))', 'reqps', desc='Handler and status breakdown.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_requests: signals.requests.asStat('Requests/s'),
          ov2_errors: signals.errorRate.asStat('Error ratio') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]),
          ov3_p95: signals.p95.asStat('Duration p95'),
          ov4_inFlight: signals.inFlight.asStat('In flight'),
        },
      } + stats,
      {
        title: 'Traffic',
        elements: {
          byCode: signals.byCode.asTimeSeries('Requests/s by status'),
          byHandler: signals.byHandler.asTimeSeries('Requests/s by handler'),
          duration: signals.p99.asTimeSeries('Request duration')
                    + panel.withTargetsMixin([signals.p95.asTarget()]),
          handlerErrors: signals.handlerErrors.asTimeSeries('Handler errors/s'),
          payloads: signals.requestSize.asTimeSeries('Payload throughput')
                    + panel.withTargetsMixin([signals.responseSize.asTarget()]),
          handlerTable: signals.handlerTable.asTable('Handlers by status'),
        },
      } + charts,
    ], [
      alert.rule.group('caddy', [
        alert.rule.new('CaddyErrorRateHigh',
                       'sum by (job) (rate(caddy_http_requests_total{code=~"5.."' + rsComma + '}[5m])) / clamp_min(sum by (job) (rate(caddy_http_requests_total' + rsBrace + '[5m])), 0.001) > 0.05',
                       '10m',
                       'warning',
                       {},
                       { summary: 'More than 5 percent of requests served by Caddy on {{ $labels.job }} fail.' }),
        alert.rule.new('CaddyLatencyHigh',
                       'histogram_quantile(0.95, sum by (le, job) (rate(caddy_http_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Caddy on {{ $labels.job }} serves its slowest 5 percent of requests in over a second.' }),
      ]),
    ], [
      alert.rule.group('caddy.rules', [
        alert.rule.record('job:caddy_http_requests:rate5m', 'sum by (job) (rate(caddy_http_requests_total' + rsBrace + '[5m]))'),
      ]),
    ]),
}
