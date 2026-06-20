// observ-viz reference — Panels folder. Every panel type is a TABBED board:
// tab 1 "Overview" (description + Grafana docs link), then example tabs. Data
// panels get rich testdata-driven examples (ported from the models/catalog
// reference-mixin); the rest are a single example panel.
local g = import 'g.libsonnet';
local place = (import 'libs/reference-lib/_util.libsonnet').place;
local tabbed = (import 'libs/reference-lib/panels/_tab.libsonnet').tabbed;

// rich example boards: function(config) -> { board }
local rich = {
  timeSeries: import 'libs/reference-lib/panels/timeseries.libsonnet',
  stat: import 'libs/reference-lib/panels/stat.libsonnet',
  gauge: import 'libs/reference-lib/panels/gauge.libsonnet',
  barGauge: import 'libs/reference-lib/panels/barGauge.libsonnet',
  pieChart: import 'libs/reference-lib/panels/pieChart.libsonnet',
  barChart: import 'libs/reference-lib/panels/barChart.libsonnet',
  histogram: import 'libs/reference-lib/panels/histogram.libsonnet',
  heatmap: import 'libs/reference-lib/panels/heatmap.libsonnet',
  table: import 'libs/reference-lib/panels/table.libsonnet',
  stateTimeline: import 'libs/reference-lib/panels/stateTimeline.libsonnet',
  statusHistory: import 'libs/reference-lib/panels/statusHistory.libsonnet',
  candlestick: import 'libs/reference-lib/panels/candlestick.libsonnet',
  trend: import 'libs/reference-lib/panels/trend.libsonnet',
  xyChart: import 'libs/reference-lib/panels/xyChart.libsonnet',
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

// example content for the panels that don't need a special datasource.
local example(name) =
  local p = g.panel[name].new(label[name]);
  if name == 'text' then
    p + g.panel.text.withOptions({ mode: 'markdown', content: '# ' + label[name] + '\n\nStatic markdown or HTML content.\n\n- bullet one\n- bullet two' })
  else if name == 'logs' then
    p
    + g.panel.logs.withTargets([g.query.base('loki', { expr: '{container=~"observ-viz-app-.+"}' }) + g.query.withDatasource('loki')])
    + g.panel.logs.withOptions({ showTime: true, wrapLogMessage: true, enableLogDetails: true, dedupStrategy: 'none', sortOrder: 'Descending' })
  else if name == 'alertList' then
    p + g.panel.alertList.withOptions({ dashboardAlerts: false, maxItems: 20, sortOrder: 1, viewMode: 'list', groupMode: 'default' })
  else if name == 'dashList' then
    p + g.panel.dashList.withOptions({ showStarred: false, showRecentlyViewed: true, showSearch: false, maxItems: 10, query: '', tags: [] })
  else if name == 'news' then
    p + g.panel.news.withOptions({ feedUrl: 'https://grafana.com/blog/news.xml', showImage: true })
  else if name == 'annotationsList' then
    p + g.panel.annotationsList.withOptions({ limit: 10, onlyFromThisDashboard: false, showTags: true, showTime: true })
  else p;

local simpleBoard(name) =
  g.dashboard.new('Panel / ' + label[name])
  + g.dashboard.withUid('observ-viz-panel-' + name)
  + g.dashboard.withElements(g.element.panel('panel', example(name)))
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
