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
  build(config, signals, groups, alerts=[], rules=[], optionalTabs=[]):: {
    local this = self,
    config: config,
    signals: signals,

    grafana: {
      // the raw group structure (so consumers can re-lay-out, e.g. as tabs).
      groups: groups,
      // flatten every group's (and optional tab's) elements into one elements map.
      elements: std.foldl(function(acc, grp) acc + grp.elements, groups + optionalTabs, {}),

      local gridOf(grp) =
        layout.grid.new()
        + layout.grid.withItems(grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height)),
      local rowsLayout =
        layout.rows.new()
        + layout.rows.withRows([layout.rows.row(grp.title, gridOf(grp)) for grp in groups]),

      // optional tabs gate on an explicit marker metric (a hidden presence
      // variable) when given, else on whether their own queries return data.
      local slug(s) = std.asciiLower(std.strReplace(s, ' ', '_')),
      local presenceVars = [
        variable.query.new('has_' + slug(t.title))
        + variable.query.withLabelValues(t.presence.label, t.presence.query)
        + variable.query.withHide(2)
        for t in optionalTabs
        if std.objectHas(t, 'presence')
      ],
      local tabGate(t) =
        if std.objectHas(t, 'presence') then
          layout.withConditionalRendering(layout.conditional.group([
            layout.conditional.variable('has_' + slug(t.title), '', 'notEquals'),
          ]))
        else layout.showIfData(),

      // default: one RowsLayout row per group. With optionalTabs, wrap the main
      // board in a primary tab and append each optional tab with showIfData(), so
      // it renders only on targets that actually have those metrics.
      layout:
        if std.length(optionalTabs) > 0 then
          layout.tabs.new()
          + layout.tabs.withTabs(
            [layout.tabs.tab(if std.objectHas(config, 'primaryTabTitle') then config.primaryTabTitle else config.dashboardTitle, rowsLayout)]
            + [layout.tabs.tab(t.title, gridOf(t)) + tabGate(t) for t in optionalTabs]
          )
        else rowsLayout,

      dashboard:
        local varMetric = if std.objectHas(config, 'varMetric') then config.varMetric else 'up';
        // optional cascading filter variables (e.g. ['cluster', 'instance']):
        // each is a label_values() query scoped by job and the variables before it.
        local varLabels = if std.objectHas(config, 'varLabels') then config.varLabels else [];
        local cap(s) = std.asciiUpper(std.substr(s, 0, 1)) + std.substr(s, 1, std.length(s));
        // default multi/includeAll vars to "All" so the initial view isn't pinned
        // to the first (often sparse) value.
        local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
        // varMulti=false makes the cascading vars single-select (one cluster / one
        // node) — needed for per-node correlation (e.g. proxmox node=~"$instance").
        local varMulti = if std.objectHas(config, 'varMulti') then config.varMulti else true;
        local multiMods = if varMulti then variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent else {};
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
          + variable.query.withIncludeAll()
          + allCurrent,
        ] + [
          variable.query.new(varLabels[i])
          + variable.query.withLabel(cap(varLabels[i]))
          + variable.query.withLabelValues(
            varLabels[i],
            varMetric + '{' + std.join(', ', ['job=~"$job"'] + [varLabels[j] + '=~"$' + varLabels[j] + '"' for j in std.range(0, i - 1)]) + '}'
          )
          + multiMods
          for i in std.range(0, std.length(varLabels) - 1)
        ] + (if std.objectHas(config, 'lokiDatasource') && config.lokiDatasource then [
          variable.datasource.new('loki_datasource', 'loki') + variable.datasource.withLabel('Loki'),
        ] else []) + presenceVars)
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
