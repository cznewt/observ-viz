// Reference "panel gallery" board — one of every Grafana panel type, built with
// observ-viz typed builders. Proves every panel plugin is reachable.
local g = import 'g.libsonnet';

function(config) {
  local ds = config.datasource,
  local target = g.query.prometheus.new(ds, 'up'),

  // panels that render a data query
  local dataPanels = [
    'timeSeries', 'barChart', 'histogram', 'heatmap', 'stat', 'gauge', 'barGauge',
    'pieChart', 'table', 'stateTimeline', 'statusHistory', 'candlestick', 'trend', 'xyChart',
  ],
  // panels that don't take a metric query
  local otherPanels = [
    'text', 'logs', 'news', 'dashList', 'alertList', 'annotationsList',
    'nodeGraph', 'traces', 'flameGraph', 'geomap', 'canvas',
  ],
  local all = dataPanels + otherPanels,

  elements: {
    [name]:
      g.panel[name].new(name)
      + (if std.count(dataPanels, name) > 0 then g.panel[name].withTargets([target]) else {})
      + (if name == 'text' then g.panel.text.withOptions({ mode: 'markdown', content: '# observ-viz\nEvery Grafana panel type, as code.' }) else {})
    for name in all
  },

  board:
    g.dashboard.new('Reference / Panels')
    + g.dashboard.withUid('reference-panels')
    + g.dashboard.withVariables([
      g.variable.datasource.new('datasource', 'prometheus')
      + g.variable.datasource.withLabel('Data source'),
    ])
    + g.dashboard.withElements(self.elements)
    + g.dashboard.withLayout(g.layout.grid.fromElements(std.objectFields(self.elements), 6, 7)),
}
