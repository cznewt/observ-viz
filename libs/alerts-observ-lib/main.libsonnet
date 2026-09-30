// alerts-observ-lib — ALERTS signals, alert annotations, reusable alert
// panels, and an alerts-overview dashboard, all reusable.
//   g.libs.alerts.new({ filteringSelector: 'cluster="$cluster"' })
local annotationsFn = import 'libs/alerts-observ-lib/annotations.libsonnet';
local defaults = import 'libs/alerts-observ-lib/config.libsonnet';
local dashboardsFn = import 'libs/alerts-observ-lib/dashboards.libsonnet';
local panelsFn = import 'libs/alerts-observ-lib/panels.libsonnet';
local signalsFn = import 'libs/alerts-observ-lib/signals.libsonnet';

{
  withConfigMixin(config):: { config+: config },

  new(config={}):
    local cfg = defaults + config;
    local signals = signalsFn(cfg);
    local annotations = annotationsFn(cfg);
    local panels = panelsFn(cfg, signals);
    local board = dashboardsFn(cfg, signals, annotations, panels);
    {
      config: cfg,
      signals: signals,
      grafana: {
        annotations: annotations,
        panels: panels,
        dashboard: board,
        dashboards: { [cfg.uid + '.json']: board },
      },
      prometheus: { alerts: [], rules: [] },
      asMonitoringMixin():: {
        grafanaDashboards+:: { [cfg.uid + '.json']: board.toSpec() },
      },
    },
}
