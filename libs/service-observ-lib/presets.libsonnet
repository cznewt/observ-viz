// Ready service boards: the composer around a whitebox pack with that
// service's platform identity filled in. Each is an observ-lib (new(config)),
// reachable as g.libs.services.<name>; config overrides the preset per key.
local svc = import 'libs/service-observ-lib/main.libsonnet';
local preset(defaults) = { new(config={}): svc.new(defaults + config) };

{
  alloy: preset({
    app: 'alloy',
    whitebox: import 'libs/alloy-observ-lib/main.libsonnet',
    dashboardTags: ['service', 'alloy', 'collector', 'app-level'],
    systemd: { unit: 'alloy.service' },
    process: { group: 'alloy' },
    windows: { service: '(?i)alloy', process: '(?i)alloy' },
    docker: { container: '.*alloy.*' },
    // alloy exposes its process metrics as alloy_resources_process_* (in its
    // own Resources row), not process_* — the Process tab stays hidden.
  }),
  grafana: preset({
    app: 'grafana',
    whitebox: import 'libs/grafana-observ-lib/main.libsonnet',
    dashboardTags: ['service', 'grafana', 'monitoring', 'app-level'],
    kubernetes: { workload: 'grafana.*' },
    systemd: { unit: 'grafana(-server)?.service' },
    process: { group: 'grafana(-server)?' },
    windows: { service: '(?i)grafana', process: '(?i)grafana(-server)?' },
    docker: { container: '.*grafana.*' },
  }),
  mimir: preset({
    app: 'mimir',
    whitebox: import 'libs/mimir-observ-lib/main.libsonnet',
    dashboardTags: ['service', 'mimir', 'lgtm', 'app-level'],
    kubernetes: { workload: 'mimir.*' },
    systemd: { unit: 'mimir.service' },
    process: { group: 'mimir' },
    windows: { service: '(?i)mimir', process: '(?i)mimir' },
    docker: { container: '.*mimir.*' },
  }),
}
