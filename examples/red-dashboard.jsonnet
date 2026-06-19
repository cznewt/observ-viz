// RED dashboard built from signals: define elements once, reference by name.
local g = import 'g.libsonnet';

local ds = '${datasource}';

// signals -> elements
local rate = g.library.signals.requestRate(ds, 'job="$job"');
local errors = g.library.signals.errorRatio(ds, 'job="$job"');
local latency = g.library.signals.latencyP95(ds, 'job="$job"');

local elements =
  g.element.panel('rate', rate.asTimeSeries('Request rate'))
  + g.element.panel('errors', errors.asTimeSeries('Error ratio'))
  + g.element.panel('latency', latency.asTimeSeries('p95 latency'));

local layout =
  g.layout.grid.new()
  + g.layout.grid.withItems([
    g.layout.grid.item('rate', 0, 0, 8, 8),
    g.layout.grid.item('errors', 8, 0, 8, 8),
    g.layout.grid.item('latency', 16, 0, 8, 8),
  ]);

local dashboard =
  g.dashboard.new('RED — HTTP service')
  + g.dashboard.withUid('red-http-service')
  + g.dashboard.withTags(['red', 'service-level'])
  + g.dashboard.cursorSync.withCrosshair()
  + g.dashboard.withVariables([
    g.variable.datasource.new('datasource', 'prometheus')
    + g.variable.datasource.withLabel('Metrics'),
    g.variable.query.new('job')
    + g.variable.query.withLabel('Job')
    + g.variable.query.withLabelValues('job', 'up'),
  ])
  + g.dashboard.withTimeSettings(
    g.timeSettings.withFrom('now-1h') + g.timeSettings.withTo('now') + g.timeSettings.withAutoRefresh('30s')
  )
  + g.dashboard.withAnnotations([
    g.annotation.builtinAnnotation(),
    g.deploy.annotations.deploys(ds, 'job="$job"'),
  ])
  + g.dashboard.withElements(elements)
  + g.dashboard.withLayout(layout);

dashboard.toResource()
