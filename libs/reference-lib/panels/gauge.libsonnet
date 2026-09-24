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

  // a gauge with a different value calculation / text mode
  local valueGauge(label, reduceOptions, options={}) =
    g.panel.gauge.new(label)
    + g.panel.gauge.withTargets([td(), td(), td()])
    + g.panel.gauge.withMin(0) + g.panel.gauge.withMax(100)
    + g.panel.gauge.withThresholds(thrSteps)
    + g.panel.gauge.withOptions({ reduceOptions: reduceOptions } + options),

  local groups = [
    // the standard options: where the scale starts and ends, and what the
    // colours mean along it
    { title: 'Thresholds', panels: {
      base: gauge('Green / yellow / red'),
      percentage: gauge('Thresholds by percentage')
                  + g.panel.gauge.withThresholds([
                    { color: 'green', value: null },
                    { color: 'yellow', value: 50 },
                    { color: 'red', value: 80 },
                  ], 'percentage'),
      unit: gauge('Unit and decimals')
            + g.panel.gauge.withUnit('percent')
            + g.panel.gauge.withDecimals(1),
    } },
    // what the panel draws around the value
    { title: 'Markers and labels', panels: {
      markers: gauge('Markers on', { showThresholdMarkers: true, showThresholdLabels: false }),
      'no-markers': gauge('Markers off', { showThresholdMarkers: false, showThresholdLabels: false }),
      labels: gauge('Marker labels on', { showThresholdMarkers: true, showThresholdLabels: true }),
    } },
    // the neutral point the bar grows from: 0 by default, useful at the middle
    // of a range that can go both ways
    { title: 'Neutral value', panels: {
      'neutral-zero': gauge('From zero', {}, -100, 100),
      'neutral-mid': gauge('From the middle', { neutral: 0 }, -100, 100),
    } },
    // one panel, many series: reduce them to one number or show them all
    { title: 'Value options', panels: {
      last: valueGauge('Last value', { calcs: ['lastNotNull'], values: false }),
      mean: valueGauge('Mean', { calcs: ['mean'], values: false }),
      all: valueGauge('All values', { calcs: ['lastNotNull'], values: true, limit: 6 }),
    } },
    // how big the gauges are allowed to get, and which text they carry
    { title: 'Sizing and text', panels: {
      auto: valueGauge('Auto sizing', { calcs: ['lastNotNull'], values: false }, { sizing: 'auto' }),
      manual: valueGauge('Manual sizing', { calcs: ['lastNotNull'], values: false }, { sizing: 'manual', minVizWidth: 120, minVizHeight: 120 }),
      textsize: valueGauge('Bigger value text', { calcs: ['lastNotNull'], values: false }, { text: { valueSize: 40, titleSize: 16 } }),
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
    g.dashboard.new('Gauge')
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
