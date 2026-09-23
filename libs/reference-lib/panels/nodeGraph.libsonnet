// observ-viz reference — Node graph board. A node graph needs two frames, a
// nodes frame (id/title/subtitle/mainstat/...) and an edges frame
// (id/source/target), so the example reads a real service graph: the Backstage
// software catalog through the Infinity datasource, one component and the
// entities it is related to. Point `config.backstage` at another catalog to
// re-use it; the board renders empty without that datasource.
local g = import 'g.libsonnet';

function(config) {
  local bs = if std.objectHas(config, 'backstage') then config.backstage else {
    datasource: 'backstage-graphql-infinity',
    url: 'http://backstage-server.global-control-backstage.svc:7007/api/catalog/entities'
         + '?filter=kind=component&filter=kind=system&filter=kind=resource&filter=kind=api&filter=kind=domain',
    // the component the example is centred on, and how deep the graph goes
    entity: 'component:default/alert-handler',
  },
  local cols(names) = [{ selector: n, text: n, type: 'string' } for n in names],
  local infinity(rootSelector, names) =
    g.query.base('yesoreyeram-infinity-datasource', {
      type: 'json',
      source: 'url',
      format: 'table',
      parser: 'backend',
      url: bs.url,
      url_options: { method: 'GET', data: '' },
      root_selector: rootSelector,
      columns: cols(names),
    })
    + g.query.withDatasource(bs.datasource),

  // nodes: the entity itself plus everything that names it in a relation
  local nodes = infinity(
    '$[$lowercase(kind) & ":default/" & metadata.name = "' + bs.entity + '"'
    + ' or $count(relations[$lowercase(target.kind) & ":" & target.namespace & "/" & target.name = "' + bs.entity + '"]) > 0]'
    + '.($n := metadata.name; {"id": $lowercase(kind) & ":default/" & metadata.name, "title": $n,'
    + ' "subtitle": kind, "mainstat": $string(spec.system ? spec.system : spec.domain),'
    + ' "secondarystat": $string(spec.lifecycle ? spec.lifecycle : spec.type)})',
    ['id', 'title', 'subtitle', 'mainstat', 'secondarystat']
  ),
  // edges: every relation that touches the entity
  local edges = infinity(
    '$.($src := $lowercase(kind) & ":default/" & metadata.name;'
    + ' relations[type in ["dependsOn","partOf","consumesApi","providesApi"]]'
    + '.{"id": $src & " " & type & " " & $lowercase(target.kind) & ":" & target.namespace & "/" & target.name,'
    + ' "source": $src, "target": $lowercase(target.kind) & ":" & target.namespace & "/" & target.name,'
    + ' "mainstat": type})'
    + '[source = "' + bs.entity + '" or target = "' + bs.entity + '"]',
    ['id', 'source', 'target', 'mainstat']
  ),

  local graph(label, options) =
    g.panel.nodeGraph.new(label)
    + g.panel.nodeGraph.withTargets([nodes, edges])
    + g.panel.nodeGraph.withOptions(options),

  local rows = [
    {
      title: 'Layout',
      keys: ['layered', 'force'],
      elements: {
        // 'layered' arranges a dependency graph top-down; 'force' spreads a
        // mesh out. zoomMode 'cooperative' leaves the page scrollable.
        layered: graph('Layered', { layoutAlgorithm: 'layered', zoomMode: 'cooperative' }),
        force: graph('Force-directed', { layoutAlgorithm: 'force', zoomMode: 'cooperative' }),
      },
    },
  ],

  board:
    g.dashboard.new('Node graph')
    + g.dashboard.withUid('observ-viz-panel-nodeGraph')
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
