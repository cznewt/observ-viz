// observ-viz reference — Flame graph board. The panel renders a profile, so the
// board carries a Pyroscope datasource variable and asks for the two profiles
// every Go service exposes: CPU time and in-use heap.
local g = import 'g.libsonnet';

function(config) {
  local ds = '${pyroscope_datasource}',
  local profile(profileTypeId, selector='{}') =
    g.query.base('grafana-pyroscope-datasource', {
      queryType: 'profile',
      profileTypeId: profileTypeId,
      labelSelector: selector,
      groupBy: [],
    })
    + g.query.withDatasource(ds),

  local flame(label, profileTypeId, options={}) =
    g.panel.flameGraph.new(label)
    + g.panel.flameGraph.withTargets([profile(profileTypeId)])
    + g.panel.flameGraph.withOptions(options),

  local rows = [
    {
      title: 'Profiles',
      keys: ['cpu', 'heap'],
      elements: {
        cpu: flame('CPU time', 'process_cpu:cpu:nanoseconds:cpu:nanoseconds'),
        heap: flame('Heap in use', 'memory:inuse_space:bytes:space:bytes'),
      },
    },
    {
      title: 'Options',
      keys: ['sandwich', 'topTable'],
      elements: {
        // collapsing merges identical stacks; the "both" view puts the flame
        // graph next to the top-functions table.
        sandwich: flame('No collapsing', 'process_cpu:cpu:nanoseconds:cpu:nanoseconds', { collapsing: false }),
        topTable: flame('Table and graph', 'process_cpu:cpu:nanoseconds:cpu:nanoseconds', { selectedView: 'both' }),
      },
    },
  ],

  board:
    g.dashboard.new('Flame graph')
    + g.dashboard.withUid('observ-viz-panel-flameGraph')
    + g.dashboard.withVariables([
      g.variable.datasource.new('pyroscope_datasource', 'grafana-pyroscope-datasource')
      + g.variable.datasource.withLabel('Pyroscope'),
    ])
    + g.dashboard.withElements(std.foldl(function(acc, r) acc + r.elements, rows, {}))
    + g.dashboard.withLayout(
      g.layout.rows.new()
      + g.layout.rows.withRows([
        g.layout.rows.row(
          r.title,
          g.layout.grid.new() + g.layout.grid.withItems(g.util.grid.wrapItems(r.keys, 12, 11))
        )
        for r in rows
      ])
    ),
}
