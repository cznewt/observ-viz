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

  // every Grafana core panel plugin (typed builders generated for each)
  panels: [
    'timeSeries',
    'barChart',
    'histogram',
    'heatmap',
    'stat',
    'gauge',
    'barGauge',
    'pieChart',
    'table',
    'stateTimeline',
    'statusHistory',
    'text',
    'logs',
    'news',
    'dashList',
    'alertList',
    'annotationsList',
    'nodeGraph',
    'traces',
    'flameGraph',
    'geomap',
    'canvas',
    'candlestick',
    'trend',
    'xyChart',
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
