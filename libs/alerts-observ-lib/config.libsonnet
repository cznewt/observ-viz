// alerts-observ-lib config.
{
  uid: 'observ-viz-alerts',
  dashboardTitle: 'Alerts overview',
  dashboardTags: ['alerts'],
  // Platform / Monitoring / Alerting (a scenario re-files it with withFolder)
  folderPath: (import 'libs/common-lib/folders.libsonnet').monitoringAlerting,
  datasource: '${datasource}',
  // PromQL label selector applied to ALERTS, e.g. 'cluster="$cluster"'.
  filteringSelector: '',
  // alert-list grouping: 'default' | 'custom' (groups by groupLabels).
  groupMode: 'default',
  groupLabels: [],
}
