// observ-viz reference — Status history board. Demonstrates the status-history
// panel options (colWidth, rowHeight) as rows of testdata-driven panels.
// Uses the provisioned grafana-testdata datasource.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),
  local targets = [td(), td(), td()],  // 3 random-walk series

  // a status-history panel with options + custom fieldConfig
  local sh(label, options={}, custom={}) =
    g.panel.statusHistory.new(label)
    + g.panel.statusHistory.withTargets(targets)
    + g.panel.statusHistory.withOptions(options)
    + g.panel.statusHistory.withFieldConfigDefaults({ custom: custom }),

  local groups = [
    { title: 'Options', panels: {
      narrow: sh('Col width 0.7', { colWidth: 0.7, rowHeight: 0.9 }),
      wide: sh('Col width 0.9', { colWidth: 0.9, rowHeight: 0.9 }),
      shortrows: sh('Row height 0.5', { colWidth: 0.9, rowHeight: 0.5 }),
    } },
  ],

  local rows = [
    {
      title: grp.title,
      keys: [g.util.string.slugify(grp.title) + '-' + k for k in std.objectFields(grp.panels)],
      elements: { [g.util.string.slugify(grp.title) + '-' + k]: grp.panels[k] for k in std.objectFields(grp.panels) },
    }
    for grp in groups
  ],

  board:
    g.dashboard.new('Panel / Status history')
    + g.dashboard.withUid('observ-viz-panel-statusHistory')
    + g.dashboard.withElements(std.foldl(function(acc, r) acc + r.elements, rows, {}))
    + g.dashboard.withLayout(
      g.layout.rows.new()
      + g.layout.rows.withRows([
        g.layout.rows.row(
          r.title,
          g.layout.grid.new() + g.layout.grid.withItems(g.util.grid.wrapItems(r.keys, 6, 7))
        )
        for r in rows
      ])
    ),
}
