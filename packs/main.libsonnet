// observ-viz packs namespace — domain & runtime observ-lib packs, aligned with
// the alloy-resources module catalog (system / kubernetes / databases / lgtm /
// collector / runtimes). Each pack: new(config) -> { signals, grafana:{elements,
// layout,dashboard}, prometheus:{alerts}, asMonitoringMixin() }.
{
  runtimes: {
    golang: import 'packs/runtimes/golang.libsonnet',
    jvm: import 'packs/runtimes/jvm.libsonnet',
    python: import 'packs/runtimes/python.libsonnet',
    dotnet: import 'packs/runtimes/dotnet.libsonnet',
    nodejs: import 'packs/runtimes/nodejs.libsonnet',
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
  databases: {
    postgres: import 'packs/databases/postgres.libsonnet',
    mysql: import 'packs/databases/mysql.libsonnet',
    redis: import 'packs/databases/redis.libsonnet',
    memcached: import 'packs/databases/memcached.libsonnet',
    etcd: import 'packs/databases/etcd.libsonnet',
  },
  // the Grafana LGTM stack (what Alloy ships telemetry to)
  lgtm: {
    mimir: import 'packs/lgtm/mimir.libsonnet',
    loki: import 'packs/lgtm/loki.libsonnet',
    tempo: import 'packs/lgtm/tempo.libsonnet',
    pyroscope: import 'packs/lgtm/pyroscope.libsonnet',
  },
  // telemetry collectors
  collector: {
    alloy: import 'packs/collector/alloy.libsonnet',
  },
  infra: {
    prometheus: import 'packs/infra/prometheus.libsonnet',
  },
}
