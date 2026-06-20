// observ-viz common-lib requests (RED-style) panel presets.
// Ported from grafana/jsonnet-libs common-lib/common/panels/requests.
// Semantic colors: rate=light-purple, duration=blue, errors=light-red.
local g = import 'g.libsonnet';
local generic = import 'libs/common-lib/panels/generic.libsonnet';
local ts = g.panel.timeSeries;
local st = g.panel.stat;

{
  // ---- timeSeries -------------------------------------------------------
  // base: plain requests time series (generic styling).
  timeSeries(title='', targets=[], description=''):
    generic.timeSeries(title, targets, description),

  // rate: stacked request rate bars (monochrome purple shades).
  rate(title='Load / $__interval', targets=[], description='Requests rate per $__interval'):
    generic.timeSeries(title, targets, description)
    + ts.custom.withDrawStyle('bars')
    + { spec+: { data+: { spec+: { queryOptions+: { maxDataPoints: 100 } } } } }
    + ts.custom.withFillOpacity(100)
    + ts.custom.stacking.withMode('normal')
    + ts.withFieldConfigDefaults({ color+: { mode: 'shades', fixedColor: '#ca95e5' } }),

  // errors: stacked error bars (monochrome red shades).
  errors(title='Errors', targets=[], description='Request errors.'):
    generic.timeSeries(title, targets, description)
    + ts.custom.withDrawStyle('bars')
    + { spec+: { data+: { spec+: { queryOptions+: { maxDataPoints: 100 } } } } }
    + ts.custom.withFillOpacity(100)
    + ts.custom.stacking.withMode('normal')
    + ts.withFieldConfigDefaults({ color+: { mode: 'shades', fixedColor: '#ff7383' } })
    + ts.standardOptions.withNoValue('No errors'),

  // duration: response time lines in seconds (monochrome blue shades).
  duration(title='Response time', targets=[], description='Response time.'):
    generic.timeSeries(title, targets, description)
    + ts.withFieldConfigDefaults({ color+: { mode: 'shades', fixedColor: '#5794f2' } })
    + ts.standardOptions.withUnit('s'),

  // ---- stat -------------------------------------------------------------
  // base: plain requests stat (generic styling).
  stat(title='', targets=[], description=''):
    generic.stat(title, targets, description),

  // statRate: request rate single stat (no sparkline, purple shades).
  statRate(title='Rate', targets=[], description='Rate of requests.'):
    generic.stat(title, targets, description)
    + st.withFieldConfigDefaults({ color+: { mode: 'shades', fixedColor: '#ca95e5' } })
    + st.options.withGraphMode('none'),

  // statDuration: response time single stat in seconds (blue shades).
  statDuration(title='Response time', targets=[], description='Response time.'):
    generic.stat(title, targets, description)
    + st.withFieldConfigDefaults({ color+: { mode: 'shades', fixedColor: '#5794f2' } })
    + st.standardOptions.withUnit('s')
    + st.options.withGraphMode('none'),

  // statErrors: error rate single stat (red shades, default color when none).
  statErrors(title='Errors', targets=[], description='Rate of errors.'):
    generic.stat(title, targets, description)
    + st.withFieldConfigDefaults({ color+: { mode: 'shades', fixedColor: '#ff7383' } })
    + st.withFieldConfigDefaults({ noValue: 'No errors' })
    + st.options.withGraphMode('none')
    + st.standardOptions.withMappings([
      {
        type: 'special',
        options: { match: 'null', result: { index: 0, color: '#5794f2' } },
      },
      {
        type: 'value',
        options: { '0': { color: '#5794f2', index: 1 } },
      },
    ]),
}
