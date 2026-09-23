// observ-viz analysis methods (hand-written).
// Two whole-board methods that read someone else's metrics rather than owning
// any: RED for request-driven services, USE for resources. Both take a source
// profile, so the same board covers any instrumentation that has the shape.
//
//   g.libs.analysis.red.new({ source: g.libs.analysis.sources.red.ingressNginx })
//   g.libs.analysis.use.new({ source: g.libs.analysis.sources.use.node })
{
  sources: import 'libs/analysis-observ-lib/sources.libsonnet',
  red: import 'libs/analysis-observ-lib/red.libsonnet',
  use: import 'libs/analysis-observ-lib/use.libsonnet',
}
