// observ-viz reference — rich Stat board. Demonstrates the stat panel options as
// rows of testdata-driven panels: color mode and graph mode. Uses the provisioned
// grafana-testdata datasource. Mirrors the structure of timeseries.libsonnet.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),
  local targets = [td()],  // single random-walk series reduced to one value

  // thresholds: green by default, red at/above 70
  local thr = [{ color: 'green', value: null }, { color: 'red', value: 70 }],

  // a stat panel with a target, shared reduce/thresholds/unit, plus per-panel options
  local stat(label, options) =
    g.panel.stat.new(label)
    + g.panel.stat.withTargets(targets)
    + g.panel.stat.options.reduceOptions.withCalcs(['lastNotNull'])
    + g.panel.stat.standardOptions.thresholds.withMode('absolute')
    + g.panel.stat.standardOptions.thresholds.withSteps(thr)
    + g.panel.stat.standardOptions.withUnit('short')
    + g.panel.stat.withOptions(options),

  local groups = [
    { title: 'Color mode', panels: {
      value: stat('Value', { colorMode: 'value' }),
      background: stat('Background', { colorMode: 'background' }),
      none: stat('None', { colorMode: 'none' }),
    } },
    { title: 'Graph mode', panels: {
      area: stat('Area', { graphMode: 'area' }),
      none: stat('None', { graphMode: 'none' }),
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
    g.dashboard.new('Panel / Stat')
    + g.dashboard.withUid('observ-viz-panel-stat')
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
