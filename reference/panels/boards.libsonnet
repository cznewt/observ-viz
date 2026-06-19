// observ-viz reference — Panels folder. Every panel type is a TABBED board:
// tab 1 "Overview" (description + Grafana docs link), then example tabs. Data
// panels get rich testdata-driven examples (ported from the models/catalog
// reference-mixin); the rest are a single example panel.
local g = import 'g.libsonnet';
local place = (import 'reference/_util.libsonnet').place;
local tabbed = (import 'reference/panels/_tab.libsonnet').tabbed;

// rich example boards: function(config) -> { board }
local rich = {
  timeSeries: import 'reference/panels/timeseries.libsonnet',
  stat: import 'reference/panels/stat.libsonnet',
  gauge: import 'reference/panels/gauge.libsonnet',
  barGauge: import 'reference/panels/barGauge.libsonnet',
  pieChart: import 'reference/panels/pieChart.libsonnet',
  barChart: import 'reference/panels/barChart.libsonnet',
  histogram: import 'reference/panels/histogram.libsonnet',
  heatmap: import 'reference/panels/heatmap.libsonnet',
  table: import 'reference/panels/table.libsonnet',
  stateTimeline: import 'reference/panels/stateTimeline.libsonnet',
  statusHistory: import 'reference/panels/statusHistory.libsonnet',
  candlestick: import 'reference/panels/candlestick.libsonnet',
  trend: import 'reference/panels/trend.libsonnet',
  xyChart: import 'reference/panels/xyChart.libsonnet',
};

local label = {
  timeSeries: 'Time series',
  barChart: 'Bar chart',
  histogram: 'Histogram',
  heatmap: 'Heatmap',
  stat: 'Stat',
  gauge: 'Gauge',
  barGauge: 'Bar gauge',
  pieChart: 'Pie chart',
  table: 'Table',
  stateTimeline: 'State timeline',
  statusHistory: 'Status history',
  candlestick: 'Candlestick',
  trend: 'Trend',
  xyChart: 'XY chart',
  text: 'Text',
  logs: 'Logs',
  news: 'News',
  dashList: 'Dashboard list',
  alertList: 'Alert list',
  annotationsList: 'Annotations list',
  nodeGraph: 'Node graph',
  traces: 'Traces',
  flameGraph: 'Flame graph',
  geomap: 'Geomap',
  canvas: 'Canvas',
};

// panel types without a rich example board -> a single example panel.
local simpleKinds = [
  'text', 'logs', 'news', 'dashList', 'alertList', 'annotationsList',
  'nodeGraph', 'traces', 'flameGraph', 'geomap', 'canvas',
];

local simpleBoard(name) =
  local panel =
    g.panel[name].new(label[name])
    + (if name == 'text' then g.panel.text.withOptions({ mode: 'markdown', content: '# ' + label[name] + '\n\nobserv-viz panel reference.' }) else {});
  g.dashboard.new('Panel / ' + label[name])
  + g.dashboard.withUid('observ-viz-panel-' + name)
  + g.dashboard.withElements(g.element.panel('panel', panel))
  + g.dashboard.withLayout(g.layout.grid.new() + g.layout.grid.withItems([g.layout.grid.item('panel', 0, 0, 16, 9)]));

{
  _config+:: {},
  grafanaDashboards+:: {
    ['panel-' + name + '.json']:
      place(tabbed(rich[name]($._config).board, name, label[name]), $._config.folders.panels, $._config.tags)
    for name in std.objectFields(rich)
  } + {
    ['panel-' + name + '.json']:
      place(tabbed(simpleBoard(name), name, label[name]), $._config.folders.panels, $._config.tags)
    for name in simpleKinds
  },
}
