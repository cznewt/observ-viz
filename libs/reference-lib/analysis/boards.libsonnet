// observ-viz reference — Analysis folder. The two methods that read someone
// else's metrics: RED per instrumentation we can point it at, and USE per
// resource source. Same board shape as every other pack.
local g = import 'g.libsonnet';
local util = import 'libs/reference-lib/_util.libsonnet';

local sources = g.libs.analysis.sources;

// RED boards: one per source profile, named by the instrumentation it reads.
local redBoards = [
  ['otel-http', 'otelHttpServer'],
  ['prometheus-client', 'prometheusClient'],
  ['ingress-nginx', 'ingressNginx'],
  ['django', 'django'],
  ['grafana', 'grafana'],
  ['apiserver', 'apiserver'],
  ['service-graph', 'serviceGraph'],
];
local useBoards = [
  ['node', 'node'],
  ['container', 'container'],
];
local anomalyBoards = [
  ['process', 'process'],
  ['requests', 'requests'],
];

{
  _config+:: {},
  grafanaDashboards+::
    {
      ['analysis-red-' + b[0] + '.json']:
        util.place(
          g.libs.analysis.red.new({
            uid: 'observ-viz-red-' + b[0],
            dashboardTitle: 'RED / ' + sources.red[b[1]].title,
            datasource: $._config.datasource,
            source: sources.red[b[1]],
          }).grafana.dashboard,
          $._config.folders.analysis,
          $._config.tags,
        )
      for b in redBoards
    } + {
      ['analysis-use-' + b[0] + '.json']:
        util.place(
          g.libs.analysis.use.new({
            uid: 'observ-viz-use-' + b[0],
            dashboardTitle: 'USE / ' + sources.use[b[1]].title,
            datasource: $._config.datasource,
            source: sources.use[b[1]],
          }).grafana.dashboard,
          $._config.folders.analysis,
          $._config.tags,
        )
      for b in useBoards
    } + {
      ['analysis-anomaly-' + b[0] + '.json']:
        util.place(
          g.libs.analysis.anomaly.new(sources.anomaly[b[1]] {
            uid: 'observ-viz-anomaly-' + b[0],
            dashboardTitle: 'Anomaly / ' + sources.anomaly[b[1]].title,
            datasource: $._config.datasource,
          }).grafana.dashboard,
          $._config.folders.analysis,
          $._config.tags,
        )
      for b in anomalyBoards
    },
}
