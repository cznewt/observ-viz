// observ-viz RED pattern (hand-written).
// A full RED (Rate / Errors / Duration) dashboard built from signals, with one
// row of three elements per application. Reuses the library RED signals.
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local element = import 'custom/element.libsonnet';
local layout = import 'custom/layout.libsonnet';
local sig = import 'library/signals.libsonnet';

{
  // new(title, datasource, apps) where apps is { <name>: <selector> }.
  new(title, datasource='${datasource}', apps={}, uid=null):
    // build elements: <app>-rate / -errors / -latency
    local elements = std.foldl(
      function(acc, app)
        acc
        + element.panel(app + '-rate', sig.requestRate(datasource, apps[app]).asTimeSeries(app + ' rate'))
        + element.panel(app + '-errors', sig.errorRatio(datasource, apps[app]).asTimeSeries(app + ' errors'))
        + element.panel(app + '-latency', sig.latencyP95(datasource, apps[app]).asTimeSeries(app + ' p95')),
      std.objectFields(apps),
      {}
    );
    // one RowsLayout row per app, each nesting a 3-wide grid.
    local rows = [
      layout.rows.row(
        app,
        layout.grid.new() + layout.grid.withItems([
          layout.grid.item(app + '-rate', 0, 0, 8, 8),
          layout.grid.item(app + '-errors', 8, 0, 8, 8),
          layout.grid.item(app + '-latency', 16, 0, 8, 8),
        ])
      )
      for app in std.objectFields(apps)
    ];
    dashboard.new(title)
    + (if uid != null then dashboard.withUid(uid) else {})
    + dashboard.withTags(['red', 'generated'])
    + dashboard.cursorSync.withCrosshair()
    + dashboard.withElements(elements)
    + dashboard.withLayout(layout.rows.new() + layout.rows.withRows(rows)),
}
