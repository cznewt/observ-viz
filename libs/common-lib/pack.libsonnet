// observ-viz pack contract (hand-written).
// A pack is an observ-lib-style bundle built from signals: it exposes signals,
// a ready elements map + layout + dashboard, optional prometheus alerts, and an
// asMonitoringMixin() for the monitor-tools pipeline. Packs are composable into
// component (per-service) or system (per-host) dashboards by reusing .grafana.elements.
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local layout = import 'custom/layout.libsonnet';
local grid = import 'custom/util/grid.libsonnet';
local panel = import 'custom/panel.libsonnet';
local podrows = import 'libs/common-lib/podrows.libsonnet';
local runbook = import 'libs/common-lib/alert/runbook.libsonnet';
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
    // the rendered alerting rules carry a runbook_url: the written one, else
    // the alert's page on the docs site (config.runbookBaseUrl, '' for none)
    local linkedAlerts = runbook.withUrls(alerts, if std.objectHas(config, 'runbookBaseUrl') then config.runbookBaseUrl else runbook.docsBase),
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
      // every tabbed pack board scoped by job opens its Overview on the shared
      // pod rows (podrows.libsonnet) for the pods behind the selected job -
      // hidden job_cluster / job_namespace / job_pod variables off the pack's
      // identity metric (varMetric), each row gated on has_pods, so boards whose
      // targets are hosts never show them. A composer bringing its own lead rows
      // (g.libs.service) and a pack with overviewPods: false (the cluster and pod
      // boards) are left alone. A board scoped by something other than job (a
      // workload board built on kube-state-metrics, groupVar: 'cluster') names
      // its pods itself: config.podMetric, a series selector whose `pod` label
      // lists them, read through the same hidden variables.
      local podsOn = tabbedOn
                     && (std.objectHas(config, 'podMetric') || (if std.objectHas(config, 'groupVar') then config.groupVar else 'job') == 'job')
                     && !std.objectHas(config, 'overviewLeadGroups')
                     && (if std.objectHas(config, 'overviewPods') then config.overviewPods else true),
      local podLead = if podsOn then podrows.groups({
        datasource: if std.objectHas(config, 'datasource') then config.datasource else '${datasource}',
        lokiDatasource: '${loki_datasource}',
        kubeSelector: 'cluster=~"$job_cluster", namespace=~"$job_namespace", pod=~"$job_pod"',
        pods: true,
        logs: true,
        gates: { pods: 'has_pods', resources: 'has_pods', logs: 'has_pods' },
      }) else [],
      local overviewLead = if std.objectHas(config, 'overviewLeadGroups') then config.overviewLeadGroups else podLead,
      local overviewExtra = if std.objectHas(config, 'overviewExtraGroups') then config.overviewExtraGroups else [],
      local baseElements = std.foldl(function(acc, t) acc + tabElements(t), groups + optionalTabs + docTabList + overviewLead + overviewExtra, {}),
      // `config.tabbed` swaps the rows layout for the shared tabbed board:
      // an Overview tab (lead rows, instances table, the pack's own Overview
      // group, extra rows) and one tab per signal group, each opening with that
      // group's signal table. The description and references ride on the
      // dashboard itself (description + link bar), not in panels.
      local tabbedOn = std.objectHas(config, 'tabbed') && config.tabbed,
      // under the pod rows the instances table is titled after the board
      local tabbedConfig =
        if podsOn then config {
          overviewLeadGroups: podLead,
          overviewInstancesTitle: if std.objectHas(config, 'overviewInstancesTitle') then config.overviewInstancesTitle else config.dashboardTitle,
        } else config,
      local tabbedBoard = tabbed.build(tabbedConfig, signals, groups, baseElements),
      elements: if tabbedOn then tabbedBoard.elements else baseElements,

      local gridOf(grp) =
        layout.grid.new()
        + layout.grid.withItems(grid.wrapItems(std.objectFields(grp.elements), grp.width, grp.height)),
      // a row inside an optional tab may wait for a hidden presence variable
      // (`when: 'has_systemd'`), like a whole tab does with `presence`.
      local rowWhen(grp) =
        if std.objectHas(grp, 'when')
        then layout.withConditionalRendering(layout.conditional.group([layout.conditional.variable(grp.when, '', 'notEquals')]))
        else {},
      local tabLayout(t) =
        if std.objectHas(t, 'groups') then
          layout.rows.new() + layout.rows.withRows([layout.rows.row(grp.title, gridOf(grp)) + rowWhen(grp) for grp in t.groups])
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
      // One panel per alerting rule, titled with the alert name: its runbook
      // (alert/runbook.libsonnet - the written one, else a generated one).
      // one panel per alert name: a composed board merges groups that repeat an
      // alert under different selectors, and the runbook is about the alert
      local alertRules =
        local all = [r for grp in alerts for r in grp.rules if std.objectHas(r, 'alert')];
        local byName = std.foldl(function(acc, r) if std.objectHas(acc, r.alert) then acc else acc { [r.alert]: r }, all, {});
        [byName[n] for n in std.objectFields(byName)],
      local runbookPanels =
        if std.length(alertRules) == 0 then
          { doc_runbooks: panel.text.new('Runbooks') + panel.text.withOptions({ mode: 'markdown', content: '_No alerting rules defined for this pack._' }) }
        else {
          ['doc_runbook_' + r.alert]:
            panel.text.new(r.alert + '  ·  ' + runbook.severity(r) + (if std.objectHas(r, 'for') then ' · for ' + r['for'] else ''))
            + panel.text.withOptions({ mode: 'markdown', content: runbook.of(r) })
          for r in alertRules
        },
      // the documentation (the Signals / Runbooks tabs, and the tabbed board's
      // per-tab signal tables) is behind a `signals` Hide / Show variable,
      // Hide by default; a board with none of it does not get the variable
      local docsOn = docTabsOn || tabbedOn,
      local docsGate = layout.withConditionalRendering(layout.conditional.group([layout.conditional.variable('signals', 'Show', 'equals')])),
      local signalsVar = {
        kind: 'CustomVariable',
        spec: {
          name: 'signals',
          label: 'Signals',
          description: 'Show the signal / runbook documentation tables and tabs.',
          query: 'Hide,Show',
          current: { text: 'Hide', value: 'Hide' },
          options: [{ text: 'Hide', value: 'Hide', selected: true }, { text: 'Show', value: 'Show', selected: false }],
          multi: false,
          includeAll: false,
          allowCustomValue: false,
          hide: 'dontHide',
          skipUrlSync: false,
        },
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
            (if tabbedBoard.overviewTab != null then [tabbedBoard.overviewTab] else []) + tabbedBoard.groupTabs
            + [layout.tabs.tab(t.title, tabLayout(t)) + tabGate(t) for t in optionalTabs]
            // the Signals doc tab would repeat what every group tab already shows
            + [layout.tabs.tab(t.title, gridOf(t)) + docsGate for t in docTabList if t.title != 'Signals']
          )
        else if std.length(optionalTabs) + std.length(docTabList) > 0 then
          layout.tabs.new()
          + layout.tabs.withTabs(
            [layout.tabs.tab(if std.objectHas(config, 'primaryTabTitle') then config.primaryTabTitle else config.dashboardTitle, rowsLayout)]
            + [layout.tabs.tab(t.title, tabLayout(t)) + tabGate(t) for t in optionalTabs]
            + [layout.tabs.tab(t.title, gridOf(t)) + docsGate for t in docTabList]
          )
        else rowsLayout,

      dashboard:
        local varMetric = if std.objectHas(config, 'varMetric') then config.varMetric else 'up';
        // the board's primary grouping variable. `job` for a scrape target, but a
        // series that carries no job label needs its own: Tempo's
        // metrics-generator labels its output `source`, say.
        local groupVar = if std.objectHas(config, 'groupVar') then config.groupVar else 'job';
        // optional cascading filter variables (e.g. ['cluster', 'instance']):
        // each is a label_values() query scoped by job and the variables before it.
        // a cascading variable exists only while the board actually reads it - the
        // selector or any signal's own query. A scenario that overrides the
        // selector (job=~"alloy|integrations/alloy", say) then does not grow a
        // dropdown that filters nothing, while a pack whose panels filter on a
        // label the pack-level selector leaves out keeps its variable.
        local declaredVarLabels = if std.objectHas(config, 'varLabels') then config.varLabels else [];
        local sigExprs = [
          signals[k].asTarget().spec.query.spec.expr
          for k in std.objectFields(signals)
          if std.objectHasAll(signals[k], 'asTarget')
        ];
        local varHaystack =
          (if std.objectHas(config, 'selector') then config.selector else '')
          + std.join(' ', sigExprs);
        local readsLabel(label) = std.length(std.findSubstr('$' + label, varHaystack)) > 0;
        local varLabels = std.filter(readsLabel, declaredVarLabels);
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
        // a tabbed board shows no About/References panels: what it is goes into
        // the dashboard description, and each config.references entry becomes a
        // link-bar link whose tooltip is the reference's description.
        local description =
          if std.objectHas(config, 'description') then config.description
          else if tabbedOn then 'Runtime signals for every instance matching the selected job.'
          else null;
        local refLinks =
          if tabbedOn && std.objectHas(config, 'references') then [
            {
              title: r.title,
              type: 'link',
              icon: 'external link',
              tooltip: if std.objectHas(r, 'description') then r.description else '',
              url: r.url,
              tags: [],
              asDropdown: false,
              targetBlank: true,
              includeVars: false,
              keepTime: false,
            }
            for r in config.references
          ] else [];
        // dashboard-level links: config.links ([]DashboardLink specs), then the references
        local links = (if std.objectHas(config, 'links') then config.links else []) + refLinks;
        // the pods behind the selected job, for the shared pod rows: has_pods gates
        // them, job_cluster / job_namespace / job_pod scope their queries (hidden).
        // scoped by the pack's identity metric, not `up`: a scrape that gives
        // every app one job name (monlab's annotation autodiscovery) would
        // otherwise put every pod on every board. config.podMetric replaces it on
        // a board without a job (the server containers of a workload board).
        local podUp = if std.objectHas(config, 'podMetric') then config.podMetric else varMetric + '{job=~"$job", pod!=""}';
        local podVars = if podsOn then [
          variable.query.new('has_pods') + variable.query.withLabelValues('pod', podUp) + variable.query.withHide('hideVariable'),
        ] + [
          variable.query.new('job_' + l) + variable.query.withLabelValues(l, podUp) + variable.query.withHide('hideVariable')
          + variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent
          for l in ['cluster', 'namespace', 'pod']
        ] else [];
        local extraVars = if std.objectHas(config, 'extraVariables') then config.extraVariables else [];
        local declares(name) = std.length([v for v in extraVars if std.objectHas(v, 'spec') && std.objectHas(v.spec, 'name') && v.spec.name == name]) > 0;
        local wantLoki = ((std.objectHas(config, 'lokiDatasource') && config.lokiDatasource) || podsOn) && !declares('loki_datasource');
        dashboard.new(config.dashboardTitle)
        + dashboard.withUid(config.uid)
        + dashboard.withTags(config.dashboardTags)
        + (if description != null then dashboard.withDescription(description) else {})
        + (if std.length(links) > 0 then dashboard.withLinks(links) else {})
        // folderPath is the general form: an ancestor chain ending in the
        // folder itself, for a tree deeper than parent/child.
        + (if std.objectHas(config, 'folderPath') then dashboard.withFolderPath(config.folderPath)
           else if std.objectHas(config, 'folderUid') then
             dashboard.withFolder(config.folderUid, opt('folderTitle'), opt('folderParentUid'), opt('folderParentTitle'))
           else {})
        + dashboard.withVariables([
          variable.datasource.new('datasource', 'prometheus')
          + variable.datasource.withLabel('Data source'),
          variable.query.new(groupVar)
          + variable.query.withLabel(cap(groupVar))
          + variable.query.withLabelValues(groupVar, varMetric)
          + variable.query.withMulti()
          + variable.query.withIncludeAll()
          + allCurrent,
        ] + [
          variable.query.new(varLabels[i])
          + variable.query.withLabel(cap(varLabels[i]))
          + variable.query.withLabelValues(
            varLabels[i],
            varMetric + '{' + std.join(', ', [groupVar + '=~"$' + groupVar + '"'] + [varLabels[j] + '=~"$' + varLabels[j] + '"' for j in std.range(0, i - 1)]) + '}'
          )
          + multiMods
          for i in std.range(0, std.length(varLabels) - 1)
        ] + extraVars
        + (if wantLoki then [
               variable.datasource.new('loki_datasource', 'loki') + variable.datasource.withLabel('Loki'),
             ] else []) + presenceVars + podVars + (if docsOn then [signalsVar] else []))
        + dashboard.withElements(this.grafana.elements)
        + dashboard.withLayout(this.grafana.layout),

      // named dashboards map (render entry point for the dashboards/ dir).
      dashboards: { [config.uid + '.json']: this.grafana.dashboard },
    },

    // the prometheus side of the container: alerting + recording rule groups.
    prometheus: { alerts: linkedAlerts, rules: rules },

    // observ-lib mixin output for the monitor-tools / render-lib pipeline.
    asMonitoringMixin():: {
      grafanaDashboards+:: { [config.uid + '.json']: this.grafana.dashboard.toSpec() },
      [if std.length(alerts) > 0 then 'prometheusAlerts']+:: { groups: linkedAlerts },
      [if std.length(rules) > 0 then 'prometheusRules']+:: { groups: rules },
    },
  },
}
