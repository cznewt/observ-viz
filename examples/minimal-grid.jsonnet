// Smallest valid observ-viz dashboard: one element, a grid layout, toResource().
local g = import 'g.libsonnet';

local ds = '${datasource}';

// 1) Define a reusable element (a panel).
local up =
  g.panel.timeSeries.new('Up')
  + g.panel.timeSeries.withTargets([
    g.query.prometheus.new(ds, 'up')
    + g.query.prometheus.withLegendFormat('{{instance}}'),
  ])
  + g.panel.timeSeries.standardOptions.withUnit('short')
  + g.panel.timeSeries.options.legend.withShowLegend(false);

local elements = g.element.panel('up', up);

// 2) Layout references the element BY NAME.
local layout =
  g.layout.grid.new()
  + g.layout.grid.withItems([
    g.layout.grid.item('up', 0, 0, 12, 8),
  ]);

local dashboard =
  g.dashboard.new('Minimal grid')
  + g.dashboard.withUid('minimal-grid')
  + g.dashboard.withTags(['example'])
  + g.dashboard.withVariables([
    g.variable.datasource.new('datasource', 'prometheus')
    + g.variable.datasource.withLabel('Data source'),
  ])
  + g.dashboard.withElements(elements)
  + g.dashboard.withLayout(layout);

dashboard.toResource()
