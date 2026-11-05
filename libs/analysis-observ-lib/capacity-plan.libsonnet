// observ-viz capacity planning method (hand-written).
// How full every cluster, node or application was, is and will be, over a window
// the board chooses. A tab per resource: three counts (under-used, well used, too
// full), then the table they count. analysis.capacity is the same question for one
// resource over time; this is the whole fleet at one moment, for the conversation
// about what to buy and what to move.
//
// Every query is instant. A window of months evaluated once per dashboard step
// would take minutes, and a table has no use for the steps.
//
//   Now     the aggregation of the hourly value over the window
//   Past    the same, the same length of window, `past` ago
//   Future  the straight line through the two, carried `future` ahead
//
// Future is deliberately not predict_linear. A regression over sparse data is
// wild: one node with 8 hours of data in 30 days read 3210 percent. The line needs
// a past window to exist, so a row without history leaves the cell blank rather
// than inventing a number, it can be checked by eye, and it compares like with
// like whichever aggregation is chosen.
//
//   .new(cfg) .signals(cfg) .elements(cfg)
local panel = import 'custom/panel.libsonnet';
local grid = import 'custom/util/grid.libsonnet';
local sources = import 'libs/analysis-observ-lib/sources.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { custom: gv.custom + cv.custom };

local defaults = {
  uid: 'observ-viz-capacity-plan',
  dashboardTitle: 'Capacity plan',
  dashboardTags: ['observ-viz', 'analysis', 'capacity'],
  datasource: '${datasource}',
  selector: 'cluster=~"$cluster"',
  groupVar: 'cluster',
  // a tab per resource is the whole board: no scrape-target table, no pod rows
  tabbed: true,
  overviewInstances: false,
  overviewPods: false,
  source: sources.capacityPlan.clusters,
  // under-used, well used, too full
  bands: { under: 0.3, over: 0.7 },
  // the knobs and what they start on
  aggregations: ['avg', 'max', 'min'],
  aggregation: 'avg',
  intervals: ['1h', '1d', '7d', '30d', '90d', '180d'],
  interval: '7d',
  offsets: ['1d', '7d', '30d', '90d', '180d', '1y'],
  past: '30d',
  future: '30d',
};

local resolve(config) =
  local cfg = defaults + config;
  cfg { varMetric: cfg.source.varMetric, varLabels: cfg.source.varLabels };

// seconds in a duration: the knobs carry seconds, because the line divides by them
local seconds(d) =
  local n = std.parseInt(std.substr(d, 0, std.length(d) - 1));
  local u = std.substr(d, std.length(d) - 1, 1);
  n * (if u == 'h' then 3600 else if u == 'd' then 86400 else if u == 'y' then 31536000 else 1);

local percent(x) = std.toString(std.floor(x * 100 + 0.5)) + '%';

// a choice between durations, shown as written and worth its seconds
local knob(name, label, description, choices, current) =
  variable.custom.new(name)
  + variable.custom.withLabel(label)
  + variable.custom.withDescription(description)
  + variable.custom.withQuery(std.join(',', [c + ' : ' + seconds(c) for c in choices]))
  + { spec+: {
    current: { text: current, value: std.toString(seconds(current)) },
    options: [{ text: c, value: std.toString(seconds(c)), selected: c == current } for c in choices],
    allowCustomValue: false,
  } };

local instant(target) = target { spec+: { query+: { spec+: { instant: true, range: false } } } };

