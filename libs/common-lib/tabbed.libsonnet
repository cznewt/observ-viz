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
local grid = import 'custom/util/grid.libsonnet';
local layout = import 'custom/layout.libsonnet';
local panel = import 'custom/panel.libsonnet';
{
  // build(config, signals, groups, elements) -> { elements, tabs }
  build(cfg, signals, groups, packElements):: (
    local opt(key, default) = if std.objectHas(cfg, key) then cfg[key] else default;

    local cap(s) = std.asciiUpper(std.substr(s, 0, 1)) + std.substr(s, 1, std.length(s));
    local slug(s) = std.asciiLower(std.strReplace(std.strReplace(s, ' ', '_'), '-', '_'));
    // escape table-breaking pipes (PromQL regex uses |).
    local esc(s) = std.strReplace(s, '|', '\\|');
    local sigKeys(grp) = std.filter(function(k) std.objectHas(signals, k), std.objectFields(grp.elements));

    // --- one signal table per group, rendered on that group's own tab --------
    // the query as written, with the dashboard's filter variables left as '...'
    // - the table documents the signal, it is not a copy of the panel's query.
    local sigRow(key) =
      local s = signals[key];
      local desc = if s._description != '' then esc(s._description) else '';
      local expr = s._expr % { queriesSelector: '...', filteringSelector: '...' };
      '| ' + s._name + ' | ' + s._unit + ' | ' + desc + ' | `' + esc(expr) + '` |';
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
    // label_join(<query>, "__row__", "/", "namespace", "pod")
    local rowTarget(key) =
      local t = signals[key].asTableTarget();
      local expr = t.spec.query.spec.expr;
      t + { spec+: { query+: { spec+: { expr:
        'label_join(' + expr + ', "' + rowField + '", "/", ' + std.join(', ', ['"' + l + '"' for l in rowLabels]) + ')' } } } };
    local instances =
      panel.table.new('Instances')
      + panel.table.withDescription('One row per ' + std.asciiLower(rowTitle) + ', from the current value of each signal.')
      + panel.table.withTargets([rowTarget(cols[i]) for i in std.range(0, nCols - 1)])
      + panel.table.withTransformations([
        // keep the identity column + one value column per query
        { id: 'filterFieldsByName', options: { include: { names: [rowField] + [valueName(i) for i in std.range(0, nCols - 1)] } } },
        // join the per-query frames into one row
        { id: 'seriesToColumns', options: { byField: rowField } },
        { id: 'organize', options: {
          excludeByName: {},
          renameByName: { [rowField]: rowTitle } + { [valueName(i)]: signals[cols[i]]._name for i in std.range(0, nCols - 1) },
          indexByName: { [rowField]: 0 } + { [valueName(i)]: 1 + i for i in std.range(0, nCols - 1) },
        } },
      ])
      + panel.table.withOverrides([
        {
          matcher: { id: 'byName', options: signals[cols[i]]._name },
          properties: [{ id: 'unit', value: signals[cols[i]]._unit }],
        }
        for i in std.range(0, nCols - 1)
      ]);

    local elements =
      packElements
      + element.panel('__about', about)
      + element.panel('__references', references)
      + element.panel('__instances', instances)
      + { ['__sig_' + slug(grp.title)]: sigPanel(grp) for grp in groups };

    // a group's tab: its signal table, then its panels
    local groupItems(grp, startY=0) =
      [layout.grid.item('__sig_' + slug(grp.title), 0, startY, 24, sigHeight(grp))]
      + grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height, startY + sigHeight(grp));

    // a pack may already have a group called "Overview" (the system packs do).
    // Fold it into this tab rather than opening a second one with the same name.
    local isOverview(grp) = std.asciiLower(grp.title) == 'overview';
    local ownOverview = std.filter(isOverview, groups);
    local overviewHeight = 17;
    local overviewTab =
      layout.tabs.tab(
        'Overview',
        layout.grid.new() + layout.grid.withItems([
          layout.grid.item('__about', 0, 0, 12, 7),
          layout.grid.item('__references', 12, 0, 12, 7),
          layout.grid.item('__instances', 0, 7, 24, 10),
        ] + (if std.length(ownOverview) > 0 then groupItems(ownOverview[0], overviewHeight) else []))
      );
    local groupTabs = [
      layout.tabs.tab(grp.title, layout.grid.new() + layout.grid.withItems(groupItems(grp)))
      for grp in groups
      if !isOverview(grp)
    ];


    { elements: elements, overviewTab: overviewTab, groupTabs: groupTabs }
  ),
}
