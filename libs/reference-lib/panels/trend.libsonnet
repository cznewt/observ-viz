// observ-viz reference — Trend panel board.
// Trend plots a non-time x-field (any numeric field) instead of time on the
// x-axis. We feed it the random_walk_table testdata scenario (which yields a
// table with numeric columns) and show a couple of variation panels driven by
// the provisioned grafana-testdata datasource.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),

  // a trend panel built from the random_walk_table scenario; opts/custom are
  // merged onto options/fieldConfig.custom respectively.
  local trend(label, opts={}, custom={}) =
    g.panel.trend.new(label)
    + g.panel.trend.withTargets([td('random_walk_table')])
    + g.panel.trend.withOptions(opts)
    + g.panel.trend.withFieldConfigDefaults({ custom: { drawStyle: 'line', lineWidth: 1, fillOpacity: 10 } + custom }),

  local groups = [
    { title: 'X field', panels: {
      auto: trend('Auto x-field', {}, { fillOpacity: 20 }),
      time: trend('X = Time', { xField: 'Time' }, { drawStyle: 'bars', fillOpacity: 50 }),
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
    g.dashboard.new('Panel / Trend')
    + g.dashboard.withUid('observ-viz-panel-trend')
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
