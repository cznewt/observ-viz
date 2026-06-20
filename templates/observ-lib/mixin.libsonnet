// Monitoring mixin for this observ-lib — the render entry point the generic
// justfile drives. Exposes the three outputs of the container:
//   grafanaDashboards : { '<uid>.json': <v2 dashboard spec> }
//   prometheusAlerts  : { groups: [ alerting rule group ] }
//   prometheusRules   : { groups: [ recording rule group ] }
local config = import 'config.libsonnet';
local lib = (import 'main.libsonnet').new(config);
{
  grafanaDashboards:
    if std.objectHas(lib.grafana, 'dashboards')
    then { [k]: lib.grafana.dashboards[k].toSpec() for k in std.objectFields(lib.grafana.dashboards) }
    else { [lib.config.uid + '.json']: lib.grafana.dashboard.toSpec() },
  prometheusAlerts: { groups: if std.objectHas(lib, 'prometheus') then lib.prometheus.alerts else [] },
  prometheusRules: { groups: if std.objectHas(lib, 'prometheus') && std.objectHas(lib.prometheus, 'rules') then lib.prometheus.rules else [] },
}
