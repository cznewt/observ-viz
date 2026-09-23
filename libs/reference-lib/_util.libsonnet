// observ-viz reference — shared helpers (mixin-level; not part of the slim core).
local g = import 'g.libsonnet';
{
  // place a board in a Grafana folder (with a readable title) and tag it.
  place(dashboard, folder, tags):
    dashboard
    + g.dashboard.withFolder(folder.uid, folder.title)
    + (if std.objectHas(folder, 'parent') then {
         metadata+: { annotations+: {
           'observ-viz.dev/folder-parent-uid': folder.parent.uid,
           'observ-viz.dev/folder-parent-title': folder.parent.title,
         } },
       } else {})
    + g.dashboard.withTagsMixin(tags),

  // tabbedBoard(packInstance, title, uid): lay a pack out as a TabsLayout on top
  // of the pack's own dashboard (so its variables — job plus any cascading
  // config.varLabels filters — carry over).
  //   Overview tab: what the board is (half) + reference links (half), then a
  //                 table with one row per instance (config.overviewSignals).
  //   group tabs:   that group's signal table, then the group's panels.
  // Config keys read here: description, references, overviewSignals,
  // instanceLabel, varLabels.
  tabbedBoard(packInstance, title=null, uid=null)::
    local cfg = packInstance.config;
    local opt(key, default) = if std.objectHas(cfg, key) then cfg[key] else default;
    local signals = packInstance.signals;
    local groups = packInstance.grafana.groups;

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
      g.panel.text.new('Signals')
      + g.panel.text.withOptions({ mode: 'markdown', content:
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
      g.panel.text.new('')
      + g.panel.text.withOptions({ mode: 'markdown', content:
        opt('description', 'Runtime signals for every instance matching the selected job.') + filterLine });
    local refItem(r) =
      '- [' + r.title + '](' + r.url + ')'
      + (if std.objectHas(r, 'description') then ' - ' + r.description else '');
    local references =
      local refs = opt('references', []);
      g.panel.text.new('References')
      + g.panel.text.withOptions({ mode: 'markdown', content:
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
    local cols =
      local wanted = std.filter(function(k) std.objectHas(signals, k), opt('overviewSignals', []));
      if std.length(wanted) > 0 then wanted else std.objectFields(signals)[0:4];
    local nCols = std.length(cols);
    local valueName(i) = 'Value #' + std.char(std.codepoint('A') + i);
    // label_join(<query>, "__row__", "/", "namespace", "pod")
    local rowTarget(key) =
      local t = signals[key].asTableTarget();
      local expr = t.spec.query.spec.expr;
      t + { spec+: { query+: { spec+: { expr:
        'label_join(' + expr + ', "' + rowField + '", "/", ' + std.join(', ', ['"' + l + '"' for l in rowLabels]) + ')' } } } };
    local instances =
      g.panel.table.new('Instances')
      + g.panel.table.withDescription('One row per ' + std.asciiLower(rowTitle) + ', from the current value of each signal.')
      + g.panel.table.withTargets([rowTarget(cols[i]) for i in std.range(0, nCols - 1)])
      + g.panel.table.withTransformations([
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
      + g.panel.table.withOverrides([
        {
          matcher: { id: 'byName', options: signals[cols[i]]._name },
          properties: [{ id: 'unit', value: signals[cols[i]]._unit }],
        }
        for i in std.range(0, nCols - 1)
      ]);

    local elements =
      packInstance.grafana.elements
      + g.element.panel('__about', about)
      + g.element.panel('__references', references)
      + g.element.panel('__instances', instances)
      + { ['__sig_' + slug(grp.title)]: sigPanel(grp) for grp in groups };

    // a group's tab: its signal table, then its panels
    local groupItems(grp, startY=0) =
      [g.layout.grid.item('__sig_' + slug(grp.title), 0, startY, 24, sigHeight(grp))]
      + g.util.grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height, startY + sigHeight(grp));

    // a pack may already have a group called "Overview" (the system packs do).
    // Fold it into this tab rather than opening a second one with the same name.
    local isOverview(grp) = std.asciiLower(grp.title) == 'overview';
    local ownOverview = std.filter(isOverview, groups);
    local overviewHeight = 17;
    local overviewTab =
      g.layout.tabs.tab(
        'Overview',
        g.layout.grid.new() + g.layout.grid.withItems([
          g.layout.grid.item('__about', 0, 0, 12, 7),
          g.layout.grid.item('__references', 12, 0, 12, 7),
          g.layout.grid.item('__instances', 0, 7, 24, 10),
        ] + (if std.length(ownOverview) > 0 then groupItems(ownOverview[0], overviewHeight) else []))
      );
    local groupTabs = [
      g.layout.tabs.tab(grp.title, g.layout.grid.new() + g.layout.grid.withItems(groupItems(grp)))
      for grp in groups
      if !isOverview(grp)
    ];

    packInstance.grafana.dashboard
    + (if title != null then { spec+: { title: title } } else {})
    + (if uid != null then g.dashboard.withUid(uid) else {})
    + g.dashboard.withElements(elements)
    + g.dashboard.withLayout(g.layout.tabs.new() + g.layout.tabs.withTabs([overviewTab] + groupTabs)),
}
