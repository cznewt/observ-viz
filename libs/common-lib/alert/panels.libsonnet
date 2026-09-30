// observ-viz reusable alert panels (hand-written).
// Returns PanelKind elements ready for g.element.panel(...).
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  // A unified alert-list panel (the 'alertlist' viz). instanceFilter is an
  // alert-instance label filter string (advanced syntax), groupMode default/custom.
  list(title='Alerts', instanceFilter='', groupMode='default', groupBy=[]):
    panel.base('alertlist', title)
    + { spec+: { vizConfig+: { spec+: { options+: {
      alertInstanceLabelFilter: instanceFilter,
      groupMode: groupMode,
      groupBy: groupBy,
      dashboardAlerts: false,
      maxItems: 20,
      sortOrder: 1,
      viewMode: 'list',
    } } } } },

  // Instant table of firing alerts grouped by alertname + severity.
  firingTable(title='Firing alerts', datasource='${datasource}', selector=''):
    panel.table.new(title)
    + panel.table.withTargets([
      query.prometheus.new(datasource, 'sum by (alertname, severity) (ALERTS{alertstate="firing"' + (if selector != '' then ', ' + selector else '') + '})')
      + query.prometheus.withInstant(true)
      + query.prometheus.withFormat('table'),
    ]),

  // Instant table of firing alerts, one row per alert x where it fires:
  // Alert, Severity, Namespace, Pod, Node, Instance, Job and how long it has
  // been active (time() - ALERTS_FOR_STATE, the rule's activation time, kept
  // to what is firing now). The ruler's ALERTS / ALERTS_FOR_STATE series carry
  // labels only, so there is no summary column - the rule itself (and its
  // runbook_url) is one click away on the Alert link.
  // Links: Alert -> Grafana's alert-rule list searched for it; Namespace / Pod
  // -> the Kubernetes pod board; Node -> the Linux node board. Every link
  // carries the row's cluster.
  firingDetailTable(title='Firing alerts', datasource='${datasource}', selector='', podBoardUid='observ-viz-kube-pod', nodeBoardUid='compute-linux-overview'):
    local sel = if selector != '' then ', ' + selector else '';
    local by = 'cluster, alertname, severity, namespace, pod, node, instance, job';
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local link(t, url) = { id: 'links', value: [{ title: t, url: url }] };
    local colorText(mapping) = [
      { id: 'custom.cellOptions', value: { type: 'color-text' } },
      { id: 'mappings', value: [{ type: 'value', options: mapping }] },
    ];
    panel.table.new(title)
    + panel.table.withDescription('Every alert firing now, one row per alert and place (namespace / pod / node / instance / job). Active for = time since the rule went active (ALERTS_FOR_STATE). ALERTS carries no annotations, so the summary lives with the rule: Alert opens it in Grafana alerting. Namespace / Pod open the Kubernetes pod board, Node the Linux node board.')
    + panel.table.withTargets([
      query.prometheus.new(datasource,
                           'max by (' + by + ') (time() - (ALERTS_FOR_STATE{alertname!=""' + sel + '} and ignoring (alertstate) ALERTS{alertstate="firing"' + sel + '}))')
      + query.prometheus.withInstant(true)
      + query.prometheus.withFormat('table'),
    ])
    + panel.table.withTransformations([
      { id: 'organize', options: {
        excludeByName: { Time: true },
        indexByName: { alertname: 0, severity: 1, namespace: 2, pod: 3, node: 4, instance: 5, job: 6, Value: 7, cluster: 8 },
        renameByName: { alertname: 'Alert', severity: 'Severity', namespace: 'Namespace', pod: 'Pod', node: 'Node', instance: 'Instance', job: 'Job', Value: 'Active for' },
      } },
      { id: 'sortBy', options: { sort: [{ field: 'Active for', desc: true }] } },
    ])
    + panel.table.withOverrides([
      ov('^cluster$', [{ id: 'custom.hidden', value: true }]),
      ov('^Alert$', [link('Alert rule ${__value.raw}', '/alerting/list?search=${__value.raw}')]),
      ov('^Severity$', [{ id: 'custom.width', value: 90 }] + colorText({
        critical: { color: 'red', index: 0 },
        'error': { color: 'red', index: 1 },
        warning: { color: 'orange', index: 2 },
        info: { color: 'blue', index: 3 },
      })),
      ov('^Namespace$', [link('Pods in ${__value.raw}', '/d/' + podBoardUid + '?var-cluster=${__data.fields.cluster}&var-namespace=${__value.raw}')]),
      ov('^Pod$', [link('Open pod ${__value.raw}', '/d/' + podBoardUid + '?var-cluster=${__data.fields.cluster}&var-namespace=${__data.fields.Namespace}&var-pod=${__value.raw}')]),
      ov('^Node$', [link('Open node ${__value.raw}', '/d/' + nodeBoardUid + '?var-cluster=${__data.fields.cluster}&var-instance=${__value.raw}')]),
      ov('^Active for$', [{ id: 'unit', value: 's' }, { id: 'decimals', value: 0 }, { id: 'custom.width', value: 110 }]),
    ]),

  // Alert state timeline: one row per alert (alertstate folded into the VALUE,
  // so a row shifts color as it warms pending -> firing), severity-tiered
  // colors, legend trimmed to alertname + instance/pod.
  // `limit` bounds the rows: a state timeline draws one per series and splits
  // the panel height between them, so an unbounded query turns into a grey
  // smear the moment a cluster has a few hundred alerts firing.
  timeline(title='Alert state', datasource='${datasource}', selector='', limit=100):
    local sel = if selector != '' then ', ' + selector else '';
    local st(state, sevMatcher, weight) =
      '(ALERTS{alertstate="' + state + '"' + sevMatcher + sel + '} * ' + weight + ')';
    panel.base('state-timeline', title)
    + panel.withTargets([
      query.prometheus.new(
        datasource,
        'topk(' + limit + ', max by (alertname, severity, instance, pod, namespace) ('
        + st('pending', '', '1')
        + ' or ' + st('firing', ', severity="info"', '2')
        + ' or ' + st('firing', ', severity="warning"', '3')
        + ' or ' + st('firing', ', severity=~"critical|error"', '4')
        + ' or ' + st('firing', ', severity!~"info|warning|critical|error"', '3')
        + '))'
      )
      + query.prometheus.withLegendFormat('{{alertname}} · {{instance}}{{pod}}'),
    ])
    + panel.withOptions({ legend: { showLegend: true, displayMode: 'list', placement: 'bottom' }, rowHeight: 0.85 })
    + panel.withFieldConfigDefaults({ custom: { fillOpacity: 72, lineWidth: 0 } })
    + panel.withMappings([{ type: 'value', options: {
      '1': { text: 'pending', color: 'yellow', index: 0 },
      '2': { text: 'firing · info', color: 'super-light-blue', index: 1 },
      '3': { text: 'firing · warning', color: 'orange', index: 2 },
      '4': { text: 'firing · critical', color: 'red', index: 3 },
    } }]),
}
