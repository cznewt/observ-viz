// logs-lib config.
{
  uid: 'observ-viz-logs',
  dashboardTitle: 'Logs',
  dashboardTags: ['logs'],
  datasource: '${loki_datasource}',
  // Loki stream selector WITHOUT braces, e.g. 'job="myapp"'.
  filterSelector: '',
  // the label carrying the log level (Loki structured-metadata: detected_level).
  levelLabel: 'detected_level',
  // optional LogQL pipeline appended to the stream, e.g. '| json'.
  pipeline: '',
}
