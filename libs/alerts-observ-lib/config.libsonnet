// alerts-observ-lib config.
{
  uid: 'observ-viz-alerts',
  dashboardTitle: 'Alerts overview',
  dashboardTags: ['alerts'],
  datasource: '${datasource}',
  // PromQL label selector applied to ALERTS, e.g. 'cluster="$cluster"'.
  filteringSelector: '',
  // alert-list grouping: 'default' | 'custom' (groups by groupLabels).
  groupMode: 'default',
  groupLabels: [],
}
