// common-lib signal — panel styling shared by both signal APIs.
// The preset look from libs/common-lib/panels (ported from grafana/jsonnet-libs
// common-lib): thicker smooth lines with a light gradient fill, no points,
// multi tooltip sorted desc, plain list legend; percent units get the
// cold->hot continuous scheme and a fixed 0..1 / 0..100 range. Stats reduce to
// the last value, colour by thresholds, no sparkline. Applied by asTimeSeries()
// / asStat() so every signal-rendered panel looks like the presets; callers
// still override anything with a later `+`.
local tokens = (import 'libs/common-lib/tokens/timeSeries.libsonnet').lines;
local viz(o) = { spec+: { vizConfig+: { spec+: o } } };
local percentRange(unit) =
  if unit == 'percentunit' then { min: 0, max: 1, color+: { mode: 'continuous-BlYlRd' } }
  else if unit == 'percent' then { min: 0, max: 100, color+: { mode: 'continuous-BlYlRd' } }
  else {};
local isPercent(unit) = unit == 'percentunit' || unit == 'percent';

{
  timeSeries(unit):
    viz({
      fieldConfig+: {
        defaults+: {
          color+: { mode: 'palette-classic' },
          custom+: {
            lineWidth: tokens.width.default,
            fillOpacity: tokens.opacity.default,
            showPoints: tokens.showPoints.default,
            gradientMode: if isPercent(unit) then 'scheme' else tokens.gradientMode.default,
            lineInterpolation: tokens.interpolation.default,
          },
        } + percentRange(unit),
      },
      options+: {
        tooltip+: { mode: 'multi', sort: 'desc' },
        legend+: { showLegend: true, displayMode: 'list', placement: 'bottom', calcs: [] },
      },
    }),

  stat(unit):
    viz({
      fieldConfig+: {
        defaults+: {
          color+: { mode: 'thresholds' },
          thresholds+: { mode: 'absolute', steps: [{ color: 'green', value: null }] },
        } + percentRange(unit),
      },
      options+: {
        reduceOptions+: { calcs: ['lastNotNull'], fields: '', values: false },
        colorMode: 'value',
        graphMode: 'none',
        justifyMode: 'auto',
        textMode: 'auto',
      },
    }),
}
