// observ-viz runtime config (consumer-overridable). Follows the base/config
// pattern from grafonnet-extensions: filtering, grouping, and dashboard defaults
// that packs/signals read.
{
  // Default datasource uid (a template-variable ref or a concrete uid).
  datasource: '${datasource}',
  lokiDatasource: '${loki_datasource}',

  // PromQL label selector prefix and aggregation labels (observ-lib convention).
  filteringSelector: '',
  groupLabels: ['job'],
  instanceLabels: ['instance'],

  // Dashboard defaults.
  refresh: '1m',
  timezone: 'utc',
  period: 'now-1h',
  tags: [],

  // Output envelope.
  apiVersion: 'dashboard.grafana.app/v2beta1',
}
