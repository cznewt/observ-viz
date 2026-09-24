// Deployment profile — Linux server (headless host + collector).
// Mirrors a monitor-tools deployment config: which observ-libs (mixins) to
// deploy, with per-mixin params. Rendered + applied by scripts/deploy.py.
local libs = import 'libs/observ-libs.libsonnet';
{
  uid: 'linux-server',
  title: 'Linux server',
  datasource: '${datasource}',
  tags: ['linux', 'server'],
  folder: { uid: 'scenario-linux-server', title: 'Linux server', parent: { uid: 'scenarios', title: 'Scenarios' } },
  // the alloy config that ships telemetry for this deployment.
  alloyConfig: 'scenarios/linux-server/alloy.alloy',
  // the host board is system.linux (Base / Operating systems) and the collector
  // board is collector.alloy (Components / Monitoring); its alerts and logs are
  // tabs on the Linux board. The profile keeps its Alloy config and rules.
  boards: false,
  members: [
    { key: 'host', pack: libs.system.linux, config: { selector: 'job=~"node|integrations/node_exporter"' } },
    { key: 'collector', pack: libs.collector.alloy, config: { selector: 'job=~"alloy|integrations/alloy"' } },
  ],
}
