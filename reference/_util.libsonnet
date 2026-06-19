// observ-viz reference — shared helpers (mixin-level; not part of the slim core).
local g = import 'g.libsonnet';
{
  // place a board in a Grafana folder (with a readable title) and tag it.
  place(dashboard, folder, tags):
    dashboard
    + g.dashboard.withFolder(folder.uid, folder.title)
    + g.dashboard.withTagsMixin(tags),

  // tabbedBoard(packInstance, title, uid): lay a pack out as a TabsLayout — an
  // "Overview" tab with a markdown panel describing every signal, then one tab
  // per signal group containing that group's panels.
  tabbedBoard(packInstance, title, uid)::
    local signals = packInstance.signals;
    local groups = packInstance.grafana.groups;

    // escape table-breaking pipes (PromQL regex uses |).
    local esc(s) = std.strReplace(s, '|', '\\|');
    // a signal's description column: its description, else the query.
    local sigRow(key) =
      local s = signals[key];
      local desc = if s._description != '' then esc(s._description) else '`' + esc(s._expr) + '`';
      '| ' + s._name + ' | ' + s._unit + ' | ' + desc + ' |';
    // one section per signal group (same grouping as the tabs).
    local section(grp) =
      local keys = std.filter(function(k) std.objectHas(signals, k), std.objectFields(grp.elements));
      '### ' + grp.title + '\n\n'
      + (if std.length(keys) > 0
         then '| Signal | Unit | Description |\n|---|---|---|\n' + std.join('\n', [sigRow(k) for k in keys])
         else '_No signal-backed panels._');

    // markdown page: titled with the board, then Signals split by group.
    local md = '## Signals\n\n' + std.join('\n\n', [section(grp) for grp in groups]);
    local about =
      g.panel.text.new(title)
      + g.panel.text.withOptions({ mode: 'markdown', content: md });

    local elements = packInstance.grafana.elements + g.element.panel('__about', about);

    local overviewTab =
      g.layout.tabs.tab(
        'Overview',
        g.layout.grid.new() + g.layout.grid.withItems([g.layout.grid.item('__about', 0, 0, 24, 12)])
      );
    local groupTabs = [
      g.layout.tabs.tab(
        grp.title,
        g.layout.grid.new()
        + g.layout.grid.withItems(g.util.grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height))
      )
      for grp in groups
    ];

    g.dashboard.new(title)
    + g.dashboard.withUid(uid)
    + g.dashboard.withVariables([
      g.variable.datasource.new('datasource', 'prometheus') + g.variable.datasource.withLabel('Data source'),
      g.variable.query.new('job')
      + g.variable.query.withLabel('Job')
      + g.variable.query.withLabelValues('job', 'up')
      + g.variable.query.withMulti()
      + g.variable.query.withIncludeAll(),
    ])
    + g.dashboard.withElements(elements)
    + g.dashboard.withLayout(g.layout.tabs.new() + g.layout.tabs.withTabs([overviewTab] + groupTabs)),
}
