// observ-viz reference — Candlestick board. Candlestick renders OHLC-like data,
// so we drive it from the testdata 'random_walk_table' scenario which emits a
// table of time/open/high/low/close-ish numeric fields. Two representative
// panels show the two main display modes: candles, and candles+volume.
// Uses the provisioned grafana-testdata datasource.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),

  // OHLC-shaped data for candlestick comes from the random_walk_table scenario.
  local targets = [td('random_walk_table')],

  // build a candlestick panel: mode selects candles vs candles+volume; the
  // candleStyle/colorStrategy live in options too. Field-level candlestick
  // custom config (e.g. drawStyle hints) goes through withFieldConfigDefaults.
  local candle(label, opts, custom={}) =
    g.panel.candlestick.new(label)
    + g.panel.candlestick.withTargets(targets)
    + g.panel.candlestick.withUnit('currencyUSD')
    + g.panel.candlestick.withOptions({
      candleStyle: 'candles',
      colorStrategy: 'open-close',
      colors: { up: 'green', down: 'red' },
    } + opts)
    + (if custom != {} then g.panel.candlestick.withFieldConfigDefaults({ custom: custom }) else {}),

  local groups = [
    { title: 'Display mode', panels: {
      candles: candle('Candles', { mode: 'candles' }),
      volume: candle('Candles + volume', { mode: 'candles+volume' }, { fillOpacity: 40 }),
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
    g.dashboard.new('Panel / Candlestick')
    + g.dashboard.withUid('observ-viz-panel-candlestick')
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
