// Deployment profile — Linux server (headless host + collector).
// Mirrors a monitor-tools deployment config: which observ-libs (mixins) to
// deploy, with per-mixin params. Rendered + applied by scripts/deploy.py.
local libs = import 'libs/observ-libs.libsonnet';
{
  uid: 'linux-server',
  title: 'Linux server',
  datasource: '${datasource}',
  tags: ['linux', 'server'],
  folder: { uid: 'observ-viz-linux-server', title: 'Linux server' },
  // the alloy config that ships telemetry for this deployment.
  alloyConfig: 'scenarios/linux-server/alloy.alloy',
  members: [
    { key: 'host', pack: libs.system.linux, config: { selector: 'job=~"node|integrations/node_exporter"' } },
    { key: 'collector', pack: libs.collector.alloy, config: { selector: 'job=~"alloy|integrations/alloy"' } },
  ],
}