{
  local this = self,

  // the three moments of a value, for a resource's query
  moments(u):: {
    local windowed = '${aggregation}_over_time((' + u + ')[${interval}s:1h]',
    now: windowed + ')',
    past: windowed + ' offset ${past}s)',
    line: self.now + ' + (' + self.now + ' - ' + self.past + ') * ${future} / ${past}',
  },

  signals(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local sel = filters.selector(cfg);
    local sig(name, expr, unit, description) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit)
      .filteringSelector(sel)
      .withDescription(description);
    // as written in a query: 0.7, where plain concatenation prints 0.69999999999999996
    local under = std.format('%g', cfg.bands.under);
    local over = std.format('%g', cfg.bands.over);
    local pctUnder = percent(cfg.bands.under);
    local pctOver = percent(cfg.bands.over);
    // no row in the band is an answer, zero, not a missing one
    local count(x) = 'count(' + x + ') or vector(0)';
    // `what` it is a share of, and what each band means for that
    local counts(res, ratio, what, means) =
      local many = 'How many ' + std.asciiLower(src.title) + ' are ';
      {
        [res.key + '_under']: sig(res.title + ' under ' + pctUnder,
                                  count(ratio + ' < ' + under),
                                  'short',
                                  many + 'under ' + pctUnder + ' of ' + what + ' over the interval: ' + means.under),
        [res.key + '_well']: sig(res.title + ' ' + pctUnder + ' to ' + pctOver,
                                 count(ratio + ' >= ' + under + ' < ' + over),
                                 'short',
                                 many + 'between ' + pctUnder + ' and ' + pctOver + ' of ' + what + ' over the interval: ' + means.well),
        [res.key + '_over']: sig(res.title + ' over ' + pctOver,
                                 count(ratio + ' >= ' + over),
                                 'short',
                                 many + 'at ' + pctOver + ' or more of ' + what + ' over the interval: ' + means.over),
      };
    local share(res) =
      local m = this.moments(res.share);
      {
        [res.key + '_past']: sig(res.title + ' past', m.past, 'percentunit', 'How full it was over an interval of the same length, `past` ago.'),
        [res.key + '_now']: sig(res.title + ' now', m.now, 'percentunit', 'How full it is: the chosen aggregation of the hourly value over the interval.'),
        [res.key + '_future']: sig(res.title + ' future', 'clamp(' + m.line + ', 0, 1)', 'percentunit', 'The straight line through past and now, carried `future` ahead and held between empty and full. Blank where there is no past to draw it from.'),
        [res.key + '_total']: sig(res.title + ' ' + std.asciiLower(res.totalTitle), res.total, res.totalUnit, 'What there is to use, right now.'),
      } + counts(res, m.now, 'their ' + std.asciiLower(res.title), {
        under: 'room to give back.',
        well: 'what is paid for is in use.',
        over: 'the next step is already late.',
      });
    local quota(res) =
      local m = this.moments(res.used);
      local ofRequest = m.now + ' / (' + res.request + ' > 0)';
      {
        [res.key + '_past']: sig(res.title + ' past', m.past, res.unit, 'What it used over an interval of the same length, `past` ago.'),
        [res.key + '_now']: sig(res.title + ' now', m.now, res.unit, 'What it uses: the chosen aggregation of the hourly value over the interval.'),
        [res.key + '_future']: sig(res.title + ' future', 'clamp_min(' + m.line + ', 0)', res.unit, 'The straight line through past and now, carried `future` ahead and held above zero. Blank where there is no past to draw it from.'),
        [res.key + '_request']: sig(res.title + ' request', res.request, res.unit, 'What its running pods ask for, right now. The scheduler reserves this much.'),
        [res.key + '_of_request']: sig(res.title + ' % of request', ofRequest, 'percentunit', 'Use over the interval against the request. Far over 100 percent means the node has reserved too little for it.'),
        [res.key + '_limit']: sig(res.title + ' limit', res.limit, res.unit, 'What its running pods may take, right now.'),
        [res.key + '_of_limit']: sig(res.title + ' % of limit', m.now + ' / (' + res.limit + ' > 0)', 'percentunit', 'Use over the interval against the limit. Memory at the limit is killed, CPU at the limit is throttled.'),
      } + counts(res, '(' + ofRequest + ')', 'their ' + std.asciiLower(res.title) + ' request', {
        under: 'they reserve far more than they use.',
        well: 'the request fits.',
        over: 'they use about what they reserve, or more, so a busy node has little to spare for them.',
      });
    std.foldl(function(acc, res) acc + (if src.kind == 'quota' then quota(res) else share(res)), src.resources, {}),

  // the columns of a resource's table, in order: signal key suffix and heading
  columns(src, res)::
    if src.kind == 'quota' then [
      ['past', 'Past'],
      ['now', 'Now'],
      ['future', 'Future'],
      ['request', 'Request'],
      ['of_request', '% of request'],
      ['limit', 'Limit'],
      ['of_limit', '% of limit'],
    ] else [
      ['past', 'Past'],
      ['now', 'Now'],
      ['future', 'Future'],
      ['total', res.totalTitle],
    ],

  // the link of a table cell, carrying the knobs along when it goes to a plan board
  link(l)::
    local plan = std.objectHas(l, 'plan') && l.plan;
    {
      title: l.title,
      url: '/d/' + l.uid + '?var-' + l.var + '=${__value.raw}&${__url_time_range}&${datasource:queryparam}'
           + (if plan then '&${aggregation:queryparam}&${interval:queryparam}&${past:queryparam}&${future:queryparam}' else ''),
      targetBlank: false,
    },

  table(cfg, res, sigs)::
    local src = cfg.source;
    local cols = this.columns(src, res);
    local valueName(i) = 'Value #' + std.char(std.codepoint('A') + i);
    local ov(name, props) = { matcher: { id: 'byName', options: name }, properties: props };
    local bandCell(cell) = [
      { id: 'unit', value: 'percentunit' },
      { id: 'decimals', value: 1 },
      { id: 'min', value: 0 },
      { id: 'max', value: 1 },
      { id: 'color', value: { mode: 'thresholds' } },
      { id: 'thresholds', value: { mode: 'absolute', steps: [
        { color: 'blue', value: null },
        { color: 'green', value: cfg.bands.under },
        { color: 'red', value: cfg.bands.over },
      ] } },
      { id: 'custom.cellOptions', value: cell },
    ];
    local gauge = { type: 'gauge', mode: 'basic' };
    local text = { type: 'color-text' };
    local amount(unit, decimals) = [{ id: 'unit', value: unit }, { id: 'decimals', value: decimals }];
    // the numbers keep to a width where a row has a long name to fit
    local sized(props) = if std.objectHas(src, 'columnWidth') then props + [{ id: 'custom.width', value: src.columnWidth }] else props;
    local linksFor(label) =
      (if std.objectHas(src.drill, label) then src.drill[label] else [])
      + (if std.objectHas(res, 'history') && res.history.label == label then [res.history] else []);
    local labelWidths = if std.objectHas(src, 'labelWidths') then src.labelWidths else {};
    local rowOverrides = [
      ov(
        src.labels[l],
        (if std.length(linksFor(l)) > 0 then [{ id: 'links', value: [this.link(x) for x in linksFor(l)] }] else [])
        + (if std.objectHas(labelWidths, l) then [{ id: 'custom.width', value: labelWidths[l] }] else [])
      )
      for l in src.by
      if std.length(linksFor(l)) > 0 || std.objectHas(labelWidths, l)
    ];
    local amounts = if src.kind == 'quota' then amount(res.unit, res.decimals) else amount(res.totalUnit, 0);
    local columnOverrides = {
      past: (if src.kind == 'quota' then amounts else bandCell(text)) + [{ id: 'displayName', value: 'Past (${past:text} ago)' }],
      now: if src.kind == 'quota' then amounts else bandCell(gauge),
      future: (if src.kind == 'quota' then amounts else bandCell(text)) + [{ id: 'displayName', value: 'Future (in ${future:text})' }],
      total: amounts,
      request: amounts,
      limit: amounts,
      of_request: bandCell(text),
      of_limit: bandCell(text),
    };
    panel.table.new(res.title + ' by ' + std.asciiLower(src.labels[src.by[std.length(src.by) - 1]]) + ', ${aggregation} over ${interval:text}')
    + panel.table.withDescription(
      'Now is the chosen aggregation of the hourly value over the chosen interval, and Past is the same, `past` ago. Future is the straight line through the two, carried `future` ahead. Past is blank where the data does not reach that far back, and Future is blank with it.'
    )
    + panel.table.withTargets([sigs[res.key + '_' + c[0]].asTableTarget() for c in cols])
    + panel.table.withTransformations([
      { id: 'filterFieldsByName', options: { include: { pattern: '^(' + std.join('|', src.by) + '|Value #[A-Z]+)$' } } },
      // rows with the same labels become one; a column a row lacks stays blank
      { id: 'merge' },
      { id: 'organize', options: {
        // every field indexed: unindexed ones take the low slots and push the
        // row labels out of first place
        indexByName:
          { [src.by[i]]: i for i in std.range(0, std.length(src.by) - 1) }
          + { [valueName(i)]: std.length(src.by) + i for i in std.range(0, std.length(cols) - 1) },
        renameByName:
          { [l]: src.labels[l] for l in src.by }
          + { [valueName(i)]: cols[i][1] for i in std.range(0, std.length(cols) - 1) },
      } },
      // a row with a Past and no Now is gone, with nothing left to plan for. It
      // also has to go for the sort: a gap in the column scrambles the order.
      { id: 'filterByValue', options: { type: 'exclude', match: 'any', filters: [{ fieldName: 'Now', config: { id: 'isNull', options: {} } }] } },
      { id: 'sortBy', options: { sort: [{ field: 'Now', desc: true }] } },
    ])
    + panel.table.withOverrides(
      rowOverrides + [ov(c[1], sized(columnOverrides[c[0]])) for c in cols]
    ),

  elements(config={})::
    local cfg = resolve(config);
    local sigs = this.signals(config);
    local tile(key, title, color) =
      sigs[key].asStat(title)
      + panel.stat.withTargets([instant(sigs[key].asTarget())])
      + panel.stat.withThresholds([{ color: color, value: null }])
      + panel.stat.withDecimals(0);
    std.foldl(function(acc, res) acc {
      [res.key + '_under']: tile(res.key + '_under', 'Under ' + percent(cfg.bands.under), 'blue'),
      [res.key + '_well']: tile(res.key + '_well', percent(cfg.bands.under) + ' to ' + percent(cfg.bands.over), 'green'),
      [res.key + '_over']: tile(res.key + '_over', 'Over ' + percent(cfg.bands.over), 'red'),
      [res.key + '_table']: this.table(cfg, res, sigs),
    }, cfg.source.resources, {}),

  new(config={})::
    local cfg = resolve(config);
    local src = cfg.source;
    local els = this.elements(config);
    local sigs = this.signals(config);
    pack.build(cfg {
      description: 'How full each of them was, is and will be, over the chosen interval. ' + src.description,
      references: [
        { title: 'Subqueries', url: 'https://prometheus.io/docs/prometheus/latest/querying/basics/#subquery', description: 'the hourly value every interval here aggregates' },
        { title: 'kube-state-metrics', url: 'https://github.com/kubernetes/kube-state-metrics', description: 'where requests, limits and pod owners come from' },
      ],
      extraVariables: [
        variable.custom.new('aggregation')
        + variable.custom.withLabel('Aggregation')
        + variable.custom.withDescription('How to read the hourly values in the interval: the typical hour, the busiest or the quietest.')
        + variable.custom.withQuery(std.join(',', cfg.aggregations))
        + { spec+: {
          current: { text: cfg.aggregation, value: cfg.aggregation },
          options: [{ text: a, value: a, selected: a == cfg.aggregation } for a in cfg.aggregations],
          allowCustomValue: false,
        } },
        knob('interval', 'Interval', 'The length of time behind every number.', cfg.intervals, cfg.interval),
        knob('past', 'Past', 'How far back the Past column looks.', cfg.offsets, cfg.past),
        knob('future', 'Future', 'How far ahead the line is carried.', cfg.offsets, cfg.future),
      ],
    }, sigs, [
      {
        title: res.title,
        width: 24,
        height: src.tableHeight,
        elements: {
          [res.key + s]: els[res.key + s]
          for s in ['_under', '_well', '_over', '_table']
        },
        signalKeys: [k for k in std.objectFields(sigs) if std.startsWith(k, res.key + '_')],
        items: [
          grid.item(res.key + '_under', 0, 0, 8, 3),
          grid.item(res.key + '_well', 8, 0, 8, 3),
          grid.item(res.key + '_over', 16, 0, 8, 3),
          grid.item(res.key + '_table', 0, 3, 24, src.tableHeight),
        ],
      }
      for res in src.resources
    ]),
}
