// observ-viz common-lib hardware panel presets.
// Ported from grafana/jsonnet-libs common-lib/common/panels/hardware.
local g = import 'g.libsonnet';
local generic = import 'libs/common-lib/panels/generic.libsonnet';
local ts = g.panel.timeSeries;

{
  // ---- timeSeries -------------------------------------------------------
  // base: plain hardware time series (generic styling).
  timeSeries(title='', targets=[], description=''):
    generic.timeSeries(title, targets, description),

  // temperature: sensor values with cold->hot scheme gradient.
  temperature(title='Temperature', targets=[], description='', softMin=0, softMax=100, unit='celsius'):
    generic.timeSeries(title, targets, description)
    + ts.withFieldConfigDefaults({ custom+: { axisSoftMax: softMax, axisSoftMin: softMin } })
    + ts.standardOptions.withDecimals(1)
    + ts.standardOptions.withUnit(unit)
    + ts.withFieldConfigDefaults({ color+: { mode: 'continuous-BlYlRd' } })
    + ts.custom.withGradientMode('scheme'),
}
