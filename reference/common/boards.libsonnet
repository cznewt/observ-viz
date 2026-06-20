// observ-viz reference — Common folder. Depends on common-lib: a sample board
// per common-lib panel-preset category (each preset rendered with testdata) plus
// the whole-dashboard patterns. This is the "sample for each common pattern".
local g = import 'g.libsonnet';
local place = (import 'reference/_util.libsonnet').place;

local td() = g.query.base('grafana-testdata-datasource', { scenarioId: 'random_walk' }) + g.query.withDatasource('testdata');
local targets = [td(), td(), td()];

local categories = ['generic', 'cpu', 'memory', 'disk', 'network', 'system', 'requests', 'hardware'];

// a board showing every preset of one common-lib panels category.
local categoryBoard(cat) =
  local presets = std.objectFields(g.common.panels[cat]);
  local elements = { [cat + '-' + p]: g.common.panels[cat][p](p, targets) for p in presets };
  g.dashboard.new('Common / ' + cat)
  + g.dashboard.withUid('observ-viz-common-' + cat)
  + g.dashboard.withVariables([
    g.variable.datasource.new('datasource', 'prometheus') + g.variable.datasource.withLabel('Data source'),
  ])
  + g.dashboard.withElements(elements)
  + g.dashboard.withLayout(g.layout.grid.fromElements(std.objectFields(elements), 8, 7));

{
  _config+:: {},
  grafanaDashboards+:: {
    ['common-' + cat + '.json']: place(categoryBoard(cat), $._config.folders.common, $._config.tags)
    for cat in categories
  } + {
    // whole-dashboard patterns
    'common-red.json':
      place(g.patterns.red.new('Common / RED', $._config.datasource, { demo: 'job=~".+"' }, 'observ-viz-common-red'), $._config.folders.common, $._config.tags),
    'common-alerts.json':
      place(g.patterns.alertsOverview.new($._config.datasource, '', 'observ-viz-common-alerts', 'Common / Alerts'), $._config.folders.common, $._config.tags),
  },
}
