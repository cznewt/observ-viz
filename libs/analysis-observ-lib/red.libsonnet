// observ-viz RED method (hand-written).
// Rate, Errors and Duration for any instrumentation: point it at a source
// profile (libs/analysis-observ-lib/sources.libsonnet) and it builds the same
// three numbers - requests split into successes and failures, the share that
// failed, and the p99/p95/p50 of the latency histogram.
//
// Three ways to use it, like the anomaly method:
//   .new(cfg)            a board of its own, with a row per route repeated
//                        over the source's first dimension
//   .elements(cfg, pfx)  a fragment - the three panels as an element map, to
//                        drop into someone else's board
//   .alerts(cfg)         the rule group: failures, latency, traffic gone
local alert = import 'libs/common-lib/alert/main.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local sources = import 'libs/analysis-observ-lib/sources.libsonnet';

local defaults = {
  uid: 'observ-viz-red',
  dashboardTitle: 'RED method',
  dashboardTags: ['observ-viz', 'analysis', 'red'],
  datasource: '${datasource}',
  selector: 'job=~"$job"',
  varLabels: [],
  legendLabels: [],
  tabbed: true,
  // the shape most hand-instrumented services emit; override per board
  source: sources.red.prometheusClient,
  // repeat the three panels once per value of the source's first dimension
  perRoute: true,
  // what the rules watch. They cannot read dashboard variables, so they get
  // their own static selector.
  ruleSelector: '',
  errorRatio: 0.05,
  latency: 1,
  'for': '10m',
  severity: 'warning',
  service: 'service',
};

// the route dimension becomes a filter variable, and the source's request
// counter is where its values come from
local resolve(config) =
  local cfg = defaults + config;
  local dim = cfg.source.groupBy[0];
  cfg {
    varMetric: cfg.source.counter,
    varLabels: cfg.varLabels + (if cfg.perRoute && !std.member(cfg.varLabels, dim) then [dim] else []),
  };

// the expressions a source turns into. `sel` goes inside the metric selector,
// `rate` is the range a rate() uses (an alert cannot use $__rate_interval).
local exprs(cfg, sel, rate) = {
  local src = cfg.source,
  local by = std.join(', ', src.groupBy),
  local inSel(extra='') = '{' + sel + extra + '}',
  total: 'sum by (' + by + ') (rate(' + src.counter + inSel() + '[' + rate + ']))',
  errors:
    if std.objectHas(src, 'errorCounter')
    then 'sum by (' + by + ') (rate(' + src.errorCounter + inSel() + '[' + rate + ']))'
    else 'sum by (' + by + ') (rate(' + src.counter + inSel(', ' + src.errorSelector) + '[' + rate + ']))',
  success: '(' + self.total + ') - (' + self.errors + ')',
  // clamp_min so a route with no traffic reads 0, not NaN
  errorRatio: '(' + self.errors + ') / clamp_min(' + self.total + ', 1e-9)',
  quantile(q):: 'histogram_quantile(' + q + ', sum by (le, ' + by + ') (rate(' + src.bucket + inSel() + '[' + rate + '])))',
};

