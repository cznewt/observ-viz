// observ-viz Rails pack (hand-written).
// Rails through yabeda-rails (rails_*): request rate and duration by
// controller action and status, and where the time goes, split into database,
// view rendering and calls to other services. Puma, Sidekiq and the process
// base come from runtimes.ruby.
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
      uid: 'observ-viz-rails',
      dashboardTitle: 'Rails',
      dashboardTags: ['rails', 'ruby', 'framework'],
      description: 'A Rails application as yabeda-rails reports it: requests by controller action and status, request duration percentiles, and the split of that time between the database, view rendering and outbound service calls.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'rails_requests_total',
      ruleSelector: '',
      legend: '{{controller}}#{{action}}',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-frameworks',
      folderTitle: 'Frameworks',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      requests: sig('Requests', 'sum(rate(rails_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'requests', desc='Requests per second the application handled.'),
      byStatus: sig('Requests by status', 'sum by (status) (rate(rails_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{status}}', desc='Requests per second by response status.'),
      byAction: sig('Requests by action', 'topk(10, sum by (controller, action) (rate(rails_requests_total{%(queriesSelector)s}[$__rate_interval])))', 'reqps', desc='The ten busiest controller actions.'),
      errorRate: sig('Error ratio', 'sum(rate(rails_requests_total{%(queriesSelector)s, status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(rails_requests_total{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'percentunit', 'errors', desc='Share of requests answered with a server error.'),
      p95: sig('Duration p95', 'histogram_quantile(0.95, sum by (le) (rate(rails_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='Slowest 5 percent of requests.'),
      p99: sig('Duration p99', 'histogram_quantile(0.99, sum by (le) (rate(rails_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Slowest 1 percent of requests.'),
      p95ByAction: sig('Duration p95 by action', 'topk(10, histogram_quantile(0.95, sum by (le, controller, action) (rate(rails_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval]))))', 's', desc='The ten slowest controller actions at p95.'),
      dbRuntime: sig('Database time p95', 'histogram_quantile(0.95, sum by (le) (rate(rails_db_runtime_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'database', desc='Time inside the database per request at p95.'),
      viewRuntime: sig('View time p95', 'histogram_quantile(0.95, sum by (le) (rate(rails_view_runtime_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'views', desc='Time spent rendering views per request at p95.'),
      extRuntime: sig('External service time p95', 'histogram_quantile(0.95, sum by (le) (rate(rails_ext_service_runtime_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'external services', desc='Time waiting on other services per request at p95.'),
      actionTable: sig('Actions', 'topk(20, sum by (controller, action, status) (rate(rails_requests_total{%(queriesSelector)s}[$__rate_interval])))', 'reqps', desc='Controller action and status breakdown.'),
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
          ov4_db: signals.dbRuntime.asStat('Database p95'),
        },
      } + stats,
      {
        title: 'Requests',
        elements: {
          byStatus: signals.byStatus.asTimeSeries('Requests/s by status'),
          byAction: signals.byAction.asTimeSeries('Requests/s by action'),
          duration: signals.p99.asTimeSeries('Request duration')
                    + panel.withTargetsMixin([signals.p95.asTarget()]),
          p95ByAction: signals.p95ByAction.asTimeSeries('Duration p95 by action'),
          actionTable: signals.actionTable.asTable('Actions by status'),
        },
      } + charts,
      {
        title: 'Where the time goes',
        elements: {
          breakdown: signals.dbRuntime.asTimeSeries('Time per request at p95')
                     + panel.withTargetsMixin([signals.viewRuntime.asTarget(), signals.extRuntime.asTarget()]),
        },
      } + charts,
    ], [
      alert.rule.group('rails', [
        alert.rule.new('RailsErrorRateHigh',
                       'sum by (job) (rate(rails_requests_total{status=~"5.."' + rsComma + '}[5m])) / clamp_min(sum by (job) (rate(rails_requests_total' + rsBrace + '[5m])), 0.001) > 0.05',
                       '10m',
                       'critical',
                       {},
                       { summary: 'More than 5 percent of requests to the Rails app on {{ $labels.job }} are failing.' }),
        alert.rule.new('RailsLatencyHigh',
                       'histogram_quantile(0.95, sum by (le, job) (rate(rails_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'The Rails app on {{ $labels.job }} answers its slowest 5 percent of requests in over a second.' }),
        alert.rule.new('RailsDatabaseTimeHigh',
                       'histogram_quantile(0.95, sum by (le, job) (rate(rails_db_runtime_seconds_bucket' + rsBrace + '[5m]))) > 0.5',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Requests on {{ $labels.job }} spend more than half a second in the database at p95.' }),
      ]),
    ], [
      alert.rule.group('rails.rules', [
        alert.rule.record('job:rails_requests:rate5m', 'sum by (job) (rate(rails_requests_total' + rsBrace + '[5m]))'),
        alert.rule.record('job:rails_request_duration_seconds:p95_5m', 'histogram_quantile(0.95, sum by (le, job) (rate(rails_request_duration_seconds_bucket' + rsBrace + '[5m])))'),
      ]),
    ]),
}
