// observ-viz reference — Bar chart board. Demonstrates the barChart style
// options as rows of testdata-driven panels: orientation and stacking mode.
// Uses the provisioned grafana-testdata datasource. The random_walk_table
// scenario yields a table of numeric columns the bar chart plots as bars.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),
  // A table scenario gives several numeric columns -> multiple bar series.
  local targets = [td('random_walk_table')],

  // a barChart panel with custom fieldConfig.custom + options.
  local bar(label, options={}, custom={}) =
    g.panel.barChart.new(label)
    + g.panel.barChart.withTargets(targets)
    + g.panel.barChart.withOptions(options)
    + g.panel.barChart.withFieldConfigDefaults({ custom: custom }),

  local groups = [
    { title: 'Orientation', panels: {
      auto: bar('Auto', { orientation: 'auto' }),
      horizontal: bar('Horizontal', { orientation: 'horizontal' }),
    } },
    { title: 'Stacking', panels: {
      none: bar('None', { orientation: 'auto' }, { stacking: { mode: 'none' } }),
      normal: bar('Normal', { orientation: 'auto' }, { stacking: { mode: 'normal' } }),
      percent: bar('Percent', { orientation: 'auto' }, { stacking: { mode: 'percent' } }),
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
    g.dashboard.new('Panel / Bar chart')
    + g.dashboard.withUid('observ-viz-panel-barChart')
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
