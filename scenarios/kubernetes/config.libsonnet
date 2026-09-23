// Deployment profile — Kubernetes (pods + container resources + collector).
local libs = import 'libs/observ-libs.libsonnet';
{
  uid: 'kubernetes',
  title: 'Kubernetes',
  datasource: '${datasource}',
  tags: ['kubernetes'],
  folder: { uid: 'scenario-kubernetes', title: 'Kubernetes', parent: { uid: 'scenarios', title: 'Scenarios' } },
  alloyConfig: 'scenarios/kubernetes/alloy.alloy',
  members: [
    { key: 'pods', pack: libs.kubernetes.pod, config: { selector: 'namespace=~".+"' } },
    { key: 'containers', pack: libs.kubernetes.cadvisor, config: { selector: 'namespace=~".+"' } },
    { key: 'collector', pack: libs.collector.alloy },
  ],
}
