// observ-viz HTTP server instrumentation pack (hand-written).
// The rate, errors and duration of what a service serves, from whichever
// instrumentation it carries: OpenTelemetry semantic conventions
// (http_server_request_duration_seconds, http_server_active_requests,
// http_server_request_body_size_bytes) or the older Prometheus client-library
// convention (http_requests_total, http_request_duration_seconds). Every
// query unions both shapes, so a board works whichever one an app emits.
//   g.libs.instrumentation.httpServer.new({ selector: 'job="api"' })
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
      uid: 'observ-viz-http-server',
      dashboardTitle: 'HTTP server',
      dashboardTags: ['http', 'red', 'instrumentation'],
      description: 'What a service serves: requests per second, the share that fail, and how long they take, read from OpenTelemetry semantic conventions or from the older Prometheus client-library metrics, whichever the application emits.',
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal (process_*, go_*) cannot reach another component's
      // instances where the job label does not discriminate them
      selector: 'job=~"$job", instance=~"$instance"',
      varLabels: ['instance'],
      varMetric: 'http_server_request_duration_seconds_count',
      ruleSelector: '',
      legend: '{{instance}}',
      // the label carrying the response status in each convention
      statusLabel: 'http_response_status_code',
      legacyStatusLabel: 'code',
      routeLabel: 'http_route',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-instrumentation',
      folderTitle: 'Instrumentation',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    // %(queriesSelector)s is substituted per query, so both halves of a union
    // carry the board's selector.
    local both(otel, legacy) = '(' + otel + ') or (' + legacy + ')';

    local signals = {
      rps: sig('Requests', both(
        'sum(rate(http_server_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))',
        'sum(rate(http_requests_total{%(queriesSelector)s}[$__rate_interval]))'
      ), 'reqps', 'requests', desc='Requests per second the service handled.'),
      rpsByStatus: sig('Requests by status', both(
        'sum by (' + cfg.statusLabel + ') (rate(http_server_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))',
        'sum by (' + cfg.legacyStatusLabel + ') (rate(http_requests_total{%(queriesSelector)s}[$__rate_interval]))'
      ), 'reqps', '{{' + cfg.statusLabel + '}}{{' + cfg.legacyStatusLabel + '}}', desc='Requests per second split by response status.'),
      errorRate: sig('Error ratio', both(
        'sum(rate(http_server_request_duration_seconds_count{%(queriesSelector)s, ' + cfg.statusLabel + '=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(http_server_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])), 0.001)',
        'sum(rate(http_requests_total{%(queriesSelector)s, ' + cfg.legacyStatusLabel + '=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(http_requests_total{%(queriesSelector)s}[$__rate_interval])), 0.001)'
      ), 'percentunit', 'errors', desc='Share of requests answered with a server error. This is the number an availability objective is written against.'),
      clientErrorRate: sig('Client error ratio', both(
        'sum(rate(http_server_request_duration_seconds_count{%(queriesSelector)s, ' + cfg.statusLabel + '=~"4.."}[$__rate_interval])) / clamp_min(sum(rate(http_server_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])), 0.001)',
        'sum(rate(http_requests_total{%(queriesSelector)s, ' + cfg.legacyStatusLabel + '=~"4.."}[$__rate_interval])) / clamp_min(sum(rate(http_requests_total{%(queriesSelector)s}[$__rate_interval])), 0.001)'
      ), 'percentunit', 'client errors', desc='Share of requests rejected as a client error. A jump often means a broken caller or an expired credential.'),
      p50: sig('Duration p50', both(
        'histogram_quantile(0.50, sum by (le) (rate(http_server_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))',
        'histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))'
      ), 's', 'p50', desc='Median request duration.'),
      p95: sig('Duration p95', both(
        'histogram_quantile(0.95, sum by (le) (rate(http_server_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))',
        'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))'
      ), 's', 'p95', desc='Slowest 5 percent of requests.'),
      p99: sig('Duration p99', both(
        'histogram_quantile(0.99, sum by (le) (rate(http_server_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))',
        'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))'
      ), 's', 'p99', desc='Slowest 1 percent of requests, the tail users complain about.'),
      byRoute: sig('Requests by route', both(
        'topk(10, sum by (' + cfg.routeLabel + ') (rate(http_server_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])))',
        'topk(10, sum by (handler) (rate(http_requests_total{%(queriesSelector)s}[$__rate_interval])))'
      ), 'reqps', '{{' + cfg.routeLabel + '}}{{handler}}', desc='The ten busiest routes.'),
      slowestRoutes: sig('Slowest routes', both(
        'topk(10, histogram_quantile(0.95, sum by (le, ' + cfg.routeLabel + ') (rate(http_server_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval]))))',
        'topk(10, histogram_quantile(0.95, sum by (le, handler) (rate(http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval]))))'
      ), 's', '{{' + cfg.routeLabel + '}}{{handler}}', desc='The ten slowest routes at p95.'),
      inFlight: sig('Active requests', both(
        'sum(http_server_active_requests{%(queriesSelector)s})',
        'sum(http_requests_in_flight{%(queriesSelector)s})'
      ), 'short', 'in flight', desc='Requests being served right now. A rising floor means work arriving faster than it finishes.'),
      requestSize: sig('Request body size', 'sum(rate(http_server_request_body_size_bytes_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'request bodies', desc='Bytes of request bodies read per second.'),
      responseSize: sig('Response body size', 'sum(rate(http_server_response_body_size_bytes_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'response bodies', desc='Bytes of response bodies written per second.'),
      apdexTable: sig('Routes', both(
        'topk(20, sum by (' + cfg.routeLabel + ', ' + cfg.statusLabel + ') (rate(http_server_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])))',
        'topk(20, sum by (handler, ' + cfg.legacyStatusLabel + ') (rate(http_requests_total{%(queriesSelector)s}[$__rate_interval])))'
      ), 'reqps', '{{' + cfg.routeLabel + '}}{{handler}}', desc='Route and status breakdown.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_rps: signals.rps.asStat('Requests/s'),
          ov2_errors: signals.errorRate.asStat('Error ratio') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]),
          ov3_clientErrors: signals.clientErrorRate.asStat('Client error ratio'),
          ov4_p50: signals.p50.asStat('Duration p50'),
          ov5_p95: signals.p95.asStat('Duration p95'),
          ov6_inFlight: signals.inFlight.asStat('Active requests'),
        },
      } + stats,
      {
        title: 'Rate, errors, duration',
        elements: {
          rpsByStatus: signals.rpsByStatus.asTimeSeries('Requests/s by status'),
          errors: signals.errorRate.asTimeSeries('Error ratio')
                  + panel.withTargetsMixin([signals.clientErrorRate.asTarget()]),
          duration: signals.p99.asTimeSeries('Request duration')
                    + panel.withTargetsMixin([signals.p95.asTarget(), signals.p50.asTarget()]),
          inFlight: signals.inFlight.asTimeSeries('Active requests'),
        },
      } + charts,
      {
        title: 'Routes',
        elements: {
          byRoute: signals.byRoute.asTimeSeries('Requests/s by route'),
          slowestRoutes: signals.slowestRoutes.asTimeSeries('Slowest routes (p95)'),
          apdexTable: signals.apdexTable.asTable('Routes by status'),
          payloads: signals.requestSize.asTimeSeries('Body throughput')
                    + panel.withTargetsMixin([signals.responseSize.asTarget()]),
        },
      } + charts,
    ], [
      alert.rule.group('http-server', [
        alert.rule.new('HttpServerErrorRateHigh',
                       'sum by (job) (rate(http_server_request_duration_seconds_count{' + cfg.statusLabel + '=~"5.."' + rsComma + '}[5m])) / clamp_min(sum by (job) (rate(http_server_request_duration_seconds_count' + rsBrace + '[5m])), 0.001) > 0.05',
                       '10m',
                       'critical',
                       {},
                       { summary: 'More than 5 percent of requests to {{ $labels.job }} are failing with a server error.' }),
        alert.rule.new('HttpServerLatencyHigh',
                       'histogram_quantile(0.95, sum by (le, job) (rate(http_server_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'The slowest 5 percent of requests to {{ $labels.job }} take more than a second.' }),
        alert.rule.new('HttpServerNoTraffic',
                       'sum by (job) (rate(http_server_request_duration_seconds_count' + rsBrace + '[10m])) == 0',
                       '30m',
                       'info',
                       {},
                       { summary: '{{ $labels.job }} has served no requests for half an hour.' }),
      ]),
    ], [
      alert.rule.group('http-server.rules', [
        alert.rule.record('job:http_server_requests:rate5m', 'sum by (job) (rate(http_server_request_duration_seconds_count' + rsBrace + '[5m]))'),
        alert.rule.record('job:http_server_errors:ratio5m',
                          'sum by (job) (rate(http_server_request_duration_seconds_count{' + cfg.statusLabel + '=~"5.."' + rsComma + '}[5m])) / clamp_min(sum by (job) (rate(http_server_request_duration_seconds_count' + rsBrace + '[5m])), 0.001)'),
        alert.rule.record('job:http_server_duration_seconds:p95_5m',
                          'histogram_quantile(0.95, sum by (le, job) (rate(http_server_request_duration_seconds_bucket' + rsBrace + '[5m])))'),
      ]),
    ]),
}
