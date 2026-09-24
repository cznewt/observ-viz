// observ-viz capacity method (hand-written).
// When does this run out? Everything here is a quantity that shrinks - free
// bytes, remaining certificate life - and the question is how long it has at
// the rate it has been going. predict_linear does the arithmetic; the value of
// the method is that the board and the alert agree on the same window, so what
// fires is what you were looking at.
//
//   .new(cfg) .elements(cfg, pfx) .alerts(cfg)
local alert = import 'libs/common-lib/alert/main.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local sources = import 'libs/analysis-observ-lib/sources.libsonnet';

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

  elements(config={}, prefix='')::
    local cfg = resolve(config);
    local sigs = this.signals(config);
    {
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

  new(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local els = this.elements(config);
    pack.build(cfg + {
      description: 'When this runs out, at the rate of the last ' + cfg.learn + '. ' + src.description,
      references: [
        { title: 'predict_linear', url: 'https://prometheus.io/docs/prometheus/latest/querying/functions/#predict_linear', description: 'the function behind every number here' },
        { title: 'Alerting on disks filling up', url: 'https://www.robustperception.io/reduce-noise-from-disk-space-alerts/', description: 'why a prediction beats a percentage threshold' },
      ],
      rowLabels: src.groupBy,
      overviewSignals: ['remaining', 'timeLeft', 'predicted'],
    }, this.signals(config), [
      {
        title: 'Capacity',
        width: 12,
        height: 8,
        elements: els,
      },
    ], this.alerts(config)),
}
