// observ-viz common-lib memory panel presets.
// Ported from grafana/jsonnet-libs common-lib/common/panels/memory.
local g = import 'g.libsonnet';
local generic = import 'libs/common-lib/panels/generic.libsonnet';
local ts = g.panel.timeSeries;
local st = g.panel.stat;

// 'total' series rendered as a dashed threshold-like line.
local totalThresholdOverride(regexp) = ts.standardOptions.withOverrides([
  {
    matcher: { id: 'byRegexp', options: regexp },
    properties: [
      { id: 'custom.lineStyle', value: { fill: 'dash', dash: [10, 10] } },
      { id: 'custom.fillOpacity', value: 0 },
      { id: 'color', value: { mode: 'fixed', fixedColor: '#ffb357' } },
    ],
  },
]);

{
  // ---- timeSeries -------------------------------------------------------
  // base: plain memory time series (generic styling).
  timeSeries(title='Memory usage', targets=[], description=''):
    generic.timeSeries(title, targets, description),

  // usageBytes: memory in bytes, with the 'total' line drawn as a threshold.
  usageBytes(title='Memory usage', targets=[], description='', totalRegexp='.*(T|t)otal.*'):
    generic.timeSeries(title, targets, description)
    + ts.standardOptions.withUnit('bytes')
    + ts.standardOptions.withMin(0)
    + totalThresholdOverride(totalRegexp),

  // usagePercent: 0-100% gauge view (cold->hot, scheme gradient).
  usagePercent(title='Memory usage', targets=[], description=''):
    generic.timeSeriesPercentage(title, targets, description),

  // ---- stat -------------------------------------------------------------
  // base: plain memory stat (generic styling).
  stat(title='Memory usage', targets=[], description=''):
    generic.stat(title, targets, description),

  // total: total installed RAM (info stat, bytes).
  total(title='Memory total', targets=[], description=''):
    generic.statInfo(title, targets, description)
    + st.standardOptions.withUnit('bytes'),

  // usage: 0-100% gauge stat, forced to percent unit.
  usage(title='Memory usage', targets=[], description=''):
    generic.statPercentage(title, targets, description)
    + st.standardOptions.withUnit('percent'),
}
