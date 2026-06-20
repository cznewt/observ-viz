// Deployment profile — Linux desktop (workstation + collector).
local libs = import 'libs/observ-libs.libsonnet';
{
  uid: 'linux-desktop',
  title: 'Linux desktop',
  datasource: '${datasource}',
  tags: ['linux', 'desktop'],
  folder: { uid: 'observ-viz-linux-desktop', title: 'Linux desktop' },
  alloyConfig: 'scenarios/linux-desktop/alloy.alloy',
  members: [
    { key: 'host', pack: libs.system.linux, config: { selector: 'job=~"node|integrations/node_exporter"' } },
    { key: 'collector', pack: libs.collector.alloy, config: { selector: 'job=~"alloy|integrations/alloy"' } },
  ],
}