{
  local this = self,

  // the signal map, for composition
  signals(config={})::
    local cfg = resolve(config);
    local sel = filters.selector(cfg);
    local e = exprs(cfg, '%(queriesSelector)s', '$__rate_interval');
    local legendBy = std.join(' / ', ['{{' + l + '}}' for l in cfg.source.groupBy]);
    local sig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit)
      .filteringSelector(sel).withLegendFormat(legend).withDescription(desc);
    {
      requests: sig('Requests', e.total, 'reqps', legendBy, 'Requests per second.'),
      errors: sig('Errors', e.errors, 'reqps', legendBy, 'Requests per second that failed.'),
      success: sig('Successful', e.success, 'reqps', legendBy, 'Requests per second that did not fail.'),
      errorRatio: sig('Error ratio', e.errorRatio, 'percentunit', legendBy, 'Share of requests that failed.'),
      p50: sig('Duration p50', e.quantile('0.50'), 's', 'p50 ' + legendBy, 'Median request duration.'),
      p95: sig('Duration p95', e.quantile('0.95'), 's', 'p95 ' + legendBy, '95th percentile request duration.'),
      p99: sig('Duration p99', e.quantile('0.99'), 's', 'p99 ' + legendBy, '99th percentile request duration.'),
    },

  // a fragment: the three RED panels as an element map
  elements(config={}, prefix='')::
    local cfg = resolve(config);
    local sigs = this.signals(config);
    local legendBy = std.join(' / ', ['{{' + l + '}}' for l in cfg.source.groupBy]);
    {
      // 1. traffic, stacked into what succeeded and what did not
      [prefix + 'rate']:
        panel.timeSeries.new('Requests: successful and failed')
        + panel.timeSeries.withDescription('Requests per second, stacked: what succeeded and what did not.')
        + panel.timeSeries.withTargets([
          sigs.success.asTarget() + { spec+: { query+: { spec+: { legendFormat: 'success ' + legendBy } } } },
          sigs.errors.asTarget() + { spec+: { query+: { spec+: { legendFormat: 'error ' + legendBy } } } },
        ])
        + panel.timeSeries.standardOptions.withUnit('reqps')
        + panel.timeSeries.withFieldConfigDefaults({
          custom: { fillOpacity: 35, lineWidth: 1, stacking: { mode: 'normal', group: 'A' }, showPoints: 'never' },
        })
        + panel.timeSeries.withOverrides([
          { matcher: { id: 'byRegexp', options: '^error.*' }, properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'red' } }] },
          { matcher: { id: 'byRegexp', options: '^success.*' }, properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'green' } }] },
        ]),
      // 2. the share that failed, against the alert's threshold
      [prefix + 'errors']:
        sigs.errorRatio.asTimeSeries('Error ratio')
        + panel.timeSeries.withThresholds([
          { color: 'green', value: null },
          { color: 'red', value: cfg.errorRatio },
        ])
        + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } }),
      // 3. the three quantiles of the same requests
      [prefix + 'duration']:
        panel.timeSeries.new('Duration: p99, p95, p50')
        + panel.timeSeries.withDescription('Request duration from the latency histogram, three quantiles.')
        + panel.timeSeries.withTargets([sigs.p99.asTarget(), sigs.p95.asTarget(), sigs.p50.asTarget()])
        + panel.timeSeries.standardOptions.withUnit('s')
        + panel.timeSeries.withFieldConfigDefaults({ custom: { fillOpacity: 8, lineWidth: 2, showPoints: 'never' } }),
    },

  // the rule group: one rule per RED number
  alerts(config={})::
    local cfg = resolve(config);
    local e = exprs(cfg, cfg.ruleSelector, '5m');
    local cap(x) = std.asciiUpper(std.substr(x, 0, 1)) + std.substr(x, 1, std.length(x));
    local name(x) = std.join('', [cap(w) for w in std.split(std.strReplace(x, '_', '-'), '-')]);
    local dim = cfg.source.groupBy[0];
    [
      alert.rule.group('red-' + cfg.service, [
        alert.rule.new(
          name(cfg.service) + 'ErrorRatioHigh',
          '(' + e.errorRatio + ') > ' + cfg.errorRatio,
          cfg['for'],
          'critical',
          {},
          {
            summary: 'More than ' + (cfg.errorRatio * 100) + ' percent of requests to {{ $labels.' + dim + ' }} on ' + cfg.service + ' are failing.',
            description: 'The E of RED. Check what the failures have in common before looking at the service itself: one route, one client, one status code.',
          }
        ),
        alert.rule.new(
          name(cfg.service) + 'LatencyHigh',
          '(' + e.quantile('0.99') + ') > ' + cfg.latency,
          cfg['for'],
          cfg.severity,
          {},
          {
            summary: 'The slowest 1 percent of requests to {{ $labels.' + dim + ' }} on ' + cfg.service + ' take more than ' + cfg.latency + 's.',
            description: 'The D of RED. Compare it with p50 on the board: a gap that opens only at p99 is a queue or a slow dependency, not the service being uniformly slower.',
          }
        ),
        alert.rule.new(
          name(cfg.service) + 'TrafficGone',
          '(' + e.total + ') == 0 and (avg_over_time((' + e.total + ')[1h:5m]) > 0)',
          cfg['for'],
          cfg.severity,
          {},
          {
            summary: 'No requests are reaching {{ $labels.' + dim + ' }} on ' + cfg.service + ', which normally has some.',
            description: 'The R of RED. Silence can mean the service is fine and nobody is calling it, or that callers cannot reach it at all - check upstream before the service. Note the limit: this sees a counter that went quiet, not one that disappeared. A route whose series stops being exported entirely leaves nothing to compare, so pair this with an up/absent rule for the target itself.',
          }
        ),
      ]),
    ],

  // a board of its own
  new(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local dim = src.groupBy[0];
    local sigs = this.signals(config);
    local els = this.elements(config);
    pack.build(cfg + {
      description: 'The RED method over ' + std.asciiLower(src.title) + '. ' + src.description,
      references: [
        { title: 'The RED method', url: 'https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/', description: 'rate, errors, duration - what to measure for a request-driven service' },
        { title: 'Histograms and summaries', url: 'https://prometheus.io/docs/practices/histograms/', description: 'how the quantiles here are computed' },
      ],
      rowLabels: src.groupBy,
      overviewSignals: ['requests', 'errors', 'errorRatio', 'p95', 'p99'],
    }, sigs, [
      {
        title: 'RED',
        width: 12,
        height: 9,
        elements: { requests: els.rate, errorRatio: els.errors, duration: els.duration },
      },
    ] + (if cfg.perRoute then [
           {
             // the same three panels, once per selected value of the dimension
             title: 'Per ' + dim,
             repeat: dim,
             width: 8,
             height: 8,
             elements: { r_requests: els.rate, r_errorRatio: els.errors, r_duration: els.duration },
           },
         ] else []),
        this.alerts(config)),
}
