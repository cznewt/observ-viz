// observ-viz reference — Bar gauge board. Demonstrates the barGauge style
// options as rows of testdata-driven panels: display mode (basic/gradient/lcd)
// and orientation (horizontal/vertical). Each panel carries thresholds plus a
// min/max range. Uses the provisioned grafana-testdata datasource.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') =
    g.query.base('grafana-testdata-datasource', { scenarioId: scn })
    + g.query.withDatasource(ds),
  local targets = [td(), td(), td(), td()],  // 4 random-walk series

  local thr = [
    { color: 'green', value: null },
    { color: 'yellow', value: 40 },
    { color: 'red', value: 70 },
  ],

  // a barGauge panel: shared targets + thresholds + min/max, plus the
  // per-variation options passed through the generic withOptions setter.
  local bg(label, options) =
    g.panel.barGauge.new(label)
    + g.panel.barGauge.withTargets(targets)
    + g.panel.barGauge.withMin(0)
    + g.panel.barGauge.withMax(100)
    + g.panel.barGauge.withThresholds(thr)
    + g.panel.barGauge.withOptions(options),

  local groups = [
    { title: 'Display mode', panels: {
      basic: bg('Basic', { displayMode: 'basic' }),
      gradient: bg('Gradient', { displayMode: 'gradient' }),
      lcd: bg('LCD', { displayMode: 'lcd' }),
    } },
    { title: 'Orientation', panels: {
      horizontal: bg('Horizontal', { orientation: 'horizontal', displayMode: 'gradient' }),
      vertical: bg('Vertical', { orientation: 'vertical', displayMode: 'gradient' }),
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
    g.dashboard.new('Panel / Bar gauge')
    + g.dashboard.withUid('observ-viz-panel-barGauge')
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
