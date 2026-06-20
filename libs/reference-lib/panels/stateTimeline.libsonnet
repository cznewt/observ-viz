// observ-viz reference — State timeline board. Demonstrates the state-timeline
// viz options as rows of testdata-driven panels: merge values and row height.
// A random_walk scenario feeds numeric samples that value mappings turn into
// named states. Uses the provisioned grafana-testdata datasource.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),
  local targets = [td(), td()],  // 2 random-walk series mapped to states

  // value mappings turn the numeric random_walk samples into named states.
  local mappings = [
    { type: 'range', options: { from: -1000000, to: 0, result: { text: 'Low', color: 'red', index: 0 } } },
    { type: 'range', options: { from: 0, to: 50, result: { text: 'Mid', color: 'orange', index: 1 } } },
    { type: 'range', options: { from: 50, to: 1000000, result: { text: 'High', color: 'green', index: 2 } } },
  ],

  // a state-timeline panel: targets + value mappings + custom/options overrides.
  local stl(label, options={}, custom={}) =
    g.panel.stateTimeline.new(label)
    + g.panel.stateTimeline.withTargets(targets)
    + g.panel.stateTimeline.withFieldConfigDefaults({ mappings: mappings, custom: custom })
    + g.panel.stateTimeline.withOptions({ showValue: 'auto', legend: { displayMode: 'list', placement: 'bottom' } } + options),

  local groups = [
    { title: 'Merge values', panels: {
      merged: stl('Merged', { mergeValues: true }),
      unmerged: stl('Unmerged', { mergeValues: false }),
    } },
    { title: 'Row height', panels: {
      thin: stl('Thin', { rowHeight: 0.5 }),
      thick: stl('Thick', { rowHeight: 0.9 }),
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
    g.dashboard.new('Panel / State timeline')
    + g.dashboard.withUid('observ-viz-panel-stateTimeline')
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
