// Reference boards — mirrors monitor-tools reference-mixin: exposes
// grafanaDashboards+:: { '<name>.json': <board> }. Each board is placed in the
// reference folder and tagged. Consumes observ-viz packs + patterns + panels.
local g = import 'g.libsonnet';

{
  _config+:: {},
  grafanaDashboards+:: {
    local cfg = $._config,
    local ds = cfg.datasource,
    // place a board in the reference folder + add reference tags
    local ref(d) = d + g.dashboard.withFolder(cfg.folder.uid) + g.dashboard.withTagsMixin(cfg.tags),

    'reference-panels.json':
      ref((import 'panels.libsonnet')(cfg).board),

    'reference-red.json':
      ref(g.patterns.red.new('Reference / RED', ds, { grafana: 'job="grafana"' }, 'reference-red')),

    'reference-alerts.json':
      ref(g.patterns.alertsOverview.new(ds, '', 'reference-alerts', 'Reference / Alerts')),

    'reference-go.json':
      ref(g.packs.runtimes.golang.new({ uid: 'reference-go', dashboardTitle: 'Reference / Go runtime' }).grafana.dashboard),

    'reference-linux.json':
      ref(g.packs.system.linux.new({ uid: 'reference-linux', dashboardTitle: 'Reference / Linux node' }).grafana.dashboard),

    'reference-postgres.json':
      ref(g.packs.databases.postgres.new({ uid: 'reference-postgres', dashboardTitle: 'Reference / PostgreSQL' }).grafana.dashboard),
  },
}
