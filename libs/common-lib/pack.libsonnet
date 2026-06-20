// observ-viz pack contract (hand-written).
// A pack is an observ-lib-style bundle built from signals: it exposes signals,
// a ready elements map + layout + dashboard, optional prometheus alerts, and an
// asMonitoringMixin() for the monitor-tools pipeline. Packs are composable into
// component (per-service) or system (per-host) dashboards by reusing .grafana.elements.
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local layout = import 'custom/layout.libsonnet';
local grid = import 'custom/util/grid.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { datasource: gv.datasource + cv.datasource, query: gv.query + cv.query };

{
  // build(config, signals, groups, alerts, rules)
  //   config: { uid, dashboardTitle, dashboardTags, ... }
  //   signals: { name: signal }            (observ-lib .signals accessor)
  //   groups:  [{ title, width, height, elements: { name: PanelKind } }]
  //   alerts:  [ alertGroup ]              (optional prometheus alerting rule groups)
  //   rules:   [ ruleGroup ]               (optional prometheus recording rule groups)
  build(config, signals, groups, alerts=[], rules=[]):: {
    local this = self,
    config: config,
    signals: signals,

    grafana: {
      // the raw group structure (so consumers can re-lay-out, e.g. as tabs).
      groups: groups,
      // flatten every group's elements into one elements map.
      elements: std.foldl(function(acc, grp) acc + grp.elements, groups, {}),

      // one RowsLayout row per group, each a wrapped grid of that group's elements.
      layout:
        layout.rows.new()
        + layout.rows.withRows([
          layout.rows.row(
            grp.title,
            layout.grid.new()
            + layout.grid.withItems(grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height))
          )
          for grp in groups
        ]),

      dashboard:
        local varMetric = if std.objectHas(config, 'varMetric') then config.varMetric else 'up';
        dashboard.new(config.dashboardTitle)
        + dashboard.withUid(config.uid)
        + dashboard.withTags(config.dashboardTags)
        + dashboard.withVariables([
          variable.datasource.new('datasource', 'prometheus')
          + variable.datasource.withLabel('Data source'),
          variable.query.new('job')
          + variable.query.withLabel('Job')
          + variable.query.withLabelValues('job', varMetric)
          + variable.query.withMulti()
          + variable.query.withIncludeAll(),
        ])
        + dashboard.withElements(this.grafana.elements)
        + dashboard.withLayout(this.grafana.layout),

      // named dashboards map (render entry point for the dashboards/ dir).
      dashboards: { [config.uid + '.json']: this.grafana.dashboard },
    },

    // the prometheus side of the container: alerting + recording rule groups.
    prometheus: { alerts: alerts, rules: rules },

    // observ-lib mixin output for the monitor-tools / render-lib pipeline.
    asMonitoringMixin():: {
      grafanaDashboards+:: { [config.uid + '.json']: this.grafana.dashboard.toSpec() },
      [if std.length(alerts) > 0 then 'prometheusAlerts']+:: { groups: alerts },
      [if std.length(rules) > 0 then 'prometheusRules']+:: { groups: rules },
    },
  },
}
