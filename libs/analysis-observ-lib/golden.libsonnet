// observ-viz four golden signals (hand-written).
// Latency, traffic, errors and saturation, the Google SRE set. RED covers the
// first three for a request-driven service; the fourth is the one that says
// how close the thing is to its limit, and it is the reason this method exists
// separately - saturation is what turns a healthy service into a failing one.
//
//   .new(cfg) .elements(cfg, pfx) .alerts(cfg)
local alert = import 'libs/common-lib/alert/main.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local sources = import 'libs/analysis-observ-lib/sources.libsonnet';

local defaults = {
  uid: 'observ-viz-golden',
  dashboardTitle: 'Four golden signals',
  dashboardTags: ['observ-viz', 'analysis', 'golden-signals'],
  datasource: '${datasource}',
  selector: '',
  varLabels: [],
  legendLabels: [],
  tabbed: true,
  source: sources.golden.apiserver,
  ruleSelector: '',
  // saturation past this for `for` is worth an alert
  saturation: 0.9,
  errorRatio: 0.05,
  'for': '15m',
  severity: 'warning',
  service: 'service',
};

local order = ['latency', 'traffic', 'errors', 'saturation'];
local about = {
  latency: 'How long the work takes. Watch the tail, not the mean: the average hides the requests people notice.',
  traffic: 'How much work arrives. It gives the other three their meaning - a perfect error ratio over no traffic says nothing.',
  errors: 'How much of the work fails. Count the failures the caller sees, including the ones that answered 200 with the wrong thing where you can.',
  saturation: 'How full the thing is. This is the leading signal: latency and errors follow it, usually after it passes about 80 percent.',
};

local resolve(config) =
  local cfg = defaults + config;
  cfg { varLabels: cfg.varLabels + (if std.length(cfg.source.groupBy) > 0 && cfg.varLabels == [] then cfg.source.groupBy else []) };

{
  local this = self,

  signals(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local sel = filters.selector(cfg);
    local legend = std.join(' / ', ['{{' + l + '}}' for l in src.groupBy]);
    {
      [k]:
        signal.new(src.signals[k].title, 'prometheus', cfg.datasource, src.signals[k].expr, src.signals[k].unit)
        .filteringSelector(sel).withLegendFormat(legend).withDescription(about[k] + ' ' + (if std.objectHas(src.signals[k], 'description') then src.signals[k].description else ''))
      for k in order
      if std.objectHas(src.signals, k)
    },

  elements(config={}, prefix='')::
    local cfg = resolve(config);
    local sigs = this.signals(config);
    local thresholds(k) =
      if k == 'saturation' then
        panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: cfg.saturation * 0.8 }, { color: 'red', value: cfg.saturation }])
        + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } })
      else if k == 'errors' then
        panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'red', value: cfg.errorRatio }])
        + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } })
      else {};
    { [prefix + k]: sigs[k].asTimeSeries(sigs[k]._name) + thresholds(k) for k in std.objectFields(sigs) },

  alerts(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local sel = cfg.ruleSelector;
    local cap(x) = std.asciiUpper(std.substr(x, 0, 1)) + std.substr(x, 1, std.length(x));
    local name(x) = std.join('', [cap(w) for w in std.split(std.strReplace(x, '_', '-'), '-')]);
    local expr(k) = std.strReplace(src.signals[k].expr % { queriesSelector: sel, filteringSelector: sel }, '$__rate_interval', '5m');
    [
      alert.rule.group('golden-' + cfg.service, std.prune([
        if std.objectHas(src.signals, 'saturation') then alert.rule.new(
          name(cfg.service) + 'Saturated',
          '(' + expr('saturation') + ') > ' + cfg.saturation,
          cfg['for'],
          cfg.severity,
          {},
          {
            summary: cfg.service + ' is over ' + (cfg.saturation * 100) + ' percent of what it can take.',
            description: 'The leading signal of the four: latency and errors follow saturation rather than the other way round, so there is usually time to act before anyone notices.',
          }
        ) else null,
        if std.objectHas(src.signals, 'errors') then alert.rule.new(
          name(cfg.service) + 'ErrorsHigh',
          '(' + expr('errors') + ') > ' + cfg.errorRatio,
          cfg['for'],
          'critical',
          {},
          { summary: 'More than ' + (cfg.errorRatio * 100) + ' percent of the work ' + cfg.service + ' does is failing.' }
        ) else null,
      ])),
    ],

  new(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local els = this.elements(config);
    local present = [k for k in order if std.objectHas(src.signals, k)];
    pack.build(cfg + {
      description: 'The four golden signals: latency, traffic, errors and the one RED leaves out, saturation. ' + src.description,
      references: [
        { title: 'Monitoring distributed systems', url: 'https://sre.google/sre-book/monitoring-distributed-systems/', description: 'the chapter the four signals come from' },
        { title: 'The RED method', url: 'https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/', description: 'the same first three, without saturation' },
      ],
      rowLabels: src.groupBy,
      // a profile whose saturation carries different labels says so rather
      // than leaving an empty column
      overviewSignals: if std.objectHas(src, 'overviewSignals') then src.overviewSignals else present,
    }, this.signals(config), [
      {
        title: std.asciiUpper(std.substr(k, 0, 1)) + std.substr(k, 1, std.length(k)),
        width: 12,
        height: 8,
        elements: { [k]: els[k] },
      }
      for k in present
    ], this.alerts(config)),
}
