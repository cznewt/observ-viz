// observ-viz packs namespace — domain & runtime observ-lib packs.
// Each pack: new(config) -> { signals, grafana:{elements,layout,dashboard},
// prometheus:{alerts}, asMonitoringMixin() }.
{
  runtimes: {
    golang: import 'packs/runtimes/golang.libsonnet',
  },
  // kubernetes: { pod, cadvisor },  // added next
  // system: { linux, windows, docker },
}
