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
    { key: 'mimir', pack: libs.databases.timeseries.mimir },
    { key: 'loki', pack: libs.databases.timeseries.loki },
    { key: 'tempo', pack: libs.databases.timeseries.tempo },
    { key: 'pyroscope', pack: libs.databases.timeseries.pyroscope },
    { key: 'alloy', pack: libs.collector.alloy },
  ],
}
