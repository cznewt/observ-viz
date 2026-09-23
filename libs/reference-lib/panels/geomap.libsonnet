// observ-viz reference — Geomap board. The panel needs coordinates, which no
// random-walk scenario produces, so the examples feed it an inline CSV of a few
// cities through the testdata datasource: latitude, longitude and a value.
local g = import 'g.libsonnet';

function(config) {
  local ds = 'testdata',
  local csv = |||
    lat,lng,name,value
    50.088,14.420,Prague,42
    48.208,16.373,Vienna,31
    52.520,13.405,Berlin,55
    47.497,19.040,Budapest,18
    52.230,21.012,Warsaw,27
  |||,
  local cities =
    g.query.base('grafana-testdata-datasource', { scenarioId: 'csv_content', csvContent: csv })
    + g.query.withDatasource(ds),

  // every layer reads the coordinates out of the lat/lng fields
  local location = { mode: 'coords', latitude: 'lat', longitude: 'lng' },
  local basemap = { type: 'osm-standard', name: 'Basemap', config: {} },

  local map(label, layer) =
    g.panel.geomap.new(label)
    + g.panel.geomap.withTargets([cities])
    + g.panel.geomap.withOptions({
      basemap: basemap,
      layers: [layer { location: location }],
      view: { id: 'coords', lat: 50, lon: 16, zoom: 4.5 },
      controls: { showZoom: true, mouseWheelZoom: true, showAttribution: true, showScale: false },
      tooltip: { mode: 'details' },
    })
    + g.panel.geomap.withFieldConfigDefaults({ color: { mode: 'thresholds' } })
    + g.panel.geomap.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 30 }, { color: 'red', value: 50 }]),

  local rows = [
    {
      title: 'Layers',
      keys: ['markers', 'heatmap'],
      elements: {
        markers: map('Markers', { type: 'markers', name: 'Cities', config: {
          style: { size: { field: 'value', min: 4, max: 18 }, symbol: { mode: 'fixed', fixed: 'img/icons/marker/circle.svg' }, color: { field: 'value' }, opacity: 0.7 },
        } }),
        heatmap: map('Heatmap', { type: 'heatmap', name: 'Density', config: { weight: { field: 'value', fixed: 1 }, blur: 22, radius: 18 } }),
      },
    },
  ],

  board:
    g.dashboard.new('Geomap')
    + g.dashboard.withUid('observ-viz-panel-geomap')
    + g.dashboard.withElements(std.foldl(function(acc, r) acc + r.elements, rows, {}))
    + g.dashboard.withLayout(
      g.layout.rows.new()
      + g.layout.rows.withRows([
        g.layout.rows.row(
          r.title,
          g.layout.grid.new() + g.layout.grid.withItems(g.util.grid.wrapItems(r.keys, 12, 11))
        )
        for r in rows
      ])
    ),
}
