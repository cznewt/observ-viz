// logs-lib — onboard of grafana/jsonnet-libs logs-lib to observ-viz v2.
// Reusable Loki log panels (logs, stacked volume-by-level, rate) + a logs
// dashboard. Reuse the panels directly, or the whole dashboard.
//   g.libs.logs.new({ filterSelector: 'job="myapp"' }).grafana.panels.logsVolume
local defaults = import 'libs/logs-lib/config.libsonnet';
local queriesFn = import 'libs/logs-lib/queries.libsonnet';
local panelsFn = import 'libs/logs-lib/panels.libsonnet';
local dashboardsFn = import 'libs/logs-lib/dashboards.libsonnet';

{
  withConfigMixin(config):: { config+: config },

  new(config={}):
    local cfg = defaults + config;
    local queries = queriesFn(cfg);
    local panels = panelsFn(cfg, queries);
    local board = dashboardsFn(cfg, panels);
    {
      config: cfg,
      queries: queries,
      grafana: {
        panels: panels,
        dashboard: board,
        dashboards: { [cfg.uid + '.json']: board },
      },
      prometheus: { alerts: [], recordingRules: [] },
      asMonitoringMixin():: {
        grafanaDashboards+:: { [cfg.uid + '.json']: board.toSpec() },
      },
    },
}
