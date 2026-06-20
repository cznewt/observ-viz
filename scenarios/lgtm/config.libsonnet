// Deployment profile — Grafana LGTM stack (what Alloy ships telemetry to).
local libs = import 'libs/observ-libs.libsonnet';
{
  uid: 'lgtm',
  title: 'Grafana LGTM stack',
  datasource: '${datasource}',
  tags: ['lgtm', 'grafana'],
  folder: { uid: 'observ-viz-lgtm', title: 'Grafana LGTM stack' },
  alloyConfig: 'scenarios/lgtm/alloy.alloy',
  members: [
    { key: 'mimir', pack: libs.monitoring.mimir },
    { key: 'loki', pack: libs.monitoring.loki },
    { key: 'tempo', pack: libs.monitoring.tempo },
    { key: 'pyroscope', pack: libs.monitoring.pyroscope },
    { key: 'alloy', pack: libs.collector.alloy },
  ],
}
