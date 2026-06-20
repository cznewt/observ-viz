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

  // Alert state timeline (firing|pending) over time.
  timeline(title='Alert state', datasource='${datasource}', selector=''):
    panel.base('state-timeline', title)
    + panel.withTargets([
      query.prometheus.new(datasource, 'ALERTS{alertstate=~"firing|pending"' + (if selector != '' then ', ' + selector else '') + '}'),
    ]),
}
