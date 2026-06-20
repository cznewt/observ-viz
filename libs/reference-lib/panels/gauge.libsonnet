// observ-viz reference — Gauge board. Demonstrates the gauge panel options as
// rows of testdata-driven panels: threshold steps with min/max, and the
// threshold marker/label toggles. Uses the provisioned grafana-testdata
// datasource (uid "testdata").
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),
  local targets = [td()],

  // green/yellow/red threshold steps shared across the panels.
  local thrSteps = [
    { color: 'green', value: null },
    { color: 'yellow', value: 50 },
    { color: 'red', value: 80 },
  ],

  // a gauge panel: testdata target, min/max, thresholds and gauge options.
  local gauge(label, options={}, min=0, max=100) =
    g.panel.gauge.new(label)
    + g.panel.gauge.withTargets(targets)
    + g.panel.gauge.withMin(min)
    + g.panel.gauge.withMax(max)
    + g.panel.gauge.withThresholds(thrSteps)
    + g.panel.gauge.withOptions(options),

  local groups = [
    { title: 'Thresholds', panels: {
      base: gauge('Green / Yellow / Red'),
      wide: gauge('Min 0 / Max 100', {}, 0, 100),
    } },
    { title: 'Markers', panels: {
      markers: gauge('Markers on', { showThresholdMarkers: true, showThresholdLabels: false }),
      'no-markers': gauge('Markers off', { showThresholdMarkers: false, showThresholdLabels: false }),
      labels: gauge('Labels on', { showThresholdMarkers: true, showThresholdLabels: true }),
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
    g.dashboard.new('Panel / Gauge')
    + g.dashboard.withUid('observ-viz-panel-gauge')
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
