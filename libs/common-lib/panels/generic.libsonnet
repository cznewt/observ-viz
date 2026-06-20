// observ-viz common-lib generic base panel presets.
// Ported from grafana/jsonnet-libs common-lib/common/panels/generic.
// Each preset returns a styled v2 PanelKind; targets are passed directly.
// Styling tokens (mirrored from common-lib tokens):
//   timeSeries lines: width 2, opacity 30, showPoints never,
//   gradientMode opacity, interpolation smooth; color mode palette-classic.
local g = import 'g.libsonnet';
local ts = g.panel.timeSeries;
local st = g.panel.stat;
local tb = g.panel.table;
local sh = g.panel.statusHistory;

// optional description tail (only set when non-empty)
local desc(p, description) =
  if description != '' then p.withDescription(description) else {};

{
  // ---- timeSeries -------------------------------------------------------
  // base: clean line style with multi tooltip and simple list legend.
  timeSeries(title='', targets=[], description=''):
    ts.new(title)
    + ts.withTargets(targets)
    // Style choice: thicker lines, light fill, smooth interpolation, no points.
    + ts.custom.withLineWidth(2)
    + ts.custom.withFillOpacity(30)
    + ts.custom.withShowPoints('never')
    + ts.custom.withGradientMode('opacity')
    + ts.withFieldConfigDefaults({ custom+: { lineInterpolation: 'smooth' } })
    // Style choice: show all values in tooltip, sorted; clean list legend.
    + ts.options.tooltip.withMode('multi')
    + ts.withOptions({ tooltip+: { sort: 'desc' } })
    + ts.options.legend.withDisplayMode('list')
    + ts.options.legend.withCalcs([])
    // color mode palette-classic; empty thresholds by default.
    + ts.withFieldConfigDefaults({ color+: { mode: 'palette-classic', fixedColor: '#5794f2' } })
    + ts.standardOptions.thresholds.withMode('absolute')
    + ts.standardOptions.thresholds.withSteps([])
    + desc(ts, description),

  // percentage: gauge metrics in the 0-100% range, cold->hot coloring.
  timeSeriesPercentage(title='', targets=[], description=''):
    self.timeSeries(title, targets, description)
    + ts.standardOptions.withDecimals(1)
    + ts.standardOptions.withUnit('percent')
    + ts.withFieldConfigDefaults({ color+: { mode: 'continuous-BlYlRd' } })
    + ts.custom.withGradientMode('scheme')
    + ts.standardOptions.withMax(100)
    + ts.standardOptions.withMin(0),

  // ---- stat -------------------------------------------------------------
  // base: single fixed color, last value, no green/red threshold.
  stat(title='', targets=[], description=''):
    st.new(title)
    + st.withTargets(targets)
    + st.withFieldConfigDefaults({ color+: { mode: 'fixed', fixedColor: '#5794f2' } })
    + st.standardOptions.thresholds.withMode('absolute')
    + st.standardOptions.thresholds.withSteps([{ color: '#5794f2', value: null }])
    + desc(st, description),

  // info: simple text/count panel, no graph, no color, last value.
  statInfo(title='', targets=[], description=''):
    self.stat(title, targets, description)
    + st.withFieldConfigDefaults({ color+: { mode: 'fixed', fixedColor: 'text' } })
    + st.options.withGraphMode('none')
    + st.options.reduceOptions.withCalcs(['lastNotNull']),

  // percentage: 0-100% gauge stat with cold->hot value coloring.
  statPercentage(title='', targets=[], description=''):
    self.stat(title, targets, description)
    + st.standardOptions.withDecimals(1)
    + st.standardOptions.withUnit('percent')
    + st.options.withColorMode('value')
    + st.withFieldConfigDefaults({ color+: { mode: 'continuous-BlYlRd' } })
    + st.standardOptions.withMax(100)
    + st.standardOptions.withMin(0)
    + st.options.reduceOptions.withCalcs(['lastNotNull']),

  // ---- table ------------------------------------------------------------
  // base: plain table; inherits empty thresholds / palette color.
  table(title='', targets=[], description=''):
    tb.new(title)
    + tb.withTargets(targets)
    + tb.withFieldConfigDefaults({ color+: { mode: 'palette-classic', fixedColor: '#5794f2' } })
    + desc(tb, description),

  // ---- statusHistory ----------------------------------------------------
  // base: capped data points to avoid 'Too many data points' over wide ranges.
  statusHistory(title='', targets=[], description=''):
    sh.new(title)
    + sh.withTargets(targets)
    + { spec+: { data+: { spec+: { queryOptions+: { maxDataPoints: 50 } } } } }
    + desc(sh, description),
}
