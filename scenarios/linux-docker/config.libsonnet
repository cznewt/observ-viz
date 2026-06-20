// Deployment profile — Linux Docker host (node + containers + collector).
local libs = import 'libs/observ-libs.libsonnet';
{
  uid: 'linux-docker',
  title: 'Linux Docker host',
  datasource: '${datasource}',
  tags: ['linux', 'docker'],
  folder: { uid: 'observ-viz-linux-docker', title: 'Linux Docker host' },
  alloyConfig: 'scenarios/linux-docker/alloy.alloy',
  members: [
    { key: 'host', pack: libs.system.linux, config: { selector: 'job=~"node|integrations/node_exporter"' } },
    { key: 'containers', pack: libs.system.docker, config: { selector: 'job=~"cadvisor|integrations/cadvisor"' } },
    { key: 'collector', pack: libs.collector.alloy, config: { selector: 'job=~"alloy|integrations/alloy"' } },
  ],
}
