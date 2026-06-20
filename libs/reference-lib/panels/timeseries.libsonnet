// observ-viz reference — rich Time series board (ported from the models/catalog
// reference-mixin). Demonstrates the timeSeries style options as rows of
// testdata-driven panels: draw style, interpolation, fill, width, gradient,
// stacking, points, thresholds. Uses the provisioned grafana-testdata datasource.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td() = g.query.base('grafana-testdata-datasource', { scenarioId: 'random_walk' }) + g.query.withDatasource(ds),
  local targets = [td(), td(), td()],  // 3 random-walk series

  // a timeSeries panel with custom fieldConfig (+ optional standard fields)
  local ts(label, custom, std={}) =
    g.panel.timeSeries.new(label)
    + g.panel.timeSeries.withTargets(targets)
    + g.panel.timeSeries.withFieldConfigDefaults({ custom: custom } + std),

  local thr = { mode: 'absolute', steps: [{ color: 'green', value: null }, { color: 'red', value: 60 }] },

  local groups = [
    { title: 'Draw style', panels: {
      lines: ts('Lines', { drawStyle: 'line' }),
      bars: ts('Bars', { drawStyle: 'bars', fillOpacity: 60 }),
      points: ts('Points', { drawStyle: 'points', showPoints: 'always', pointSize: 6 }),
    } },
    { title: 'Line interpolation', panels: {
      linear: ts('Linear', { lineInterpolation: 'linear' }),
      smooth: ts('Smooth', { lineInterpolation: 'smooth' }),
      before: ts('Step before', { lineInterpolation: 'stepBefore' }),
      after: ts('Step after', { lineInterpolation: 'stepAfter' }),
    } },
    { title: 'Fill opacity', panels: {
      f0: ts('0%', { fillOpacity: 0 }),
      f25: ts('25%', { fillOpacity: 25 }),
      f50: ts('50%', { fillOpacity: 50 }),
      f100: ts('100%', { fillOpacity: 100 }),
    } },
    { title: 'Line width', panels: {
      w1: ts('1', { lineWidth: 1 }),
      w3: ts('3', { lineWidth: 3 }),
      w6: ts('6', { lineWidth: 6 }),
      w10: ts('10', { lineWidth: 10 }),
    } },
    { title: 'Gradient mode', panels: {
      none: ts('None', { gradientMode: 'none', fillOpacity: 40 }),
      opacity: ts('Opacity', { gradientMode: 'opacity', fillOpacity: 40 }),
      hue: ts('Hue', { gradientMode: 'hue', fillOpacity: 40 }),
      scheme: ts('Scheme', { gradientMode: 'scheme', fillOpacity: 40 }),
    } },
    { title: 'Stacking', panels: {
      none: ts('None', { stacking: { mode: 'none' }, fillOpacity: 40 }),
      normal: ts('Normal', { stacking: { mode: 'normal' }, fillOpacity: 60 }),
      percent: ts('Percent', { stacking: { mode: 'percent' }, fillOpacity: 60 }),
    } },
    { title: 'Show points', panels: {
      never: ts('Never', { showPoints: 'never' }),
      auto: ts('Auto', { showPoints: 'auto' }),
      always: ts('Always', { showPoints: 'always', pointSize: 5 }),
    } },
    { title: 'Thresholds', panels: {
      area: ts('Area', { thresholdsStyle: { mode: 'area' } }, { thresholds: thr }),
      line: ts('Line', { thresholdsStyle: { mode: 'line' } }, { thresholds: thr }),
      dashed: ts('Dashed', { thresholdsStyle: { mode: 'dashed' } }, { thresholds: thr }),
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
    g.dashboard.new('Panel / Time series')
    + g.dashboard.withUid('observ-viz-panel-timeSeries')
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
