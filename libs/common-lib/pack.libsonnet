// observ-viz pack contract (hand-written).
// A pack is an observ-lib-style bundle built from signals: it exposes signals,
// a ready elements map + layout + dashboard, optional prometheus alerts, and an
// asMonitoringMixin() for the monitor-tools pipeline. Packs are composable into
// component (per-service) or system (per-host) dashboards by reusing .grafana.elements.
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local layout = import 'custom/layout.libsonnet';
local grid = import 'custom/util/grid.libsonnet';
local panel = import 'custom/panel.libsonnet';
local tabbed = import 'libs/common-lib/tabbed.libsonnet';
local utils = import 'libs/common-lib/utils.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { datasource: gv.datasource + cv.datasource, query: gv.query + cv.query };

{
  // build(config, signals, groups, alerts, rules)
  //   config: { uid, dashboardTitle, dashboardTags, ... }
  //   signals: { name: signal }            (observ-lib .signals accessor)
  //   groups:  [{ title, width, height, elements: { name: PanelKind } }]
  //   optionalTabs: [{ title, presence?, alwaysShow?, width, height, elements }]
  //                 or [{ title, presence?, groups: [group, ...] }] for rows inside a tab
  //   alerts:  [ alertGroup ]              (optional prometheus alerting rule groups)
  //   rules:   [ ruleGroup ]               (optional prometheus recording rule groups)
  build(config, signals, groups, alerts=[], rules=[], optionalTabs=[]):: {
    local this = self,
    config: config,
    signals: signals,

    grafana: {
      // the raw group structure (so consumers can re-lay-out, e.g. as tabs).
      groups: groups,
      // the optional tabs too, so a composer can fold them in as extra rows.
      optionalTabs: optionalTabs,
      // flatten every group's (and optional/doc tab's) elements into one elements map.
      // a tab either holds one grid (`elements`) or rows of grids (`groups`).
      local tabElements(t) = if std.objectHas(t, 'groups') then std.foldl(function(a, grp) a + grp.elements, t.groups, {}) else t.elements,
      local baseElements = std.foldl(function(acc, t) acc + tabElements(t), groups + optionalTabs + docTabList, {}),
      // `config.tabbed` swaps the rows layout for the shared tabbed board:
      // an Overview tab (description, references, instances table) and one tab
      // per signal group, each opening with that group's signal table.
      local tabbedOn = std.objectHas(config, 'tabbed') && config.tabbed,
      local tabbedBoard = tabbed.build(config, signals, groups, baseElements),
      elements: if tabbedOn then tabbedBoard.elements else baseElements,

      local gridOf(grp) =
        layout.grid.new()
        + layout.grid.withItems(grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height)),
      local tabLayout(t) =
        if std.objectHas(t, 'groups') then
          layout.rows.new() + layout.rows.withRows([layout.rows.row(grp.title, gridOf(grp)) for grp in t.groups])
        else gridOf(t),
      local rowsLayout =
        layout.rows.new()
        + layout.rows.withRows([layout.rows.row(grp.title, gridOf(grp)) for grp in groups]),

      // optional tabs gate on an explicit marker metric (a hidden presence
      // variable) when given, else on whether their own queries return data.
      local slug(s) = std.asciiLower(std.strReplace(s, ' ', '_')),
      local presenceVars = [
        variable.query.new('has_' + slug(t.title))
        + variable.query.withLabelValues(t.presence.label, t.presence.query)
        + variable.query.withHide('hideVariable')
        for t in optionalTabs
        if std.objectHas(t, 'presence')
      ],
      local tabGate(t) =
        if std.objectHas(t, 'alwaysShow') && t.alwaysShow then {}
        else if std.objectHas(t, 'presence') then
          layout.withConditionalRendering(layout.conditional.group([
            layout.conditional.variable('has_' + slug(t.title), '', 'notEquals'),
          ]))
        else layout.showIfData(),

      // Signals/Runbooks doc tabs (config.docTabs): a signals table + a runbooks
      // markdown list, built from this pack's own signals + alerting rules.
      local docTabsOn = std.objectHas(config, 'docTabs') && config.docTabs,
      local mdEsc(s) = std.strReplace(std.strReplace(s, '\n', ' '), '|', '\\|'),
      local sigExpr(sg) = sg.asTarget().spec.query.spec.expr,
      local sigUnit(sg) = local d = sg.asTimeSeries('x').spec.vizConfig.spec.fieldConfig.defaults; if std.objectHas(d, 'unit') then d.unit else '',
      local signalsMd =
        'Signals this pack emits — dashboard query + unit.\n\n| Signal | Query | Unit |\n| --- | --- | --- |\n'
        + std.join('\n', ['| ' + k + ' | ' + utils.mdQuery(sigExpr(signals[k])) + ' | ' + (local u = sigUnit(signals[k]); if u != '' then u else '—') + ' |' for k in std.objectFields(signals)]),
      // One panel per alerting rule, titled with the alert name: the runbook the
      // rule carries (alert.rule.withRunbook) if it has one, else a generated
      // one in the shape of runbooks.prometheus-operator.dev - what it means,
      // what it affects, how to check it, what to do about it.
      // one panel per alert name: a composed board merges groups that repeat an
      // alert under different selectors, and the runbook is about the alert
      local alertRules =
        local all = [r for grp in alerts for r in grp.rules if std.objectHas(r, 'alert')];
        local byName = std.foldl(function(acc, r) if std.objectHas(acc, r.alert) then acc else acc { [r.alert]: r }, all, {});
        [byName[n] for n in std.objectFields(byName)],
      local ann(r, k, fallback='') = if std.objectHas(r, 'annotations') && std.objectHas(r.annotations, k) && r.annotations[k] != '' then r.annotations[k] else fallback,
      local sev(r) = if std.objectHas(r, 'labels') && std.objectHas(r.labels, 'severity') then r.labels.severity else 'warning',
      local generatedRunbook(r) =
        local summary = ann(r, 'summary', r.alert + ' is firing.');
        local description = ann(r, 'description', '');
        local url = ann(r, 'runbook_url', '');
        local impact =
          if sev(r) == 'critical' then 'Something users depend on is already broken or about to be. Treat it as an incident.'
          else if sev(r) == 'warning' then 'Nothing is broken yet, and it will be if the trend holds. Look at it this working day.'
          else 'Informational. It is context for another alert rather than work of its own.';
        std.join('\n', [
          '### Meaning',
          '',
          summary,
          '',
        ] + (if description != '' then [description, ''] else []) + [
          'It fires when the expression below holds for ' + (if std.objectHas(r, 'for') then r['for'] else 'one evaluation') + '.',
          '',
          '### Impact',
          '',
          impact,
          '',
          '### Diagnosis',
          '',
          'Run the alert expression and look at which series cross the threshold:',
          '',
          '```promql',
          r.expr,
          '```',
          '',
          'Then open this board with the same selectors: the tab that carries those metrics shows how long the series has been where it is, and the restart and deploy annotations show whether a release or a restart lines up with the change.',
          '',
          '### Mitigation',
          '',
          '- Confirm the target is the one you think it is: check the labels on the firing series.',
          '- Compare against the same series on a healthy peer; a single instance out of line is a different problem from every instance moving together.',
          '- If a deploy or restart lines up with the change, that is the first thing to undo.',
          '- If the threshold no longer matches how this service behaves, change the rule rather than living with a permanent alert.',
        ] + (if url != '' then ['', 'Written runbook: ' + url] else [])),
      local runbookPanels =
        if std.length(alertRules) == 0 then
          { doc_runbooks: panel.text.new('Runbooks') + panel.text.withOptions({ mode: 'markdown', content: '_No alerting rules defined for this pack._' }) }
        else {
          ['doc_runbook_' + r.alert]:
            panel.text.new(r.alert + '  ·  ' + sev(r) + (if std.objectHas(r, 'for') then ' · for ' + r['for'] else ''))
            + panel.text.withOptions({ mode: 'markdown', content: ann(r, 'runbook', generatedRunbook(r)) })
          for r in alertRules
        },
      local docTabList = if docTabsOn then [
        { title: 'Signals', width: 24, height: 12, elements: { doc_signals: panel.text.new('Signals') + panel.text.withOptions({ mode: 'markdown', content: signalsMd }) } },
        { title: 'Runbooks', width: 12, height: 14, elements: runbookPanels },
      ] else [],

      // default: one RowsLayout row per group. With optionalTabs, wrap the main
      // board in a primary tab and append each optional tab with showIfData(), so
      // it renders only on targets that actually have those metrics.
      layout:
        if tabbedOn then
          layout.tabs.new()
          + layout.tabs.withTabs(
            [tabbedBoard.overviewTab] + tabbedBoard.groupTabs
            + [layout.tabs.tab(t.title, tabLayout(t)) + tabGate(t) for t in optionalTabs]
            // the Signals doc tab would repeat what every group tab already shows
            + [layout.tabs.tab(t.title, gridOf(t)) for t in docTabList if t.title != 'Signals']
          )
        else if std.length(optionalTabs) + std.length(docTabList) > 0 then
          layout.tabs.new()
          + layout.tabs.withTabs(
            [layout.tabs.tab(if std.objectHas(config, 'primaryTabTitle') then config.primaryTabTitle else config.dashboardTitle, rowsLayout)]
            + [layout.tabs.tab(t.title, tabLayout(t)) + tabGate(t) for t in optionalTabs]
            + [layout.tabs.tab(t.title, gridOf(t)) for t in docTabList]
          )
        else rowsLayout,

      dashboard:
        local varMetric = if std.objectHas(config, 'varMetric') then config.varMetric else 'up';
        // optional cascading filter variables (e.g. ['cluster', 'instance']):
        // each is a label_values() query scoped by job and the variables before it.
        // a cascading variable exists only while the pack's selector references it:
        // a scenario that overrides the selector (job=~"alloy|integrations/alloy",
        // say) then does not grow a dropdown that filters nothing.
        local declaredVarLabels = if std.objectHas(config, 'varLabels') then config.varLabels else [];
        local usedInSelector(label) =
          local sel = if std.objectHas(config, 'selector') then config.selector else '';
          std.length(std.findSubstr('$' + label, sel)) > 0;
        local varLabels = std.filter(usedInSelector, declaredVarLabels);
        local cap(s) = std.asciiUpper(std.substr(s, 0, 1)) + std.substr(s, 1, std.length(s));
        // default multi/includeAll vars to "All" so the initial view isn't pinned
        // to the first (often sparse) value.
        local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
        // varMulti=false makes the cascading vars single-select (one cluster / one
        // node) — needed for per-node correlation (e.g. proxmox node=~"$instance").
        local varMulti = if std.objectHas(config, 'varMulti') then config.varMulti else true;
        local multiMods = if varMulti then variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent else {};
        // optional Grafana folder placement (config.folderUid [+ folderTitle,
        // folderParentUid/folderParentTitle for nesting]) — loader creates them.
        local opt(k) = if std.objectHas(config, k) then config[k] else null;
        dashboard.new(config.dashboardTitle)
        + dashboard.withUid(config.uid)
        + dashboard.withTags(config.dashboardTags)
        + (if std.objectHas(config, 'description') then dashboard.withDescription(config.description) else {})
        // optional dashboard-level links (config.links: []DashboardLink specs)
        + (if std.objectHas(config, 'links') then dashboard.withLinks(config.links) else {})
        // folderPath is the general form: an ancestor chain ending in the
        // folder itself, for a tree deeper than parent/child.
        + (if std.objectHas(config, 'folderPath') then dashboard.withFolderPath(config.folderPath)
           else if std.objectHas(config, 'folderUid') then
             dashboard.withFolder(config.folderUid, opt('folderTitle'), opt('folderParentUid'), opt('folderParentTitle'))
           else {})
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
        ] + (if std.objectHas(config, 'extraVariables') then config.extraVariables else [])
        + (if std.objectHas(config, 'lokiDatasource') && config.lokiDatasource then [
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
