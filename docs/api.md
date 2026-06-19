# Core API

Import the library:

```jsonnet
local g = import 'observ-viz/g.libsonnet';
```

## dashboard

```
g.dashboard.new(title)
  .withUid(uid) .withDescription(d) .withTags(arr) .withCursorSync('Crosshair')
  .withVariables(arr) .withAnnotations(arr) .withTimeSettings(ts)
  .withElements(map) .withLayout(layout) .withFolder(uid, title)
  .toSpec()       -> DashboardV2Spec
  .toResource(apiVersion='dashboard.grafana.app/v2beta1') -> k8s envelope
```

`new()` seeds `metadata.name` from a slug of the title. `toSpec`/`toResource`
assign panel ids and refIds deterministically.

## panel

Every Grafana panel plugin has a typed builder (`timeSeries`, `stat`, `table`,
`gauge`, `barGauge`, `pieChart`, `barChart`, `histogram`, `heatmap`,
`stateTimeline`, `statusHistory`, `text`, `logs`, `news`, `dashList`,
`alertList`, `annotationsList`, `nodeGraph`, `traces`, `flameGraph`, `geomap`,
`canvas`, `candlestick`, `trend`, `xyChart`):

```
g.panel.<type>.new(title)
  .withTargets([query, ...])      // auto-assigns refIds A, B, C
  .withDescription(d) .withTransparent() .withTransformations(arr)
  .withUnit(u) .withMin(n) .withMax(n) .withThresholds(steps) .withMappings(arr)
  .withOptions(obj) .withFieldConfigDefaults(obj) .withOverrides(arr)

g.panel.base('<plugin-id>', title)   // generic — any panel plugin
```

`timeSeries` / `stat` / `table` additionally expose rich nested option setters
(`.standardOptions.*`, `.options.*`, `.custom.*`).

## query

```
g.query.prometheus.new(datasource, expr) .withLegendFormat(f) .withInstant() .withFormat('table')
g.query.loki.new(datasource, expr) .withQueryType('range') .withMaxLines(n)
g.query.base('<datasource-id>', spec)   // generic — any datasource
  .withDatasource(uid) .withRefId(r) .withHidden()
```

## layout

```
g.layout.grid.new() .withItems([ g.layout.grid.item(name, x, y, w, h) ])
g.layout.grid.fromElements(names, width=12, height=8)     // auto-wrap
g.layout.rows.new() .withRows([ g.layout.rows.row(title, <layout>, collapse=false) ])
g.layout.autoGrid.new(maxColumnCount=3) .withItems(names)
g.layout.tabs.new() .withTabs([ g.layout.tabs.tab(title, <layout>) ])
```

## variable / element / annotation

```
g.variable.datasource.new(name, pluginId) .withLabel(l)
g.variable.query.new(name) .withLabelValues(label, metric) .withMulti() .withIncludeAll()
g.variable.{custom,interval,text,constant,groupBy,adhoc}.new(...)

g.element.panel(name, panelObj)   // { name: PanelKind }
g.element.ref(name)               // ElementReference

g.annotation.new(name) / g.annotation.builtinAnnotation()
```
