// observ-viz analysis methods (hand-written).
// Two whole-board methods that read someone else's metrics rather than owning
// any: RED for request-driven services, USE for resources. Both take a source
// profile, so the same board covers any instrumentation that has the shape.
//
//   g.libs.analysis.red.new({ source: g.libs.analysis.sources.red.ingressNginx })
//   g.libs.analysis.use.new({ source: g.libs.analysis.sources.use.node })
//   g.libs.analysis.anomaly.elements({ service: 'redis', series: [...] }, 'anom_')
{
  sources: import 'libs/analysis-observ-lib/sources.libsonnet',
  // anomaly: any series against its own past, as a board, a fragment or a rule group
  anomaly: import 'libs/analysis-observ-lib/anomaly.libsonnet',
  // the four golden signals, RED's three plus saturation
  golden: import 'libs/analysis-observ-lib/golden.libsonnet',
  // how fast an SLO spends its error budget
  burnRate: import 'libs/analysis-observ-lib/burnrate.libsonnet',
  // when a shrinking quantity runs out
  capacity: import 'libs/analysis-observ-lib/capacity.libsonnet',
  red: import 'libs/analysis-observ-lib/red.libsonnet',
  use: import 'libs/analysis-observ-lib/use.libsonnet',
}
