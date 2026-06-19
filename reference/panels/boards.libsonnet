// observ-viz reference — Panels folder. One board per Grafana panel type.
local g = import 'g.libsonnet';
local place = (import 'reference/_util.libsonnet').place;

// friendly builder name -> display label (the full Grafana panel set)
local kinds = [
  ['timeSeries', 'Time series'],
  ['barChart', 'Bar chart'],
  ['histogram', 'Histogram'],
  ['heatmap', 'Heatmap'],
  ['stat', 'Stat'],
  ['gauge', 'Gauge'],
  ['barGauge', 'Bar gauge'],
  ['pieChart', 'Pie chart'],
  ['table', 'Table'],
  ['stateTimeline', 'State timeline'],
  ['statusHistory', 'Status history'],
  ['text', 'Text'],
  ['logs', 'Logs'],
  ['news', 'News'],
  ['dashList', 'Dashboard list'],
  ['alertList', 'Alert list'],
  ['annotationsList', 'Annotations list'],
  ['nodeGraph', 'Node graph'],
  ['traces', 'Traces'],
  ['flameGraph', 'Flame graph'],
  ['geomap', 'Geomap'],
  ['canvas', 'Canvas'],
  ['candlestick', 'Candlestick'],
  ['trend', 'Trend'],
  ['xyChart', 'XY chart'],
];

// kinds that render a metric query
local dataKinds = [
  'timeSeries', 'barChart', 'histogram', 'heatmap', 'stat', 'gauge', 'barGauge',
  'pieChart', 'table', 'stateTimeline', 'statusHistory', 'candlestick', 'trend', 'xyChart',
];

local board(name, label, cfg) =
  local panel =
    g.panel[name].new(label)
    + (if std.count(dataKinds, name) > 0 then g.panel[name].withTargets([g.query.prometheus.new(cfg.datasource, 'up')]) else {})
    + (if name == 'text' then g.panel.text.withOptions({ mode: 'markdown', content: '# ' + label + '\n\nobserv-viz panel reference.' }) else {});
  g.dashboard.new('Panel / ' + label)
  + g.dashboard.withUid('observ-viz-panel-' + name)
  + g.dashboard.withVariables([
    g.variable.datasource.new('datasource', 'prometheus') + g.variable.datasource.withLabel('Data source'),
  ])
  + g.dashboard.withElements(g.element.panel('panel', panel))
  + g.dashboard.withLayout(g.layout.grid.new() + g.layout.grid.withItems([g.layout.grid.item('panel', 0, 0, 16, 9)]));

{
  _config+:: {},
  grafanaDashboards+:: {
    ['panel-' + k[0] + '.json']: place(board(k[0], k[1], $._config), $._config.folders.panels, $._config.tags)
    for k in kinds
  },
}
