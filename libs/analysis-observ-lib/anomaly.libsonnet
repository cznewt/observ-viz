// observ-viz anomaly method (hand-written).
// Anomaly detection you can point at ANY series of any service, without that
// service owning a single anomaly metric: each series is compared with its own
// recent past. The baseline is the rolling mean over `baseline`, the band is
// the mean plus or minus `z` standard deviations over the same window, and the
// z-score is how many deviations the current value sits from that mean.
//
// Three ways to use it:
//   .new(cfg)            a board of its own
//   .elements(cfg, pfx)  a fragment - the element map to drop into someone
//                        else's board as a tab or a row
//   .alerts(cfg)         the alerting rule group, one rule per series
//
// cfg.series is the whole contract:
//   { key: 'rate', title: 'Request rate', unit: 'reqps',
//     expr: 'sum(rate(http_requests_total{%(queriesSelector)s}[$__rate_interval]))' }
local alert = import 'libs/common-lib/alert/main.libsonnet';
local anomalySources = import 'libs/analysis-observ-lib/sources.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

local defaults = {
  uid: 'observ-viz-anomaly',
  dashboardTitle: 'Anomaly method',
  dashboardTags: ['observ-viz', 'analysis', 'anomaly'],
  datasource: '${datasource}',
  selector: 'job=~"$job"',
  varLabels: [],
  legendLabels: [],
  tabbed: true,
  // the window the baseline is learned from, and how often it is sampled
  baseline: '1d',
  step: '5m',
  // how many standard deviations count as anomalous
  z: 3,
  // how long it has to stay out of band before the alert fires
  'for': '15m',
  severity: 'warning',
  // a name for the thing being watched, used in alert names and summaries
  service: 'service',
  // static label filter for the rules (they cannot use dashboard variables)
  ruleSelector: '',
  // the three numbers every Prometheus client exposes, so `new({})` renders
  series: anomalySources.anomaly.process.series,
};

// the four expressions each series turns into. `sel` is what goes inside the
// metric's own selector; `rate` is the range a rate() in the expr should use
// (an alert cannot use $__rate_interval).
local exprs(cfg, s, sel, rate) = {
  local raw = std.strReplace(s.expr % { queriesSelector: sel, filteringSelector: sel }, '$__rate_interval', rate),
  local sub = '(' + raw + ')[' + cfg.baseline + ':' + cfg.step + ']',
  local mean = 'avg_over_time(' + sub + ')',
  local sd = 'stddev_over_time(' + sub + ')',
  value: raw,
  baseline: mean,
  // clamp_min keeps a flat series (stddev 0) from dividing by zero
  deviation: 'clamp_min(' + sd + ', 1e-9)',
  upper: mean + ' + ' + cfg.z + ' * ' + sd,
  lower: mean + ' - ' + cfg.z + ' * ' + sd,
  zscore: '((' + raw + ') - ' + mean + ') / clamp_min(' + sd + ', 1e-9)',
};

