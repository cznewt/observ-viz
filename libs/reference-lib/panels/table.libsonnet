// observ-viz reference — rich Table board. Demonstrates the table panel's cell
// display modes (color text, color background, gauge, sparkline) via fieldConfig
// overrides, plus header/footer options. Driven by the provisioned
// grafana-testdata datasource using the random_walk_table scenario.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local td(scn='random_walk') = g.query.base('grafana-testdata-datasource', { scenarioId: scn }) + g.query.withDatasource(ds),

  // table scenario emits a tabular frame (Time, Min, Max, Info, Value columns)
  local targets = [td('random_walk_table')],

  local thr = [{ color: 'green', value: null }, { color: 'orange', value: 40 }, { color: 'red', value: 70 }],

  // the scenario's frame is Time/Min/Max/Info/Value; three columns is enough
  // to read a cell type at this width.
  local fewColumns = [{ id: 'organize', options: {
    excludeByName: { Min: true, Max: true },
    indexByName: { Time: 0, Info: 1, Value: 2 },
  } }],

  // a table panel with the random_walk_table target, optional typed options and
  // arbitrary fieldConfig overrides (cell display modes live here).
  local tbl(label, options=g.panel.table.withTargets(targets), overrides=[]) =
    g.panel.table.new(label)
    + g.panel.table.withTargets(targets)
    + g.panel.table.withTransformations(fewColumns)
    + g.panel.table.withFieldConfigDefaults({ custom: { align: 'auto', cellOptions: { type: 'auto' } } })
    + g.panel.table.withThresholds(thr)
    + (if std.length(overrides) > 0 then g.panel.table.withOverrides(overrides) else {})
    + options,

  // A sparkline cell needs a field holding a series, which is what the
  // timeSeriesTable transformation makes out of range queries - one "Trend"
  // column per query. A plain numeric column renders nothing.
  local sparklineTable(label) =
    g.panel.table.new(label)
    + g.panel.table.withTargets([td(), td(), td()])
    + g.panel.table.withTransformations([{ id: 'timeSeriesTable', options: {} }])
    + g.panel.table.withThresholds(thr)
    + g.panel.table.withOverrides([{
      matcher: { id: 'byRegexp', options: 'Trend.*' },
      properties: [{ id: 'custom.cellOptions', value: {
        type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16, gradientMode: 'scheme',
      } }],
    }]),

  // override helper: target a column by name, set custom.cellOptions.
  local cellOverride(name, cellOptions, extra=[]) = {
    matcher: { id: 'byName', options: name },
    properties: [{ id: 'custom.cellOptions', value: cellOptions }] + extra,
  },

  local groups = [
    { title: 'Cell types', panels: {
      'color-text': tbl('Color text', overrides=[
        cellOverride('Value', { type: 'color-text' }, [
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ]),
      ]),
      'color-background': tbl('Color background', overrides=[
        cellOverride('Value', { type: 'color-background', mode: 'gradient' }),
      ]),
      gauge: tbl('Gauge', overrides=[
        cellOverride('Value', { type: 'gauge', mode: 'gradient' }, [
          { id: 'min', value: 0 },
          { id: 'max', value: 100 },
        ]),
      ]),
      sparkline: sparklineTable('Sparkline'),
    } },
    { title: 'Options', panels: {
      'header-on': tbl('Header shown', g.panel.table.withTargets(targets) + g.panel.table.options.withShowHeader(true)),
      'header-off': tbl('Header hidden', g.panel.table.withTargets(targets) + g.panel.table.options.withShowHeader(false)),
      footer: tbl(
        'Footer total',
        g.panel.table.withTargets(targets)
        + g.panel.table.options.footer.withShow(true)
        + g.panel.table.options.footer.withReducer(['sum'])
      ),
      'auto-type': tbl('Auto cells'),
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
    g.dashboard.new('Table')
    + g.dashboard.withUid('observ-viz-panel-table')
    + g.dashboard.withElements(std.foldl(function(acc, r) acc + r.elements, rows, {}))
    + g.dashboard.withLayout(
      g.layout.rows.new()
      + g.layout.rows.withRows([
        g.layout.rows.row(
          r.title,
          g.layout.grid.new() + g.layout.grid.withItems(g.util.grid.wrapItems(r.keys, 12, 8))
        )
        for r in rows
      ])
    ),
}
