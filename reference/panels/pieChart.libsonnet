// observ-viz reference — Pie chart board. Demonstrates the pieChart viz options
// as rows of testdata-driven panels: pie type (pie/donut) and legend
// (display mode + placement). Uses the provisioned grafana-testdata datasource.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),
  // 5 random-walk series -> 5 slices in the pie.
  local targets = [td(), td(), td(), td(), td()],

  // a pieChart panel with custom options merged over a sensible base.
  local pie(label, options) =
    g.panel.pieChart.new(label)
    + g.panel.pieChart.withTargets(targets)
    + g.panel.pieChart.withOptions({
      reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
      displayLabels: ['name', 'percent'],
      tooltip: { mode: 'single', sort: 'none' },
    } + options),

  local groups = [
    { title: 'Type', panels: {
      pie: pie('Pie', { pieType: 'pie' }),
      donut: pie('Donut', { pieType: 'donut' }),
    } },
    { title: 'Legend', panels: {
      'list-right': pie('List / right', { legend: { displayMode: 'list', placement: 'right' } }),
      'list-bottom': pie('List / bottom', { legend: { displayMode: 'list', placement: 'bottom' } }),
      'table-right': pie('Table / right', { legend: { displayMode: 'table', placement: 'right' } }),
      'table-bottom': pie('Table / bottom', { legend: { displayMode: 'table', placement: 'bottom' } }),
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
    g.dashboard.new('Panel / Pie chart')
    + g.dashboard.withUid('observ-viz-panel-pieChart')
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
