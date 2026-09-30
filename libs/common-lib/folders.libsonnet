// The shared Grafana folder tree the observ-libs file their boards into. Each
// entry is a folder chain, root first, for pack config `folderPath` (or
// g.dashboard.withFolderPath); the loader (scripts/load.py) and the
// monitor-tools renderer create every folder in the chain under the one before.
//
//   Platform / Ingress                        ingress controllers, proxies, web servers:
//                                             ingress-nginx, NGINX, Kong, Caddy, Traefik,
//                                             Envoy, Apache HTTP Server
//   Platform / Kubernetes                     cluster, pod, container boards, CoreDNS,
//                                             cert-manager
//   Platform / Monitoring / Storage           the telemetry stores: Prometheus, Mimir, Loki,
//                                             Tempo, Pyroscope
//   Platform / Monitoring / Collectors        what collects/exports telemetry: Alloy,
//                                             node_exporter, kube-state-metrics, OpenCost,
//                                             anomaly exporter/scorer
//   Platform / Monitoring / Alerting          Alertmanager, alert handler, Grafana, alerts overview
//   Platform / Infrastructure / Compute       hosts: Linux, Windows, Docker, Proxmox VE
//   Platform / Infrastructure / Network       UniFi, WireGuard
//   Platform / Infrastructure / Storage       file sync and storage services: Syncthing,
//                                             MinIO
//   Platform / Configuration                  config management, GitOps, secrets: Salt,
//                                             Argo CD, Vault
//   Reference / Runtimes                      language runtimes and frameworks (reference boards)
//   Platform / Databases                      SQL, key-value, document and search stores:
//                                             MongoDB, Elasticsearch
//   Platform / Deployments                    reference-lib deployment-target boards
//   Workloads / Gaming                        game servers the platform hosts: Valheim,
//                                             Minecraft
//   Workloads / Content Management            CMS sites the platform hosts: Django,
//                                             Wagtail, WordPress
//   Workloads / Demos                         demo / course sample services: the demo
//                                             Go and Python apps, the SRE sample (JVM),
//                                             the demo-apps online store
//
// A caller re-files a board with its own `folderPath` in the pack config
// (`folderPath` wins over `folderUid` in pack.build).
local platform = { uid: 'platform', title: 'Platform' };
local infrastructure = { uid: 'platform-infrastructure', title: 'Infrastructure' };
local monitoring = { uid: 'platform-monitoring', title: 'Monitoring' };
// what runs on the platform, as opposed to the platform itself
local workloads = { uid: 'workloads', title: 'Workloads' };
{
  platform: [platform],
  kubernetes: [platform, { uid: 'platform-kubernetes', title: 'Kubernetes' }],
  ingress: [platform, { uid: 'platform-ingress', title: 'Ingress' }],
  monitoring: [platform, monitoring],
  monitoringStorage: [platform, monitoring, { uid: 'platform-monitoring-storage', title: 'Storage' }],
  monitoringCollectors: [platform, monitoring, { uid: 'platform-monitoring-collectors', title: 'Collectors' }],
  monitoringAlerting: [platform, monitoring, { uid: 'platform-monitoring-alerting', title: 'Alerting' }],
  infrastructure: [platform, infrastructure],
  compute: [platform, infrastructure, { uid: 'platform-infrastructure-compute', title: 'Compute' }],
  network: [platform, infrastructure, { uid: 'platform-infrastructure-network', title: 'Network' }],
  storage: [platform, infrastructure, { uid: 'platform-infrastructure-storage', title: 'Storage' }],
  configuration: [platform, { uid: 'platform-configuration', title: 'Configuration' }],
  runtimes: [{ uid: 'observ-viz-reference', title: 'Reference' }, { uid: 'observ-viz-languages', title: 'Runtimes' }],
  databases: [platform, { uid: 'platform-databases', title: 'Databases' }],
  deployments: [platform, { uid: 'platform-deployments', title: 'Deployments' }],
  workloads: [workloads],
  gaming: [workloads, { uid: 'workloads-gaming', title: 'Gaming' }],
  cms: [workloads, { uid: 'workloads-cms', title: 'Content Management' }],
  demos: [workloads, { uid: 'workloads-demos', title: 'Demos' }],
}
