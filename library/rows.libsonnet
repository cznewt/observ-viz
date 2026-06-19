// observ-viz common element groups (hand-written).
// Each returns a ready elements map { name: PanelKind } to drop into
// g.dashboard.withElements(...), and is referenced by name from a layout.
local sig = import 'library/signals.libsonnet';

{
  // The classic RED trio as a named elements map.
  redGroup(datasource, selector=''): {
    requestRate: sig.requestRate(datasource, selector).asTimeSeries('Request rate'),
    errorRatio: sig.errorRatio(datasource, selector).asTimeSeries('Error ratio'),
    latencyP95: sig.latencyP95(datasource, selector).asTimeSeries('p95 latency'),
  },

  // Basic process resource group.
  resourceGroup(datasource, selector=''): {
    cpu: sig.cpuUsage(datasource, selector).asTimeSeries('CPU usage'),
    memory: sig.memoryUsage(datasource, selector).asTimeSeries('Memory usage'),
  },
}
