// Deployment profile — Kubernetes (pods + container resources + collector).
local libs = import 'libs/observ-libs.libsonnet';
{
  uid: 'kubernetes',
  title: 'Kubernetes',
  datasource: '${datasource}',
  tags: ['kubernetes'],
  folder: { uid: 'scenario-kubernetes', title: 'Kubernetes', parent: { uid: 'scenarios', title: 'Scenarios' } },
  alloyConfig: 'scenarios/kubernetes/alloy.alloy',
  // the members all have a home in the library's folders now (Base, Reference /
  // Deployments, Components), so this profile contributes its collector config
  // and its merged rules rather than a second copy of every board
  boards: false,
  members: [
    { key: 'pods', pack: libs.kubernetes.pod, config: { selector: 'namespace=~".+"' } },
    { key: 'containers', pack: libs.kubernetes.cadvisor, config: { selector: 'namespace=~".+"' } },
    { key: 'collector', pack: libs.collector.alloy },
  ],
}
