// observ-viz reference — XY chart board. The xyChart panel plots one field on
// the X axis against another on the Y axis (a scatter plot), rather than against
// time. We feed it the testdata "random_walk_table" scenario, which emits a
// table frame with numeric columns, and let the panel auto-map series/fields.
// xyChart options are not generated as typed setters, so we use the generic
// withOptions / withFieldConfigDefaults helpers from the shared veneer.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),
  local targets = [td('random_walk_table')],

  // an xyChart panel: pull a table frame, set the series mapping and point style.
  local xy(label, options, custom={}) =
    g.panel.xyChart.new(label)
    + g.panel.xyChart.withTargets(targets)
    + g.panel.xyChart.withOptions(options)
    + g.panel.xyChart.withFieldConfigDefaults({ custom: { pointSize: { fixed: 5 } } + custom }),

  // auto mapping lets Grafana pick x/y fields from the frame; manual would set
  // seriesMapping:'manual' + an explicit series[].x/.y field config.
  local autoOpts = { seriesMapping: 'auto', show: 'points' },

  local groups = [
    { title: 'Scatter', panels: {
      points: xy('Points', autoOpts),
      lines: xy('Points + lines', autoOpts { show: 'points+lines' }, { lineWidth: 2 }),
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
    g.dashboard.new('Panel / XY chart')
    + g.dashboard.withUid('observ-viz-panel-xyChart')
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