{
  local this = self,

  // the signals a series turns into, for composition
  signals(config={})::
    local cfg = defaults + config;
    local sel = filters.selector(cfg);
    local legend = filters.legendFormat(cfg);
    local sig(name, expr, unit, desc) =
      local s = signal.new(name, 'prometheus', cfg.datasource, expr, unit).withDescription(desc);
      if legend != null then s.withLegendFormat(legend) else s;
    std.foldl(function(acc, s) acc {
      [s.key]: sig(s.title, exprs(cfg, s, sel, '$__rate_interval').value, s.unit, 'The series as measured.'),
      [s.key + '_baseline']: sig(s.title + ' baseline', exprs(cfg, s, sel, '$__rate_interval').baseline, s.unit,
                                 'Its rolling mean over the last ' + cfg.baseline + '.'),
      [s.key + '_zscore']: sig(s.title + ' z-score', exprs(cfg, s, sel, '$__rate_interval').zscore, 'short',
                               'Standard deviations from that mean. Past ' + cfg.z + ' is what the alert calls anomalous.'),
    }, cfg.series, {}),

  // a board fragment: the element map, to drop into any other board
  elements(config={}, prefix='')::
    local cfg = defaults + config;
    local sel = filters.selector(cfg);
    local sigs = this.signals(config);
    local band(s) =
      local e = exprs(cfg, s, sel, '$__rate_interval');
      panel.timeSeries.new(s.title + ' against its baseline')
      + panel.timeSeries.withDescription('The series, its rolling mean over ' + cfg.baseline + ', and the band ' + cfg.z + ' standard deviations either side. Outside the band is what the alert calls anomalous.')
      + panel.timeSeries.withTargets([
        sigs[s.key].asTarget(),
        signal.new('Baseline', 'prometheus', cfg.datasource, e.baseline, s.unit).withLegendFormat('baseline').asTarget(),
        signal.new('Upper', 'prometheus', cfg.datasource, e.upper, s.unit).withLegendFormat('upper').asTarget(),
        signal.new('Lower', 'prometheus', cfg.datasource, e.lower, s.unit).withLegendFormat('lower').asTarget(),
      ])
      + panel.timeSeries.standardOptions.withUnit(s.unit)
      + panel.timeSeries.withFieldConfigDefaults({ custom: { fillOpacity: 0, lineWidth: 2, showPoints: 'never' } })
      + panel.timeSeries.withOverrides([{
        matcher: { id: 'byRegexp', options: '^(upper|lower|baseline)$' },
        properties: [
          { id: 'custom.lineStyle', value: { fill: 'dash', dash: [8, 8] } },
          { id: 'custom.lineWidth', value: 1 },
          { id: 'color', value: { mode: 'fixed', fixedColor: 'text' } },
        ],
      }]);
    local zpanel(s) =
      sigs[s.key + '_zscore'].asTimeSeries(s.title + ' z-score')
      + panel.timeSeries.withThresholds([
        { color: 'green', value: null },
        { color: 'orange', value: cfg.z },
        { color: 'red', value: cfg.z * 2 },
      ])
      + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } });
    std.foldl(function(acc, s) acc {
      [prefix + s.key + '_band']: band(s),
      [prefix + s.key + '_zscore']: zpanel(s),
    }, cfg.series, {}),

  // the alerting rule group: one rule per series, on the same z-score the
  // board draws, with the static rule selector rather than dashboard variables
  alerts(config={})::
    local cfg = defaults + config;
    local cap(x) = std.asciiUpper(std.substr(x, 0, 1)) + std.substr(x, 1, std.length(x));
    local name(x) = std.join('', [cap(w) for w in std.split(std.strReplace(x, '_', '-'), '-')]);
    [
      alert.rule.group('anomaly-' + cfg.service, [
        alert.rule.new(
          name(cfg.service) + name(s.key) + 'Anomalous',
          'abs(' + exprs(cfg, s, cfg.ruleSelector, '5m').zscore + ') > ' + cfg.z,
          cfg['for'],
          cfg.severity,
          {},
          {
            summary: s.title + ' on ' + cfg.service + ' is ' + cfg.z + ' standard deviations from its own ' + cfg.baseline + ' baseline.',
            description: 'Nothing here says the service is broken: the shape of ' + std.asciiLower(s.title) + ' changed against its own recent past. Compare it with the band on the board before acting, and check whether the change has an obvious cause (a deploy, a load test, a neighbour failing).',
          }
        )
        for s in cfg.series
      ]),
    ],

  // a board of its own: one tab per series
  new(config={})::
    local cfg = defaults + config;
    local els = this.elements(config);
    pack.build(cfg + {
      description: 'Every series below is compared with its own past: the rolling mean over ' + cfg.baseline + ' and a band ' + cfg.z + ' standard deviations wide. It owns no metrics - point it at any service.',
      references: [
        { title: 'Prometheus anomaly detection', url: 'https://prometheus.io/docs/prometheus/latest/querying/functions/#stddev_over_time', description: 'the functions this is built on' },
        { title: 'Subqueries', url: 'https://prometheus.io/docs/prometheus/latest/querying/basics/#subquery', description: 'how an arbitrary expression gets a rolling window' },
      ],
      overviewSignals: [s.key for s in cfg.series],
    }, this.signals(config), [
      {
        title: s.title,
        width: 12,
        height: 9,
        elements: { [s.key + '_band']: els[s.key + '_band'], [s.key + '_zscore']: els[s.key + '_zscore'] },
      }
      for s in cfg.series
    ], this.alerts(config)),
}
