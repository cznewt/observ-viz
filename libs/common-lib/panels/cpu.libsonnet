// observ-viz common-lib CPU panel presets.
// Ported from grafana/jsonnet-libs common-lib/common/panels/cpu.
local g = import 'g.libsonnet';
local generic = import 'libs/common-lib/panels/generic.libsonnet';
local ts = g.panel.timeSeries;
local st = g.panel.stat;

{
  // ---- timeSeries -------------------------------------------------------
  // base: plain CPU time series (generic styling).
  timeSeries(title='CPU usage', targets=[], description=''):
    generic.timeSeries(title, targets, description),

  // utilization: percentage view (0-100%, cold->hot, scheme gradient).
  utilization(title='CPU usage', targets=[], description=''):
    generic.timeSeriesPercentage(title, targets, description),

  // utilizationByMode: stacked percent by mode with per-mode colors.
  utilizationByMode(title='CPU usage by modes', targets=[], description='CPU usage by different modes.'):
    generic.timeSeries(title, targets, description)
    + ts.standardOptions.withUnit('percent')
    + ts.custom.withFillOpacity(80)
    + ts.standardOptions.withMax(100)
    + ts.standardOptions.withMin(0)
    + ts.custom.stacking.withMode('normal')
    + ts.standardOptions.withOverrides([
      {
        matcher: { id: 'byName', options: 'idle' },
        properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'light-blue' } }],
      },
      {
        matcher: { id: 'byName', options: 'interrupt' },
        properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'light-purple' } }],
      },
      {
        matcher: { id: 'byName', options: 'user' },
        properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'light-orange' } }],
      },
      {
        matcher: { id: 'byRegexp', options: 'system|privileged' },
        properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'light-red' } }],
      },
    ]),

  // ---- stat -------------------------------------------------------------
  // base: plain CPU stat (generic styling).
  stat(title='CPU usage', targets=[], description=''):
    generic.stat(title, targets, description),

  // usage: 0-100% gauge stat with cold->hot value coloring.
  usage(title='CPU usage', targets=[], description=''):
    generic.statPercentage(title, targets, description),

  // count: number of CPU cores (info stat, unitless).
  count(title='CPU count', targets=[], description=''):
    generic.statInfo(title, targets, description)
    + st.standardOptions.withUnit('none'),
}
