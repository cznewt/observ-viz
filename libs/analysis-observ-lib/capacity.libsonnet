// observ-viz capacity method (hand-written).
// Two questions, one method, chosen by the source's `kind`:
//
//   exhaustion   a quantity that shrinks - free bytes, certificate life. When
//                does it hit zero at the rate it has been going?
//   utilisation  used against total - how full is it now, how full was it a
//                while back, and how full will it be. This is the capacity
//                *planning* question, ported from the service catalog's
//                capacity-mixin (whose future column repeated the present
//                instead of predicting it, which is fixed here).
//
// predict_linear does the arithmetic in both. The value of the method is that
// the board and the alert agree on the same window, so what fires is what you
// were looking at.
//
//   .new(cfg) .elements(cfg, pfx) .alerts(cfg)
local alert = import 'libs/common-lib/alert/main.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local sources = import 'libs/analysis-observ-lib/sources.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { custom: gv.custom + cv.custom };

local defaults = {
  uid: 'observ-viz-capacity',
  dashboardTitle: 'Capacity',
  dashboardTags: ['observ-viz', 'analysis', 'capacity'],
  datasource: '${datasource}',
  selector: '',
  varLabels: [],
  legendLabels: [],
  tabbed: true,
  source: sources.capacity.filesystem,
  ruleSelector: '',
  // the trend is learned over this, and the alert asks about this far ahead
  learn: '6h',
  ahead: '4d',
  // utilisation sources: how far back the "was" column looks, and the bands
  // that split under-used from well-used from too full
  past: '7d',
  bands: { under: 0.3, over: 0.7 },
  'for': '1h',
  severity: 'warning',
  service: 'capacity',
};

// seconds in the `ahead` window, for predict_linear
local seconds(d) =
  local n = std.parseInt(std.substr(d, 0, std.length(d) - 1));
  local u = std.substr(d, std.length(d) - 1, 1);
  n * (if u == 'm' then 60 else if u == 'h' then 3600 else if u == 'd' then 86400 else if u == 'w' then 604800 else 1);

local resolve(config) =
  local cfg = defaults + config;
  cfg { varLabels: cfg.varLabels + (if std.length(cfg.source.groupBy) > 0 && cfg.varLabels == [] then cfg.source.groupBy else []) };

