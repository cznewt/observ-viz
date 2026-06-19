// observ-viz generation manifest — the "schema with datasources/panels/layouts
// enabled". Single source of truth the Python generator reads to decide which
// typed builders to emit into gen/. Adding a kind here + a schema file under
// generator/schemas/ + re-running the generator is all it takes to extend.
{
  schemaVersion: 'v2beta1',
  apiVersion: 'dashboard.grafana.app/v2beta1',

  datasources: [
    'prometheus',
    'loki',
    'sql',  // mysql / postgres / mssql share the SQL query spec
    'influxdb',
    'elasticsearch',
    'tempo',
    'jaeger',
    'cloudWatch',
    'azureMonitor',
    'googleCloudMonitoring',
  ],

  panels: [
    'timeSeries',
    'stat',
    'table',
    'gauge',
    'barGauge',
    'pieChart',
    'heatmap',
    'logs',
    'text',
    'stateTimeline',
    'alertList',
  ],

  layouts: ['grid', 'rows', 'autoGrid', 'tabs'],

  variables: [
    'query',
    'datasource',
    'custom',
    'interval',
    'text',
    'constant',
    'groupBy',
    'adhoc',
  ],
}
