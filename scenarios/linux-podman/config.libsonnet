// Deployment profile — Linux Podman host (node + containers + collector).
local libs = import 'libs/observ-libs.libsonnet';
{
  uid: 'linux-podman',
  title: 'Linux Podman host',
  datasource: '${datasource}',
  tags: ['linux', 'podman'],
  folder: { uid: 'scenario-linux-podman', title: 'Linux Podman host', parent: { uid: 'scenarios', title: 'Scenarios' } },
  alloyConfig: 'scenarios/linux-podman/alloy.alloy',
  members: [
    { key: 'host', pack: libs.system.linux, config: { selector: 'job=~"node|integrations/node_exporter"' } },
    { key: 'containers', pack: libs.kubernetes.cadvisor, config: { selector: 'job=~"cadvisor|integrations/cadvisor"' } },
    { key: 'collector', pack: libs.collector.alloy, config: { selector: 'job=~"alloy|integrations/alloy"' } },
  ],
}
