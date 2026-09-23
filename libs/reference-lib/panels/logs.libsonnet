// observ-viz reference — Logs board. The panel needs a real logs datasource, so
// the board carries a Loki datasource variable (it defaults to the first Loki
// in the org) and queries whatever namespaces that Loki holds, capped at a
// hundred lines per panel - a reference board should not pull a day of logs.
local g = import 'g.libsonnet';

function(config) {
  local ds = '${loki_datasource}',
  // maxLines is the panel's line limit; without it Loki answers with its own
  // default (1000) and the panel scrolls forever.
  local logq(expr, maxLines=100) =
    g.query.loki.new(ds, expr) + { spec+: { query+: { spec+: { maxLines: maxLines } } } },

  local logs(label, expr, options={}) =
    g.panel.logs.new(label)
    + g.panel.logs.withTargets([logq(expr)])
    + g.panel.logs.withOptions({
      showTime: true,
      wrapLogMessage: true,
      enableLogDetails: true,
      dedupStrategy: 'none',
      sortOrder: 'Descending',
    } + options),

  local rows = [
    {
      title: 'Streams',
      keys: ['recent', 'errors'],
      elements: {
        recent: logs('Recent lines', '{namespace=~".+"}'),
        // |= is a line filter: the substring has to appear in the line
        errors: logs('Lines matching "error"', '{namespace=~".+"} |= `error`'),
      },
    },
    {
      title: 'Options',
      keys: ['ascending', 'nowrap'],
      elements: {
        ascending: logs('Oldest first', '{namespace=~".+"}', { sortOrder: 'Ascending' }),
        nowrap: logs('No wrapping, no timestamps', '{namespace=~".+"}', { wrapLogMessage: false, showTime: false }),
      },
    },
  ],

  board:
    g.dashboard.new('Logs')
    + g.dashboard.withUid('observ-viz-panel-logs')
    + g.dashboard.withVariables([
      g.variable.datasource.new('loki_datasource', 'loki') + g.variable.datasource.withLabel('Loki'),
    ])
    + g.dashboard.withElements(std.foldl(function(acc, r) acc + r.elements, rows, {}))
    + g.dashboard.withLayout(
      g.layout.rows.new()
      + g.layout.rows.withRows([
        g.layout.rows.row(
          r.title,
          g.layout.grid.new() + g.layout.grid.withItems(g.util.grid.wrapItems(r.keys, 12, 10))
        )
        for r in rows
      ])
    ),
}
