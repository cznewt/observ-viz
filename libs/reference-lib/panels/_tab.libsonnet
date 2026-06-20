// observ-viz reference — panel-board tabbing. Wraps a panel reference board so
// the FIRST tab is an "Overview" (panel description + a link to the Grafana
// docs), and the remaining tabs are the board's example rows.
local g = import 'g.libsonnet';

// friendly type -> { slug (grafana docs), desc }
local docs = {
  timeSeries: { slug: 'time-series', desc: 'The default graph for time-based data — lines, bars or points over time.' },
  barChart: { slug: 'bar-chart', desc: 'Categorical data as vertical or horizontal bars.' },
  histogram: { slug: 'histogram', desc: 'The distribution of values into buckets.' },
  heatmap: { slug: 'heatmap', desc: 'Value density over time as a colour grid.' },
  stat: { slug: 'stat', desc: 'A big single value, optionally with a sparkline and coloured background.' },
  gauge: { slug: 'gauge', desc: 'A value against a min/max range with threshold markers.' },
  barGauge: { slug: 'bar-gauge', desc: 'A horizontal/vertical bar gauge per series.' },
  pieChart: { slug: 'pie-chart', desc: 'Series as proportional slices of a pie or donut.' },
  table: { slug: 'table', desc: 'Tabular data with cell colouring, gauges and sparklines.' },
  stateTimeline: { slug: 'state-timeline', desc: 'State changes over time as coloured segments.' },
  statusHistory: { slug: 'status-history', desc: 'Periodic state as a grid of coloured cells.' },
  text: { slug: 'text', desc: 'Static markdown or HTML content.' },
  logs: { slug: 'logs', desc: 'Log lines from a logs datasource (e.g. Loki).' },
  news: { slug: 'news', desc: 'An RSS/Atom feed reader.' },
  dashList: { slug: 'dashboard-list', desc: 'A list of dashboards (starred, recent, by tag).' },
  alertList: { slug: 'alert-list', desc: 'Current alert instances, filtered by labels/state.' },
  annotationsList: { slug: 'annotations-list', desc: 'A list of annotations.' },
  nodeGraph: { slug: 'node-graph', desc: 'Directed graph of nodes and edges.' },
  traces: { slug: 'traces', desc: 'Distributed traces from a tracing datasource (e.g. Tempo).' },
  flameGraph: { slug: 'flame-graph', desc: 'Profiling data as a flame graph (e.g. Pyroscope).' },
  geomap: { slug: 'geomap', desc: 'Geospatial data on a map.' },
  canvas: { slug: 'canvas', desc: 'A free-form canvas of elements bound to data.' },
  candlestick: { slug: 'candlestick', desc: 'OHLC financial data as candles.' },
  trend: { slug: 'trend', desc: 'Like time series but plotted against a non-time x-axis.' },
  xyChart: { slug: 'xy-chart', desc: 'Arbitrary x/y scatter of two fields.' },
};

{
  // tabbed(board, type, title): board (a built dashboard with a Grid or Rows
  // layout) -> a TabsLayout board: Overview tab + one tab per row (or a single
  // example tab for grid boards).
  tabbed(board, type, title)::
    local d = if std.objectHas(docs, type) then docs[type] else { slug: '', desc: '' };
    local overview =
      g.panel.text.new('Overview')
      + g.panel.text.withOptions({
        mode: 'markdown',
        content: '# ' + title + '\n\n' + d.desc
                 + (if d.slug != ''
                    then '\n\n[Grafana docs ↗](https://grafana.com/docs/grafana/latest/panels-visualizations/visualizations/' + d.slug + '/)'
                    else ''),
      });
    local lay = board.spec.layout;
    local exampleTabs =
      if lay.kind == 'RowsLayout'
      then [g.layout.tabs.tab(r.spec.title, r.spec.layout) for r in lay.spec.rows]
      else [g.layout.tabs.tab('Example', lay)];
    local overviewTab =
      g.layout.tabs.tab('Overview', g.layout.grid.new() + g.layout.grid.withItems([g.layout.grid.item('__overview', 0, 0, 24, 8)]));
    board + {
      spec+: {
        elements+: g.element.panel('__overview', overview),
        layout: g.layout.tabs.new() + g.layout.tabs.withTabs([overviewTab] + exampleTabs),
      },
    },
}
