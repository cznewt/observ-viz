// Deployment profile — platform boards: the Kubernetes cluster / multi-cluster
// / pod / container packs, the Linux and Windows node boards (with their
// kubelet tabs), systemd and process groups, ingress-nginx, OpenCost, Argo CD
// and the Backstage catalog. Site-agnostic: every board keys on its own
// variables.
local libs = import 'libs/observ-libs.libsonnet';
{
  uid: 'platform',
  title: 'Platform',
  datasource: '${datasource}',
  tags: ['platform'],
  folder: { uid: 'lab-platform', title: 'Lab platform', parent: { uid: 'scenarios', title: 'Scenarios' } },
  includeAlerts: false,
  includeLogs: false,
  // the members all have a home in the library's folders now (Base, Reference /
  // Deployments, Components), so this profile contributes its collector config
  // and its merged rules rather than a second copy of every board
  boards: false,
  members: [
    { key: 'multicluster', pack: libs.kubernetes.multicluster, title: 'Kubernetes / Clusters' },
    { key: 'cluster', pack: libs.kubernetes.cluster, title: 'Kubernetes / Cluster' },
    { key: 'pods', pack: libs.kubernetes.pod, title: 'Kubernetes / Pods' },
    { key: 'containers', pack: libs.kubernetes.cadvisor, title: 'Kubernetes / Containers' },
    { key: 'linux', pack: libs.system.linux, title: 'Nodes / Linux' },
    { key: 'windows', pack: libs.system.windows, title: 'Nodes / Windows' },
    { key: 'systemd', pack: libs.system.systemd, title: 'Nodes / systemd' },
    { key: 'processes', pack: libs.system.processExporter, title: 'Nodes / Process groups' },
    { key: 'ingress', pack: libs.networking.ingressNginx, title: 'Ingress NGINX' },
    { key: 'opencost', pack: libs.monitoring.opencost, title: 'OpenCost' },
    { key: 'argocd', pack: libs.cicd.argocd, title: 'Argo CD' },
    { key: 'backstage', pack: libs.cicd.backstage, title: 'Backstage catalog' },
  ],
}
