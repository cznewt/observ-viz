// observ-viz reference — Traces board. The panel renders ONE trace, which means
// it needs a trace id: TraceQL search returns a table of results, not a trace,
// so a search query leaves the panel empty. The board therefore takes the id as
// a variable - paste one from Explore or the Traces Drilldown app - and shows
// the panel's options against it.
local g = import 'g.libsonnet';

function(config) {
  local ds = '${tempo_datasource}',
  local byId(id='${traceId}') =
    g.query.base('tempo', { queryType: 'traceql', query: id, limit: 20 })
    + g.query.withDatasource(ds),

  local trace(label, options={}) =
    g.panel.traces.new(label)
    + g.panel.traces.withTargets([byId()])
    + g.panel.traces.withOptions(options),

  local help =
    g.panel.text.new('Where to get a trace id')
    + g.panel.text.withOptions({ mode: 'markdown', content: |||
      Set **Trace ID** above. Pick one in Explore with a TraceQL search
      (`{}` lists recent traces, `{duration > 100ms}` the slow ones) or open the
      Traces Drilldown app and copy the id from a trace you are looking at.

      A search query cannot drive this panel: it answers with a table of
      matches, and the panel wants the spans of a single trace.
    ||| }),

  local rows = [
    {
      title: 'Trace',
      keys: ['help', 'spans'],
      elements: {
        help: help,
        spans: trace('Spans'),
      },
    },
  ],

  board:
    g.dashboard.new('Traces')
    + g.dashboard.withUid('observ-viz-panel-traces')
    + g.dashboard.withVariables([
      g.variable.datasource.new('tempo_datasource', 'tempo') + g.variable.datasource.withLabel('Tempo'),
      g.variable.text.new('traceId') + g.variable.text.withQuery('') + { spec+: { label: 'Trace ID' } },
    ])
    + g.dashboard.withElements(std.foldl(function(acc, r) acc + r.elements, rows, {}))
    + g.dashboard.withLayout(
      g.layout.rows.new()
      + g.layout.rows.withRows([
        g.layout.rows.row(
          r.title,
          g.layout.grid.new() + g.layout.grid.withItems([
            g.layout.grid.item('help', 0, 0, 8, 12),
            g.layout.grid.item('spans', 8, 0, 16, 12),
          ])
        )
        for r in rows
      ])
    ),
}
