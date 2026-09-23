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
      g.panel.text.new(grp.title + ' signals')
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
      g.panel.text.new(if title != null then title else cfg.dashboardTitle)
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

    // one row per instance: an instant query per column, joined on the instance
    // label. Column order = label columns, then config.overviewSignals.
    local instanceLabel = opt('instanceLabel', 'instance');
    local labelCols = varLabels + (if std.member(varLabels, instanceLabel) then [] else [instanceLabel]);
    local cols =
      local wanted = std.filter(function(k) std.objectHas(signals, k), opt('overviewSignals', []));
      if std.length(wanted) > 0 then wanted else std.objectFields(signals)[0:4];
    local nCols = std.length(cols);
    local valueName(i) = 'Value #' + std.char(std.codepoint('A') + i);
    local instances =
      g.panel.table.new('Instances')
      + g.panel.table.withDescription('One row per instance, from the current value of each signal.')
      + g.panel.table.withTargets([signals[cols[i]].asTableTarget() for i in std.range(0, nCols - 1)])
      + g.panel.table.withTransformations([
        // keep the label columns + one value column per query, drop Time/__name__
        { id: 'filterFieldsByName', options: { include: { names: labelCols + [valueName(i) for i in std.range(0, nCols - 1)] } } },
        // join the per-query frames into one row per instance
        { id: 'seriesToColumns', options: { byField: instanceLabel } },
        { id: 'organize', options: {
          // the join repeats every label column once per extra query
          excludeByName: { [labelCols[j] + ' ' + i]: true for j in std.range(0, std.length(labelCols) - 1) for i in std.range(2, if nCols > 1 then nCols else 2) },
          renameByName: { [l]: cap(l) for l in labelCols } + { [valueName(i)]: signals[cols[i]]._name for i in std.range(0, nCols - 1) },
          indexByName: { [labelCols[j]]: j for j in std.range(0, std.length(labelCols) - 1) }
                       + { [valueName(i)]: std.length(labelCols) + i for i in std.range(0, nCols - 1) },
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

    local overviewTab =
      g.layout.tabs.tab(
        'Overview',
        g.layout.grid.new() + g.layout.grid.withItems([
          g.layout.grid.item('__about', 0, 0, 12, 7),
          g.layout.grid.item('__references', 12, 0, 12, 7),
          g.layout.grid.item('__instances', 0, 7, 24, 10),
        ])
      );
    local groupTabs = [
      g.layout.tabs.tab(
        grp.title,
        g.layout.grid.new()
        + g.layout.grid.withItems(
          [g.layout.grid.item('__sig_' + slug(grp.title), 0, 0, 24, sigHeight(grp))]
          + g.util.grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height, sigHeight(grp))
        )
      )
      for grp in groups
    ];

    packInstance.grafana.dashboard
    + (if title != null then { spec+: { title: title } } else {})
    + (if uid != null then g.dashboard.withUid(uid) else {})
    + g.dashboard.withElements(elements)
    + g.dashboard.withLayout(g.layout.tabs.new() + g.layout.tabs.withTabs([overviewTab] + groupTabs)),
}
