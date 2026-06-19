// observ-viz packs namespace — structured to mirror the alloy-resources module
// tree (one alloy module ~ one observ-viz pack/mixin). Each pack:
//   new(config) -> { signals, grafana:{elements,layout,dashboard},
//                    prometheus:{alerts}, asMonitoringMixin() }
{
  databases: {
    kv: {
      etcd: import 'packs/databases/kv/etcd.libsonnet',
      memcached: import 'packs/databases/kv/memcached.libsonnet',
      redis: import 'packs/databases/kv/redis.libsonnet',
    },
    sql: {
      mysql: import 'packs/databases/sql/mysql.libsonnet',
      postgres: import 'packs/databases/sql/postgres.libsonnet',
    },
    timeseries: {
      loki: import 'packs/databases/timeseries/loki.libsonnet',
      mimir: import 'packs/databases/timeseries/mimir.libsonnet',
      tempo: import 'packs/databases/timeseries/tempo.libsonnet',
      pyroscope: import 'packs/databases/timeseries/pyroscope.libsonnet',
    },
  },
  collector: {
    alloy: import 'packs/collector/alloy.libsonnet',
  },
  system: {
    linux: import 'packs/system/linux.libsonnet',
    docker: import 'packs/system/docker.libsonnet',
    windows: import 'packs/system/windows.libsonnet',
  },
  kubernetes: {
    pod: import 'packs/kubernetes/pod.libsonnet',
    cadvisor: import 'packs/kubernetes/cadvisor.libsonnet',
  },
  // language runtimes (observ-viz-specific; the "Language Reference" set)
  runtimes: {
    golang: import 'packs/runtimes/golang.libsonnet',
    jvm: import 'packs/runtimes/jvm.libsonnet',
    python: import 'packs/runtimes/python.libsonnet',
    dotnet: import 'packs/runtimes/dotnet.libsonnet',
    nodejs: import 'packs/runtimes/nodejs.libsonnet',
  },
  infra: {
    prometheus: import 'packs/infra/prometheus.libsonnet',
  },
}
