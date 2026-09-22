// Index of all observ-viz observ-libs (the mixins), grouped to mirror the
// alloy-resources module tree. Each entry is a libs/<name>-observ-lib.
{
  // base/cluster fleet overview boards (ported from the base-mixin into common-lib)
  base: import 'libs/common-lib/base.libsonnet',
  runtimes: {
    golang: import 'libs/golang-observ-lib/main.libsonnet',
    jvm: import 'libs/jvm-observ-lib/main.libsonnet',
    python: import 'libs/python-observ-lib/main.libsonnet',
    dotnet: import 'libs/dotnet-observ-lib/main.libsonnet',
    nodejs: import 'libs/nodejs-observ-lib/main.libsonnet',
  },
  system: {
    linux: import 'libs/linux-observ-lib/main.libsonnet',
    docker: import 'libs/docker-observ-lib/main.libsonnet',
    windows: import 'libs/windows-observ-lib/main.libsonnet',
    // node_exporter systemd collector + process-exporter, by host
    systemd: import 'libs/systemd-observ-lib/main.libsonnet',
    processExporter: import 'libs/process-exporter-observ-lib/main.libsonnet',
  },
  kubernetes: {
    pod: import 'libs/kubernetes-observ-lib/main.libsonnet',
    // cluster-level board + kubernetes-mixin-ported rules/alerts
    cluster: import 'libs/kubernetes-observ-lib/cluster.libsonnet',
    // every kube cluster side by side (kubernetes-mixin multi-cluster port)
    multicluster: import 'libs/kubernetes-observ-lib/multicluster.libsonnet',
    // node-level kubelet elements for embedding in host boards
    kubelet: import 'libs/kubernetes-observ-lib/kubelet.libsonnet',
    cadvisor: import 'libs/cadvisor-observ-lib/main.libsonnet',
  },
  iot: {
    // Home Assistant device/entity telemetry (hass_* from home_assistant_exporter)
    devices: import 'libs/iot-observ-lib/main.libsonnet',
  },
  automation: {
    // salt jobs pack (salt-grafana architecture, Alloy edition — see
    // libs/salt-observ-lib/README.md); salt-job-view drill-down is the
    // ported JSON board in libs/salt-observ-lib/dashboards/.
    salt: import 'libs/salt-observ-lib/main.libsonnet',
    // Alcali-style per-minion highstate conformity (same gauges)
    conformity: import 'libs/salt-observ-lib/conformity.libsonnet',
    // fleet view: minion presence + jobs + conformity tabs
    infrastructure: import 'libs/salt-observ-lib/infrastructure.libsonnet',
  },
  databases: {
    sql: {
      postgres: import 'libs/postgres-observ-lib/main.libsonnet',
      mysql: import 'libs/mysql-observ-lib/main.libsonnet',
    },
    kv: {
      redis: import 'libs/redis-observ-lib/main.libsonnet',
      memcached: import 'libs/memcached-observ-lib/main.libsonnet',
      etcd: import 'libs/etcd-observ-lib/main.libsonnet',
    },
  },
  monitoring: {
    prometheus: import 'libs/prometheus-observ-lib/main.libsonnet',
    mimir: import 'libs/mimir-observ-lib/main.libsonnet',
    grafana: import 'libs/grafana-observ-lib/main.libsonnet',
    loki: import 'libs/loki-observ-lib/main.libsonnet',
    tempo: import 'libs/tempo-observ-lib/main.libsonnet',
    pyroscope: import 'libs/pyroscope-observ-lib/main.libsonnet',
    anomalyScorer: import 'libs/anomaly-scorer-observ-lib/main.libsonnet',
    anomalyExporter: import 'libs/anomaly-exporter-observ-lib/main.libsonnet',
    alertmanager: import 'libs/alertmanager-observ-lib/main.libsonnet',
    alertHandler: import 'libs/alert-handler-observ-lib/main.libsonnet',
    opencost: import 'libs/opencost-observ-lib/main.libsonnet',
  },
  collector: {
    alloy: import 'libs/alloy-observ-lib/main.libsonnet',
  },
  networking: {
    wireguard: import 'libs/wg-easy-observ-lib/main.libsonnet',
    unifi: import 'libs/unifi-observ-lib/main.libsonnet',
    ingressNginx: import 'libs/ingress-nginx-observ-lib/main.libsonnet',
  },
  applications: {
    syncthing: import 'libs/syncthing-observ-lib/main.libsonnet',
    guardian: import 'libs/guardian-observ-lib/main.libsonnet',
  },
  // a service wherever it runs: whitebox pack + gated platform tabs
  // (Kubernetes / Containers / Docker / systemd / process / Windows / Logs).
  service: import 'libs/service-observ-lib/main.libsonnet',
  services: import 'libs/service-observ-lib/presets.libsonnet',
  // cross-cutting observ-libs (signals + annotations + reusable panels)
  alerts: import 'libs/alerts-observ-lib/main.libsonnet',
  // CI/CD platforms: the Backstage catalog (Infinity datasource) and Argo CD.
  cicd: {
    backstage: import 'libs/backstage-observ-lib/main.libsonnet',
    argocd: import 'libs/argocd-observ-lib/main.libsonnet',
  },
  // Backstage catalog context through the Infinity datasource (alias of cicd.backstage)
  backstage: import 'libs/backstage-observ-lib/main.libsonnet',
  logs: import 'libs/logs-lib/main.libsonnet',
}
