// observ-viz error-budget burn rate (hand-written).
// How fast an SLO is spending its error budget, which is the number that tells
// you whether to wake someone: a burn rate of 1 spends the budget exactly over
// the SLO window, 14.4 spends it in a day, 6 in two and a half.
//
// Two shapes of source, because SLO tooling disagrees:
//   kind: 'windows'  burn rates already recorded per window (the
//                    kubernetes-mixin does this: apiserver_request:burnrate5m)
//   kind: 'budget'   an availability and an objective, from which the burn and
//                    the budget left are derived (Pyrra publishes these)
//
//   .new(cfg) .elements(cfg, pfx) .alerts(cfg)
local alert = import 'libs/common-lib/alert/main.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local sources = import 'libs/analysis-observ-lib/sources.libsonnet';

local defaults = {
  uid: 'observ-viz-burnrate',
  dashboardTitle: 'Error budget burn rate',
  dashboardTags: ['observ-viz', 'analysis', 'slo'],
  datasource: '${datasource}',
  selector: '',
  varLabels: [],
  legendLabels: [],
  tabbed: true,
  source: sources.burnRate.apiserver,
  ruleSelector: '',
  'for': '2m',
  service: 'slo',
};

// the four multi-window multi-burn pairs from the Google SRE workbook: how
// much of the budget is gone, over which long window, confirmed by a short one
local pairs = [
  { factor: 14.4, long: '1h', short: '5m', severity: 'critical', spends: 'the whole budget in about two days' },
  { factor: 6, long: '6h', short: '30m', severity: 'critical', spends: 'the whole budget in about five days' },
  { factor: 3, long: '1d', short: '2h', severity: 'warning', spends: 'the whole budget in about ten days' },
  { factor: 1, long: '3d', short: '6h', severity: 'warning', spends: 'exactly the budget over the SLO window' },
];

local resolve(config) =
  local cfg = defaults + config;
  cfg { varLabels: cfg.varLabels + (if std.length(cfg.source.groupBy) > 0 && cfg.varLabels == [] then cfg.source.groupBy else []) };

{
  local this = self,

  // burn(cfg, window, sel) -> the burn rate over that window
  burn(cfg, window, sel)::
    local src = cfg.source;
    if src.kind == 'windows'
    then src.prefix + window + '{' + sel + '}'
    // (1 - availability) / (1 - objective): how many budgets per window
    else '(1 - ' + src.availability + '{' + sel + '}) / clamp_min(1 - ' + src.objective + '{' + sel + '}, 1e-9)',

  signals(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local sel = filters.selector(cfg);
    local legend = std.join(' / ', ['{{' + l + '}}' for l in src.groupBy]);
    local sig(name, expr, unit, lg, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(sel).withLegendFormat(lg).withDescription(desc);
    local windows = if src.kind == 'windows' then src.windows else ['window'];
    {
      ['burn_' + w]: sig(
        'Burn rate ' + w,
        this.burn(cfg, w, '%(queriesSelector)s'),
        'short', legend + ' ' + w,
        'Budgets per ' + (if src.kind == 'windows' then 'SLO window, measured over ' + w else 'SLO window') + '. Past 1 the budget runs out before the window ends.'
      )
      for w in windows
    } + (if src.kind == 'budget' then {
           availability: sig('Availability', src.availability + '{%(queriesSelector)s}', 'percentunit', legend, 'The SLI over the SLO window.'),
           objective: sig('Objective', src.objective + '{%(queriesSelector)s}', 'percentunit', legend, 'What it is supposed to be.'),
           budgetLeft: sig(
             'Error budget left',
             '1 - ((1 - ' + src.availability + '{%(queriesSelector)s}) / clamp_min(1 - ' + src.objective + '{%(queriesSelector)s}, 1e-9))',
             'percentunit', legend,
             'Share of the budget still unspent. Zero means the objective is already missed for this window.'
           ),
         } else {}),

  elements(config={}, prefix='')::
    local cfg = resolve(config);
    local src = cfg.source;
    local sigs = this.signals(config);
    local windows = if src.kind == 'windows' then src.windows else ['window'];
    // every burn panel carries the same threshold lines, so a glance says
    // which of the four pairs is in play
    local burnPanel(w) =
      sigs['burn_' + w].asTimeSeries('Burn rate over ' + w)
      + panel.timeSeries.withThresholds([
        { color: 'green', value: null },
        { color: 'yellow', value: 1 },
        { color: 'orange', value: 6 },
        { color: 'red', value: 14.4 },
      ])
      + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } });
    { [prefix + 'burn_' + w]: burnPanel(w) for w in windows }
    + (if src.kind == 'budget' then {
         [prefix + 'budget']: sigs.budgetLeft.asTimeSeries('Error budget left')
                              + panel.timeSeries.withThresholds([{ color: 'red', value: null }, { color: 'orange', value: 0.25 }, { color: 'green', value: 0.5 }])
                              + panel.timeSeries.standardOptions.withMin(0) + panel.timeSeries.standardOptions.withMax(1),
         [prefix + 'availability']: sigs.availability.asTimeSeries('Availability against objective')
                                    + panel.withTargetsMixin([sigs.objective.asTarget()]),
       } else {}),

  // the multi-window multi-burn rules, only for a source that records windows
  alerts(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    if src.kind != 'windows' then [] else
      local cap(x) = std.asciiUpper(std.substr(x, 0, 1)) + std.substr(x, 1, std.length(x));
      local name(x) = std.join('', [cap(w) for w in std.split(std.strReplace(x, '_', '-'), '-')]);
      [
        alert.rule.group('burnrate-' + cfg.service, [
          alert.rule.new(
            name(cfg.service) + 'BudgetBurn' + std.strReplace(std.toString(p.factor), '.', '') + 'x',
            '(' + this.burn(cfg, p.long, cfg.ruleSelector) + ' > ' + p.factor + ')'
            + ' and (' + this.burn(cfg, p.short, cfg.ruleSelector) + ' > ' + p.factor + ')',
            cfg['for'],
            p.severity,
            { long_window: p.long, short_window: p.short },
            {
              summary: cfg.service + ' is burning its error budget ' + p.factor + ' times faster than it can afford, over ' + p.long + '.',
              description: 'At this rate it spends ' + p.spends + '. The short window (' + p.short + ') confirms it is still happening rather than something that already stopped.',
            }
          )
          for p in pairs
        ]),
      ],

  new(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local els = this.elements(config);
    local windows = if src.kind == 'windows' then src.windows else ['window'];
    pack.build(cfg + {
      description: 'How fast the error budget is being spent, and what that means for the objective. ' + src.description,
      references: [
        { title: 'Alerting on SLOs', url: 'https://sre.google/workbook/alerting-on-slos/', description: 'where the 14.4 / 6 / 3 / 1 pairs come from' },
        { title: 'Multi-window multi-burn', url: 'https://grafana.com/blog/2021/03/02/how-to-use-multi-window-multi-burn-rate-alerts/', description: 'why each rate is confirmed by a shorter window' },
      ],
      rowLabels: src.groupBy,
      overviewSignals: if src.kind == 'windows' then ['burn_' + w for w in windows[0:4]] else ['availability', 'budgetLeft'],
    }, this.signals(config), [
      {
        title: 'Burn rate',
        width: 12,
        height: 8,
        elements: { ['burn_' + w]: els['burn_' + w] for w in windows },
      },
    ] + (if src.kind == 'budget' then [
           { title: 'Budget', width: 12, height: 8, elements: { budget: els.budget, availability: els.availability } },
         ] else []),
        this.alerts(config)),
}
