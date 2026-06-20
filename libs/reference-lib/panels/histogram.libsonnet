// observ-viz reference — Histogram board. Demonstrates the histogram panel
// options as rows of testdata-driven panels: bucket size and series combine.
// histogram has no rich generated setters, so option/custom values go through
// the generic g.panel.histogram.withOptions / .withFieldConfigDefaults setters.
// Uses the provisioned grafana-testdata datasource.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),
  local targets = [td(), td(), td()],  // 3 random-walk series

  // a histogram panel: shared targets + generic options/custom fieldConfig.
  local hist(label, options={}, custom={}) =
    g.panel.histogram.new(label)
    + g.panel.histogram.withTargets(targets)
    + g.panel.histogram.withOptions(options)
    + g.panel.histogram.withFieldConfigDefaults({ custom: custom }),

  local groups = [
    { title: 'Bucket size', panels: {
      b5: hist('Bucket 5', { bucketSize: 5 }),
      b10: hist('Bucket 10', { bucketSize: 10 }),
      b20: hist('Bucket 20', { bucketSize: 20 }),
    } },
    { title: 'Combine', panels: {
      on: hist('Combined', { combine: true, bucketSize: 10 }, { fillOpacity: 60 }),
      off: hist('Per series', { combine: false, bucketSize: 10 }, { fillOpacity: 40 }),
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
    g.dashboard.new('Panel / Histogram')
    + g.dashboard.withUid('observ-viz-panel-histogram')
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
