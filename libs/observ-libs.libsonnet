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
  },
  kubernetes: {
    pod: import 'libs/kubernetes-observ-lib/main.libsonnet',
    // cluster-level board + kubernetes-mixin-ported rules/alerts
    cluster: import 'libs/kubernetes-observ-lib/cluster.libsonnet',
    // node-level kubelet elements for embedding in host boards
    kubelet: import 'libs/kubernetes-observ-lib/kubelet.libsonnet',
    cadvisor: import 'libs/cadvisor-observ-lib/main.libsonnet',
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
    loki: import 'libs/loki-observ-lib/main.libsonnet',
    tempo: import 'libs/tempo-observ-lib/main.libsonnet',
    pyroscope: import 'libs/pyroscope-observ-lib/main.libsonnet',
  },
  collector: {
    alloy: import 'libs/alloy-observ-lib/main.libsonnet',
  },
  networking: {
    wireguard: import 'libs/wg-easy-observ-lib/main.libsonnet',
    unifi: import 'libs/unifi-observ-lib/main.libsonnet',
  },
  applications: {
    syncthing: import 'libs/syncthing-observ-lib/main.libsonnet',
    guardian: import 'libs/guardian-observ-lib/main.libsonnet',
  },
  // cross-cutting observ-libs (signals + annotations + reusable panels)
  alerts: import 'libs/alerts-observ-lib/main.libsonnet',
  logs: import 'libs/logs-lib/main.libsonnet',
}

