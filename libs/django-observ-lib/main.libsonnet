// observ-viz Django pack (hand-written).
// Django through korfuri/django-prometheus (django_http_*): requests and
// responses by view, method and status, latency with and without middleware,
// exceptions by view and type, and the body sizes moved. Runtime and process
// rows come from runtimes.python.
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
      uid: 'observ-viz-django',
      dashboardTitle: 'Django',
      dashboardTags: ['django', 'python', 'framework'],
      description: 'A Django application as django-prometheus reports it: requests by view and method, responses by status, latency measured inside and around the middleware stack, and exceptions by view and type.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'django_http_requests_before_middlewares_total',
      ruleSelector: '',
      legend: '{{view}}',
      docTabs: true,
      folderUid: 'software-frameworks',
      folderTitle: 'Frameworks',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      requests: sig('Requests', 'sum(rate(django_http_requests_before_middlewares_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'requests', desc='Requests per second entering the middleware stack.'),
      byMethod: sig('Requests by method', 'sum by (method) (rate(django_http_requests_total_by_method_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{method}}', desc='Requests per second by HTTP method.'),
      byView: sig('Requests by view', 'topk(10, sum by (view) (rate(django_http_requests_total_by_view_transport_method_total{%(queriesSelector)s}[$__rate_interval])))', 'reqps', desc='The ten busiest views.'),
      byStatus: sig('Responses by status', 'sum by (status) (rate(django_http_responses_total_by_status_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{status}}', desc='Responses per second by status code.'),
      errorRate: sig('Error ratio', 'sum(rate(django_http_responses_total_by_status_total{%(queriesSelector)s, status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(django_http_responses_total_by_status_total{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'percentunit', 'errors', desc='Share of responses that are server errors.'),
      p95: sig('Latency p95', 'histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='Slowest 5 percent of requests, measured in the view.'),
      p99: sig('Latency p99', 'histogram_quantile(0.99, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Slowest 1 percent of requests.'),
      p95ByView: sig('Latency p95 by view', 'topk(10, histogram_quantile(0.95, sum by (le, view) (rate(django_http_requests_latency_seconds_by_view_method_bucket{%(queriesSelector)s}[$__rate_interval]))))', 's', desc='The ten slowest views at p95.'),
      middlewareP95: sig('Latency p95 including middleware', 'histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_including_middlewares_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95 with middleware', desc='The same percentile measured around the whole middleware stack. A gap against the view latency is middleware cost.'),
      exceptionsByView: sig('Exceptions by view', 'sum by (view) (rate(django_http_exceptions_total_by_view_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', desc='Unhandled exceptions per second by view.'),
      exceptionsByType: sig('Exceptions by type', 'sum by (type) (rate(django_http_exceptions_total_by_type_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{type}}', desc='Unhandled exceptions per second by exception class.'),
      ajax: sig('AJAX requests', 'sum(rate(django_http_ajax_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'ajax', desc='Requests that arrived as XMLHttpRequest.'),
      requestBodies: sig('Request bodies', 'sum(rate(django_http_requests_body_total_bytes_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'request bodies', desc='Bytes of request bodies read per second.'),
      responseBodies: sig('Response bodies', 'sum(rate(django_http_responses_body_total_bytes_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'response bodies', desc='Bytes of response bodies written per second.'),
      viewTable: sig('Views', 'topk(20, sum by (view, method) (rate(django_http_requests_total_by_view_transport_method_total{%(queriesSelector)s}[$__rate_interval])))', 'reqps', '{{view}} {{method}}', desc='View and method breakdown.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_requests: signals.requests.asStat('Requests/s'),
          ov2_errors: signals.errorRate.asStat('Error ratio') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]),
          ov3_p95: signals.p95.asStat('Latency p95'),
          ov4_exceptions: signals.exceptionsByType.asStat('Exceptions/s') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.001 }]),
        },
      } + stats,
      {
        title: 'Requests',
        elements: {
          byStatus: signals.byStatus.asTimeSeries('Responses/s by status'),
          byMethod: signals.byMethod.asTimeSeries('Requests/s by method'),
          byView: signals.byView.asTimeSeries('Requests/s by view'),
          latency: signals.p99.asTimeSeries('Latency')
                   + panel.withTargetsMixin([signals.p95.asTarget(), signals.middlewareP95.asTarget()]),
          p95ByView: signals.p95ByView.asTimeSeries('Latency p95 by view'),
          viewTable: signals.viewTable.asTable('Views'),
        },
      } + charts,
      {
        title: 'Exceptions and payloads',
        elements: {
          exceptionsByType: signals.exceptionsByType.asTimeSeries('Exceptions/s by type'),
          exceptionsByView: signals.exceptionsByView.asTimeSeries('Exceptions/s by view'),
          payloads: signals.requestBodies.asTimeSeries('Body throughput')
                    + panel.withTargetsMixin([signals.responseBodies.asTarget()]),
          ajax: signals.ajax.asTimeSeries('AJAX requests/s'),
        },
      } + charts,
    ], [
      alert.rule.group('django', [
        alert.rule.new('DjangoErrorRateHigh',
                       'sum by (job) (rate(django_http_responses_total_by_status_total{status=~"5.."' + rsComma + '}[5m])) / clamp_min(sum by (job) (rate(django_http_responses_total_by_status_total' + rsBrace + '[5m])), 0.001) > 0.05',
                       '10m',
                       'critical',
                       {},
                       { summary: 'More than 5 percent of responses from the Django app on {{ $labels.job }} are server errors.' }),
        alert.rule.new('DjangoExceptions',
                       'sum by (job, view) (rate(django_http_exceptions_total_by_view_total' + rsBrace + '[10m])) > 0',
                       '10m',
                       'warning',
                       {},
                       { summary: 'View {{ $labels.view }} on {{ $labels.job }} keeps raising unhandled exceptions.' }),
        alert.rule.new('DjangoLatencyHigh',
                       'histogram_quantile(0.95, sum by (le, job) (rate(django_http_requests_latency_seconds_by_view_method_bucket' + rsBrace + '[5m]))) > 1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'The Django app on {{ $labels.job }} answers its slowest 5 percent of requests in over a second.' }),
      ]),
    ], [
      alert.rule.group('django.rules', [
        alert.rule.record('job:django_http_requests:rate5m', 'sum by (job) (rate(django_http_requests_before_middlewares_total' + rsBrace + '[5m]))'),
        alert.rule.record('job:django_http_errors:ratio5m',
                          'sum by (job) (rate(django_http_responses_total_by_status_total{status=~"5.."' + rsComma + '}[5m])) / clamp_min(sum by (job) (rate(django_http_responses_total_by_status_total' + rsBrace + '[5m])), 0.001)'),
      ]),
    ]),
}
