// observ-viz tabbed board layout (hand-written).
// The board contract every pack can opt into with `config.tabbed`:
//
//   Overview tab  what the board is (half width) + reference links (half),
//                 then one row per instance built from config.overviewSignals.
//                 A group the pack itself calls "Overview" folds in here.
//   group tabs    one per signal group: that group's signal table
//                 (name / unit / description / query), then its panels.
//
// Config keys read here: dashboardTitle, description, references,
// overviewSignals, rowLabels, instanceLabel, varLabels.
// imports the veneers directly, not g.libsonnet: pack.libsonnet pulls this in,
// and g would be an import cycle.
local element = import 'custom/element.libsonnet';
local layout = import 'custom/layout.libsonnet';
local panel = import 'custom/panel.libsonnet';
local utils = import 'libs/common-lib/utils.libsonnet';
local grid = import 'custom/util/grid.libsonnet';
{
  // build(config, signals, groups, elements) -> { elements, tabs }
  build(cfg, signals, groups, packElements):: (
    local opt(key, default) = if std.objectHas(cfg, key) then cfg[key] else default;

    local showInstances = opt('overviewInstances', true);
    local cap(s) = std.asciiUpper(std.substr(s, 0, 1)) + std.substr(s, 1, std.length(s));
    local slug(s) = std.asciiLower(std.strReplace(std.strReplace(s, ' ', '_'), '-', '_'));
    // escape table-breaking pipes (PromQL regex uses |).
    local esc(s) = std.strReplace(s, '|', '\\|');
    // An element key is usually the signal key. Packs that order their panels
    // with a numeric prefix (s11_state) or rename them broke that and their
    // tabs printed an empty signal table, so resolve in three steps: the key
    // itself, the key with an ordering prefix stripped, then the panel title
    // matched against a signal name.
    local digits = '0123456789';
    local keyChars = 'abcdefghijklmnopqrstuvwxyz' + digits;
    local isOrderPrefix(p) =
      std.length(p) > 0
      && std.length(std.filter(function(c) !std.member(keyChars, c), std.stringChars(p))) == 0
      && std.length(std.filter(function(c) std.member(digits, c), std.stringChars(p))) > 0;
    local unprefixed(k) =
      local i = std.findSubstr('_', k);
      if std.length(i) > 0 && isOrderPrefix(std.substr(k, 0, i[0]))
      then std.substr(k, i[0] + 1, std.length(k) - i[0] - 1)
      else k;
    // two signals may share a display name (a stat and its table); first wins.
    local byName = std.foldl(
      function(acc, k) if std.objectHas(acc, signals[k]._name) then acc else acc { [signals[k]._name]: k },
      std.objectFields(signals),
      {}
    );
    local resolve(grp, k) =
      if std.objectHas(signals, k) then k
      else if std.objectHas(signals, unprefixed(k)) then unprefixed(k)
      else
        local t = std.get(std.get(grp.elements[k], 'spec', {}), 'title', '');
        if std.objectHas(byName, t) then byName[t] else null;
    // a group may name its signals outright - the escape hatch for a tab whose
    // panels each draw several signals, where no key or title maps one to one.
    local sigKeys(grp) =
      if std.objectHas(grp, 'signalKeys')
      then std.filter(function(k) std.objectHas(signals, k), grp.signalKeys)
      else
        local resolved = [resolve(grp, k) for k in std.objectFields(grp.elements)];
        std.uniq(std.sort(std.filter(function(k) k != null, resolved)));

    // --- one signal table per group, rendered on that group's own tab --------
    // the query as written, with the dashboard's filter variables left as '...'
    // - the table documents the signal, it is not a copy of the panel's query.
    local sigRow(key) =
      local s = signals[key];
      local desc = if s._description != '' then esc(s._description) else '';
      local expr = s._expr % { queriesSelector: '...', filteringSelector: '...' };
      '| ' + s._name + ' | ' + s._unit + ' | ' + desc + ' | ' + utils.mdQuery(expr) + ' |';
    local sigPanel(grp) =
      local keys = sigKeys(grp);
      panel.text.new('Signals')
      + panel.text.withOptions({ mode: 'markdown', content:
        if std.length(keys) > 0
        then '| Signal | Unit | Description | Query |\n|---|---|---|---|\n' + std.join('\n', [sigRow(k) for k in keys])
        else '_No signal-backed panels in this group._' });
    local sigHeight(grp) = 3 + std.length(sigKeys(grp));

    // --- Overview: about + references (half each), then the instances table --
    local varLabels = opt('varLabels', []);
    local filterLine =
      if std.length(varLabels) > 0
      then '\n\nFilter with the **Job**' + std.join('', [' / **' + cap(l) + '**' for l in varLabels]) + ' variables above.'
      else '';
    local about =
      panel.text.new('')
      + panel.text.withOptions({ mode: 'markdown', content:
        opt('description', 'Runtime signals for every instance matching the selected job.') + filterLine });
    local refItem(r) =
      '- [' + r.title + '](' + r.url + ')'
      + (if std.objectHas(r, 'description') then ' - ' + r.description else '');
    local references =
      local refs = opt('references', []);
      panel.text.new('References')
      + panel.text.withOptions({ mode: 'markdown', content:
        if std.length(refs) > 0 then std.join('\n', [refItem(r) for r in refs])
        else '_No references configured._' });

    // One row per instance: an instant query per column, joined on a single
    // identity column that label_join() builds from config.rowLabels
    // (namespace/pod, say), so the table is that column plus the signals.
    local instanceLabel = opt('instanceLabel', 'instance');
    local rowLabels =
      local r = opt('rowLabels', []);
      if std.length(r) > 0 then r else [instanceLabel];
    local rowField = '__row__';
    local rowTitle = std.join(' / ', [cap(l) for l in rowLabels]);
    // columns: config.overviewSignals, else the first signal group's signals -
    // a pack's first group is its summary, which beats four signals picked
    // alphabetically out of the whole set.
    local cols =
      local wanted = std.filter(function(k) std.objectHas(signals, k), opt('overviewSignals', []));
      local firstGroup =
        if std.length(groups) > 0
        then std.filter(function(k) std.objectHas(signals, k), std.objectFields(groups[0].elements))
        else [];
      local fallback = if std.length(firstGroup) > 0 then firstGroup else std.objectFields(signals);
      if std.length(wanted) > 0 then wanted else fallback[0:5];
    local nCols = std.length(cols);
    local valueName(i) = 'Value #' + std.char(std.codepoint('A') + i);
    local refIdOf(i) = std.char(std.codepoint('A') + i);
    // config.overviewSparklines: signals drawn as a Trend column instead of a
    // number - a range query put through timeSeriesTable, which is the only
    // thing a sparkline cell can render.
    local sparkCols = std.filter(function(k) std.objectHas(signals, k), opt('overviewSparklines', []));
    local nSpark = std.length(sparkCols);
    local trendName(i) = signals[sparkCols[i]]._name + ' trend';
    // config.overviewTopK: keep the N largest series per column. A table of
    // every container in a cluster is unreadable; the busiest N is the question.
    local topK = opt('overviewTopK', 0);
    local limited(expr) = if topK > 0 then 'topk(' + topK + ', ' + expr + ')' else expr;
    // A column's signal is often a whole-service aggregate (max(x), sum by (code)
    // (rate(y))), which drops the row labels, leaving every row key empty and the
    // table blank. Add the row labels to each aggregation: `op(` becomes
    // `op by (<rowLabels>) (`, and an existing `op by (a)` gains them. Function
    // names that merely end in an op (clamp_max, sum_over_time) and `without`
    // aggregations are left alone.
    local aggOps = ['sum', 'max', 'min', 'avg', 'count', 'stddev', 'stdvar', 'group'];
    local wordChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_';
    local byRow(expr) =
      local n = std.length(expr);
      local skipWs(i) = if i < n && expr[i] == ' ' then skipWs(i + 1) else i;
      local closeAt(i) = if i >= n || expr[i] == ')' then i else closeAt(i + 1);
      local edit(op, p) =
        local j = skipWs(p + std.length(op));
        if j < n && expr[j] == '(' then [{ at: j, text: ' by (' + std.join(', ', rowLabels) + ') ' }]
        else if std.substr(expr, j, 2) == 'by' && skipWs(j + 2) < n && expr[skipWs(j + 2)] == '(' then
          local open = skipWs(j + 2);
          local close = closeAt(open);
          local have = [std.stripChars(x, ' ') for x in std.split(std.substr(expr, open + 1, close - open - 1), ',')];
          local add = [l for l in rowLabels if !std.member(have, l)];
          if std.length(add) > 0 then [{ at: close, text: ', ' + std.join(', ', add) }] else []
        else [];
      local edits = std.sort(std.flattenArrays([
        edit(op, p)
        for op in aggOps
        for p in std.findSubstr(op, expr)
        if p == 0 || std.findSubstr(expr[p - 1], wordChars) == []
      ]), function(e) -e.at);
      std.foldl(function(acc, e) std.substr(acc, 0, e.at) + e.text + std.substr(acc, e.at, std.length(acc) - e.at), edits, expr);
    local joined(expr) =
      'label_join(' + limited(byRow(expr)) + ', "' + rowField + '", "/", '
      + std.join(', ', ['"' + l + '"' for l in rowLabels]) + ')';
    // label_join(<query>, "__row__", "/", "namespace", "pod")
    local rowTarget(key) =
      local t = signals[key].asTableTarget();
      t { spec+: { query+: { spec+: { expr: joined(t.spec.query.spec.expr) } } } };
    // the sparkline columns stay range queries and keep their labels, so
    // timeSeriesTable can key each row by __row__ like the instant columns.
    local trendTarget(key) =
      local t = signals[key].asTarget();
      t { spec+: { query+: { spec+: { expr: joined(t.spec.query.spec.expr), legendFormat: '' } } } };
    local instances =
      panel.table.new('Instances')
      + panel.table.withDescription('One row per ' + std.asciiLower(rowTitle) + ', from the current value of each signal.')
      + panel.table.withTargets(
        [rowTarget(cols[i]) for i in std.range(0, nCols - 1)]
        + [trendTarget(sparkCols[i]) for i in std.range(0, nSpark - 1)]
      )
      + panel.table.withTransformations(
        // range frames -> one Trend column each; the instant frames are tables
        // already and pass through untouched.
        (if nSpark > 0 then [{ id: 'timeSeriesTable', options: {} }] else [])
        + [
          // keep the identity column + one value column per query
          (if nSpark > 0
           then { id: 'filterFieldsByName', options: { include: { pattern: '^(' + rowField + '|Value #[A-Z]+|Trend.*)$' } } }
           else { id: 'filterFieldsByName', options: { include: { names: [rowField] + [valueName(i) for i in std.range(0, nCols - 1)] } } }),
          // join the per-query frames into one row
          { id: 'seriesToColumns', options: { byField: rowField } },
          { id: 'organize', options: {
            excludeByName: {},
            renameByName:
              { [rowField]: rowTitle }
              + { [valueName(i)]: signals[cols[i]]._name for i in std.range(0, nCols - 1) }
              + { ['Trend #' + refIdOf(nCols + i)]: trendName(i) for i in std.range(0, nSpark - 1) },
            indexByName:
              { [rowField]: 0 }
              + { ['Trend #' + refIdOf(nCols + i)]: 1 + i for i in std.range(0, nSpark - 1) }
              + { [valueName(i)]: 1 + nSpark + i for i in std.range(0, nCols - 1) },
          } },
        ]
      )
      + panel.table.withOverrides(
        [
          {
            matcher: { id: 'byName', options: signals[cols[i]]._name },
            properties: [{ id: 'unit', value: signals[cols[i]]._unit }],
          }
          for i in std.range(0, nCols - 1)
        ]
        + [
          {
            matcher: { id: 'byName', options: trendName(i) },
            properties: [
              { id: 'unit', value: signals[sparkCols[i]]._unit },
              { id: 'custom.cellOptions', value: {
                type: 'sparkline',
                hideValue: false,
                lineWidth: 1.5,
                fillOpacity: 16,
                gradientMode: 'scheme',
              } },
            ],
          }
          for i in std.range(0, nSpark - 1)
        ]
      );

    local elements =
      packElements
      + element.panel('__about', about)
      + element.panel('__references', references)
      + (if showInstances then element.panel('__instances', instances) else {})
      + { ['__sig_' + slug(grp.title)]: sigPanel(grp) for grp in groups };

    // a group's tab: its signal table, then its panels
    // The signal tables are documentation: each sits in its own "Signals" row,
    // rendered only while the board's `signals` variable (Hide / Show, pack.build
    // declares it) is Show. The panels ride in a header-less row below, so a
    // tab reads as before with the tables hidden.
    local signalsGate = layout.withConditionalRendering(layout.conditional.group([layout.conditional.variable('signals', 'Show', 'equals')]));
    local sigRow(grp, collapse=false) =
      layout.rows.row('Signals', layout.grid.new() + layout.grid.withItems([layout.grid.item('__sig_' + slug(grp.title), 0, 0, 24, sigHeight(grp))]), collapse)
      + signalsGate;
    local bodyRow(title, items) = layout.rows.row(title, layout.grid.new() + layout.grid.withItems(items)) + { spec+: { hideHeader: true } };
    local groupRows(grp) = [
      sigRow(grp),
      bodyRow(grp.title, grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height)),
    ];

    // a pack may already have a group called "Overview" (the system packs do).
    // Fold it into this tab rather than opening a second one with the same name.
    local isOverview(grp) = std.asciiLower(grp.title) == 'overview';
    local ownOverview = std.filter(isOverview, groups);
    // config.overviewInstances: false drops the instances table. A board whose
    // own Overview group already answers "what is out there" - the cluster and
    // multi-cluster boards, with their Clusters and Namespaces tables - does not
    // need a second table of scrape targets on top.
    local overviewTab =
      layout.tabs.tab(
        'Overview',
        layout.rows.new() + layout.rows.withRows([
          bodyRow('Overview', [
            layout.grid.item('__about', 0, 0, 12, 7),
            layout.grid.item('__references', 12, 0, 12, 7),
          ] + (if showInstances then [layout.grid.item('__instances', 0, 7, 24, 10)] else [])),
        ] + (if std.length(ownOverview) > 0 then groupRows(ownOverview[0]) else []))
      );
    // a group may repeat itself per value of a variable (`grp.repeat`): the
    // signal table stays put and the panels come back once per value.
    local repeatedTab(grp) =
      layout.rows.new() + layout.rows.withRows([
        sigRow(grp, true),
        layout.rows.row(
          '$' + grp.repeat,
          layout.grid.new() + layout.grid.withItems(grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height))
        ) + layout.rows.withRepeat(grp.repeat),
      ]);
    local groupTabs = [
      layout.tabs.tab(
        grp.title,
        if std.objectHas(grp, 'repeat') then repeatedTab(grp)
        else layout.rows.new() + layout.rows.withRows(groupRows(grp))
      )
      for grp in groups
      if !isOverview(grp)
    ];


    { elements: elements, overviewTab: overviewTab, groupTabs: groupTabs }
  ),
}
