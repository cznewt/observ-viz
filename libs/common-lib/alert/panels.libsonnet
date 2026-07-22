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

  // Alert state timeline: one row per alert (alertstate folded into the VALUE,
  // so a row shifts color as it warms pending -> firing), severity-tiered
  // colors, legend trimmed to alertname + instance/pod.
  timeline(title='Alert state', datasource='${datasource}', selector=''):
    local sel = if selector != '' then ', ' + selector else '';
    local st(state, sevMatcher, weight) =
      '(ALERTS{alertstate="' + state + '"' + sevMatcher + sel + '} * ' + weight + ')';
    panel.base('state-timeline', title)
    + panel.withTargets([
      query.prometheus.new(
        datasource,
        'max by (alertname, severity, instance, pod, namespace) ('
        + st('pending', '', '1')
        + ' or ' + st('firing', ', severity="info"', '2')
        + ' or ' + st('firing', ', severity="warning"', '3')
        + ' or ' + st('firing', ', severity=~"critical|error"', '4')
        + ' or ' + st('firing', ', severity!~"info|warning|critical|error"', '3')
        + ')'
      )
      + query.prometheus.withLegendFormat('{{alertname}} · {{instance}}{{pod}}'),
    ])
    + panel.withOptions({ legend: { showLegend: true, displayMode: 'list', placement: 'bottom' }, rowHeight: 0.85 })
    + panel.withFieldConfigDefaults({ custom: { fillOpacity: 72, lineWidth: 0 } })
    + panel.withMappings([{ 'type': 'value', options: {
        '1': { text: 'pending', color: 'yellow', index: 0 },
        '2': { text: 'firing · info', color: 'super-light-blue', index: 1 },
        '3': { text: 'firing · warning', color: 'orange', index: 2 },
        '4': { text: 'firing · critical', color: 'red', index: 3 },
      } }]),
}
