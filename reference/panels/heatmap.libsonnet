// observ-viz reference — Heatmap board. Demonstrates heatmap panel options as
// rows of testdata-driven panels: color scheme (options.color.scheme) and the
// calculate toggle (options.calculate). Uses the provisioned grafana-testdata
// datasource. Pattern mirrors reference/panels/timeseries.libsonnet.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),
  local targets = [td(), td(), td(), td()],  // several random-walk series

  // a heatmap panel with the given options merged onto sensible defaults.
  local hm(label, opts={}) =
    g.panel.heatmap.new(label)
    + g.panel.heatmap.withTargets(targets)
    + g.panel.heatmap.withOptions({
      calculate: true,
      color: { mode: 'scheme', scheme: 'Spectral', steps: 64 },
      yAxis: { axisPlacement: 'left' },
    } + opts),

  local groups = [
    { title: 'Color scheme', panels: {
      spectral: hm('Spectral', { color: { mode: 'scheme', scheme: 'Spectral', steps: 64 } }),
      greens: hm('Greens', { color: { mode: 'scheme', scheme: 'Greens', steps: 64 } }),
      blues: hm('Blues', { color: { mode: 'scheme', scheme: 'Blues', steps: 64 } }),
      rdylgn: hm('RdYlGn', { color: { mode: 'scheme', scheme: 'RdYlGn', steps: 64 } }),
    } },
    { title: 'Calculate', panels: {
      on: hm('Calculate on', { calculate: true }),
      off: hm('Calculate off', { calculate: false }),
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
    g.dashboard.new('Panel / Heatmap')
    + g.dashboard.withUid('observ-viz-panel-heatmap')
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