{
  local this = self,

  // the expressions a source turns into, for a given selector
  exprs(cfg, sel):: {
    local src = cfg.source,
    local remaining = src.remaining % { queriesSelector: sel, filteringSelector: sel },
    remaining: remaining,
    // how much it shrinks per second, negative while it is filling up
    trend: 'deriv((' + remaining + ')[' + cfg.learn + ':])',
    // Seconds until it reaches zero at that rate. The trailing `> 0` is a
    // filter, not a comparison: where the quantity is flat or growing the
    // division comes out negative and the series drops out, which is the
    // honest answer - that one is not running out of anything.
    timeLeft: '((' + remaining + ') / -deriv((' + remaining + ')[' + cfg.learn + ':])) > 0',
    predicted: 'predict_linear((' + remaining + ')[' + cfg.learn + ':], ' + seconds(cfg.ahead) + ')',
  },

  signals(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local sel = filters.selector(cfg);
    if src.kind == 'utilisation' then this.utilisationSignals(config) else
    local e = this.exprs(cfg, '%(queriesSelector)s');
    local legend = std.join(' / ', ['{{' + l + '}}' for l in src.groupBy]);
    local sig(name, expr, unit, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(sel).withLegendFormat(legend).withDescription(desc);
    {
      remaining: sig(src.remainingTitle, e.remaining, src.unit, 'What is left right now.'),
      timeLeft: sig('Time left', e.timeLeft, 's',
                    'How long until it reaches zero at the rate of the last ' + cfg.learn + '. Empty where it is not shrinking.'),
      predicted: sig('Predicted in ' + cfg.ahead, e.predicted, src.unit,
                     'What the same trend leaves in ' + cfg.ahead + '. Below zero is the alert.'),
    },

  utilisationSignals(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local sel = filters.selector(cfg);
    local u = this.utilisation(cfg, '%(queriesSelector)s');
    local legend = std.join(' / ', ['{{' + l + '}}' for l in src.groupBy]);
    local sig(name, expr, unit, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(sel).withLegendFormat(legend).withDescription(desc);
    {
      now: sig('Utilisation', u.now, 'percentunit', 'How full it is right now.'),
      before: sig('Utilisation ' + cfg.past + ' ago', u.before, 'percentunit', 'What it was ' + cfg.past + ' ago, so the current number reads as a trend rather than a snapshot.'),
      soon: sig('Utilisation in ' + cfg.ahead, u.soon, 'percentunit', 'Where the trend of the last ' + cfg.learn + ' puts it in ' + cfg.ahead + '.'),
      total: sig(src.totalTitle, u.total, src.totalUnit, 'What there is to use.'),
    },

  elements(config={}, prefix='')::
    local cfg = resolve(config);
    local sigs = this.signals(config);
    if cfg.source.kind == 'utilisation' then {
      [prefix + 'utilisation']:
        sigs.now.asTimeSeries('Utilisation, and where it is heading')
        + panel.withTargetsMixin([sigs.soon.asTarget()])
        + panel.timeSeries.standardOptions.withUnit('percentunit')
        + panel.timeSeries.withThresholds([
          { color: 'blue', value: null },
          { color: 'green', value: cfg.bands.under },
          { color: 'red', value: cfg.bands.over },
        ])
        + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } }),
      [prefix + 'total']: sigs.total.asTimeSeries(cfg.source.totalTitle),
    } else {
      [prefix + 'remaining']: sigs.remaining.asTimeSeries(sigs.remaining._name)
                              + panel.withTargetsMixin([sigs.predicted.asTarget()]),
      [prefix + 'timeLeft']: sigs.timeLeft.asTimeSeries('Time left')
                             + panel.timeSeries.standardOptions.withUnit('s')
                             + panel.timeSeries.withThresholds([
                               { color: 'red', value: null },
                               { color: 'orange', value: seconds(cfg.ahead) },
                               { color: 'green', value: seconds(cfg.ahead) * 4 },
                             ])
                             + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } }),
    },

  alerts(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    if src.kind == 'utilisation' then
      local u = this.utilisation(cfg, cfg.ruleSelector);
      local cap(x) = std.asciiUpper(std.substr(x, 0, 1)) + std.substr(x, 1, std.length(x));
      local name(x) = std.join('', [cap(w) for w in std.split(std.strReplace(x, '_', '-'), '-')]);
      [
        alert.rule.group('capacity-' + cfg.service, [
          alert.rule.new(
            name(cfg.service) + 'Full',
            '(' + u.now + ') > ' + cfg.bands.over + ' and (' + u.soon + ') > ' + cfg.bands.over,
            cfg['for'],
            cfg.severity,
            {},
            {
              summary: cfg.source.title + ' on {{ $labels.' + src.groupBy[0] + ' }} is over ' + (cfg.bands.over * 100) + ' percent and not coming back down.',
              description: 'Both the current number and where the trend puts it in ' + cfg.ahead + ' are past the band, so this is growth rather than a spike. Capacity is a planning decision: the alert is early on purpose.',
            }
          ),
        ]),
      ]
    else
    local e = this.exprs(cfg, cfg.ruleSelector);
    local cap(x) = std.asciiUpper(std.substr(x, 0, 1)) + std.substr(x, 1, std.length(x));
    local name(x) = std.join('', [cap(w) for w in std.split(std.strReplace(x, '_', '-'), '-')]);
    [
      alert.rule.group('capacity-' + cfg.service, [
        alert.rule.new(
          name(cfg.service) + 'RunningOut',
          // still has something now, and the trend says it will not in `ahead`
          '(' + e.remaining + ') > 0 and (' + e.predicted + ') < 0',
          cfg['for'],
          cfg.severity,
          {},
          {
            summary: src.remainingTitle + ' on {{ $labels.' + src.groupBy[0] + ' }} runs out within ' + cfg.ahead + ' at the current rate.',
            description: 'A prediction, not a measurement: it reads the trend of the last ' + cfg.learn + ' and extends it. A burst of writes that has already stopped will still fire it, so look at the trend before acting.',
          }
        ),
      ]),
    ],

  // ---- utilisation ---------------------------------------------------------
  utilisation(cfg, sel):: {
    local src = cfg.source,
    local used = src.used % { queriesSelector: sel, filteringSelector: sel },
    local total = src.total % { queriesSelector: sel, filteringSelector: sel },
    used: used,
    total: total,
    now: '(' + used + ') / clamp_min(' + total + ', 1e-9)',
    // the same ratio as it stood `past` ago, for the column that says whether
    // this is a trend or a Tuesday
    before: '(' + std.strReplace(used, '}', ' offset ' + cfg.past + '}') + ') / clamp_min(' + std.strReplace(total, '}', ' offset ' + cfg.past + '}') + ', 1e-9)',
    // where the trend puts it `ahead` from now - a prediction, which is what
    // the catalog board promised and did not do
    soon: 'predict_linear(((' + used + ') / clamp_min(' + total + ', 1e-9))[' + cfg.learn + ':], ' + seconds(cfg.ahead) + ')',
  },

  new(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local els = this.elements(config);
    pack.build(cfg + {
      description:
        (if src.kind == 'utilisation'
         then 'How full this is, how full it was ' + cfg.past + ' ago, and where the trend of the last ' + cfg.learn + ' puts it in ' + cfg.ahead + '. '
         else 'When this runs out, at the rate of the last ' + cfg.learn + '. ') + src.description,
      references: [
        { title: 'predict_linear', url: 'https://prometheus.io/docs/prometheus/latest/querying/functions/#predict_linear', description: 'the function behind every number here' },
        { title: 'Alerting on disks filling up', url: 'https://www.robustperception.io/reduce-noise-from-disk-space-alerts/', description: 'why a prediction beats a percentage threshold' },
      ],
      rowLabels: src.groupBy,
      overviewSignals:
        if src.kind == 'utilisation'
        then ['before', 'now', 'soon', 'total']
        else ['remaining', 'timeLeft', 'predicted'],
      // the aggregation window and the horizon are the two knobs a capacity
      // conversation actually turns, so they are variables, not constants
      extraVariables: if src.kind != 'utilisation' then [] else [
        variable.custom.new('interval')
        + variable.custom.withLabel('Rate window')
        + variable.custom.withQuery('5m,1h,1d,7d')
        + { spec+: { current: { text: '1h', value: '1h' }, options: [{ text: w, value: w, selected: w == '1h' } for w in ['5m', '1h', '1d', '7d']] } },
      ],
    }, this.signals(config), [
      {
        title: 'Capacity',
        width: 12,
        height: 8,
        elements: els,
      },
    ], this.alerts(config)),
}
