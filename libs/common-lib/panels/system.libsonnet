// observ-viz common-lib system panel presets.
// Ported from grafana/jsonnet-libs common-lib/common/panels/system.
local g = import 'g.libsonnet';
local generic = import 'libs/common-lib/panels/generic.libsonnet';
local ts = g.panel.timeSeries;
local st = g.panel.stat;
local sh = g.panel.statusHistory;

{
  // ---- timeSeries -------------------------------------------------------
  // base: plain system time series (generic styling).
  timeSeries(title='', targets=[], description=''):
    generic.timeSeries(title, targets, description),

  // loadAverage: system load averages, unitless lines with no fill.
  loadAverage(title='Load average', targets=[], description=''):
    generic.timeSeries(title, targets, description)
    + ts.custom.withFillOpacity(0)
    + ts.standardOptions.withMin(0)
    + ts.standardOptions.withUnit('short'),

  // ---- stat -------------------------------------------------------------
  // base: plain system stat (generic styling).
  stat(title='', targets=[], description=''):
    generic.stat(title, targets, description),

  // uptime: time since last reboot; warns (orange) on reset, clears after 10m.
  uptime(title='Uptime', targets=[], description='The duration of time that has passed since the last reboot or system start.'):
    generic.stat(title, targets, description)
    + st.options.reduceOptions.withCalcs(['lastNotNull'])
    + st.standardOptions.withDecimals(1)
    + st.standardOptions.withUnit('dtdurations')
    + st.withFieldConfigDefaults({ color+: { mode: 'thresholds' } })
    + st.options.withColorMode('value')
    + st.options.withGraphMode('none')
    + st.standardOptions.thresholds.withMode('absolute')
    + st.standardOptions.thresholds.withSteps([
      { color: 'orange', value: null },
      { color: 'text', value: 600 },
    ]),

  // ---- table ------------------------------------------------------------
  // base: plain system table (generic styling).
  table(title='', targets=[], description=''):
    generic.table(title, targets, description),

  // ---- statusHistory ----------------------------------------------------
  // ntp: NTP sync state with in-sync / not-in-sync mappings.
  ntp(title='NTP status', targets=[], description=''):
    generic.statusHistory(title, targets, description)
    + sh.withFieldConfigDefaults({ color+: { mode: 'fixed' } })
    + sh.withMappings([{
      type: 'value',
      options: {
        '0': { text: 'Not in sync', color: 'light-yellow', index: 1 },
        '1': { text: 'In sync', color: 'light-green', index: 0 },
      },
    }]),
}
