// observ-viz common reusable panels (hand-written).
// Thin pre-styled panel builders for frequent cases; take targets directly.
local panel = import 'custom/panel.libsonnet';

{
  cpu(title='CPU usage', targets=[]):
    panel.timeSeries.new(title)
    + panel.timeSeries.withTargets(targets)
    + panel.timeSeries.standardOptions.withUnit('percentunit')
    + panel.timeSeries.standardOptions.withMin(0)
    + panel.timeSeries.custom.withFillOpacity(10),

  memory(title='Memory usage', targets=[]):
    panel.timeSeries.new(title)
    + panel.timeSeries.withTargets(targets)
    + panel.timeSeries.standardOptions.withUnit('bytes')
    + panel.timeSeries.standardOptions.withMin(0),

  requests(title='Requests', targets=[]):
    panel.timeSeries.new(title)
    + panel.timeSeries.withTargets(targets)
    + panel.timeSeries.standardOptions.withUnit('reqps')
    + panel.timeSeries.standardOptions.withMin(0)
    + panel.timeSeries.custom.withFillOpacity(100)
    + panel.timeSeries.custom.withLineWidth(0)
    + panel.timeSeries.custom.stacking.withMode('normal'),

  statShort(title, targets=[]):
    panel.stat.new(title)
    + panel.stat.withTargets(targets)
    + panel.stat.standardOptions.withUnit('short'),
}
