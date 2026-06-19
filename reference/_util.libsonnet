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

    // markdown: one bullet per signal (name, unit, query).
    local md =
      '# ' + title + '\n\n## Signals\n\n'
      + std.join('\n', [
        '- **' + signals[k]._name + '** _(' + signals[k]._unit + ')_ — `' + signals[k]._expr + '`'
        for k in std.objectFields(signals)
      ]);
    local about =
      g.panel.text.new('About')
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
