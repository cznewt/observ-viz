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
  ['kong', 'kong'],
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
local goldenBoards = [
  ['apiserver', 'apiserver'],
  ['node', 'node'],
  ['ingress-nginx', 'ingressNginx'],
  ['container', 'container'],
];
local burnRateBoards = [
  ['apiserver', 'apiserver'],
  ['pyrra', 'pyrra'],
];
local capacityBoards = [
  ['filesystem', 'filesystem'],
  ['memory', 'memory'],
  ['certificates', 'certificates'],
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
    } + {
      ['analysis-golden-' + b[0] + '.json']:
        util.place(
          g.libs.analysis.golden.new({
            uid: 'observ-viz-golden-' + b[0],
            dashboardTitle: 'Golden signals / ' + sources.golden[b[1]].title,
            datasource: $._config.datasource,
            source: sources.golden[b[1]],
          }).grafana.dashboard,
          $._config.folders.analysis,
          $._config.tags,
        )
      for b in goldenBoards
    } + {
      ['analysis-burnrate-' + b[0] + '.json']:
        util.place(
          g.libs.analysis.burnRate.new({
            uid: 'observ-viz-burnrate-' + b[0],
            dashboardTitle: 'Burn rate / ' + sources.burnRate[b[1]].title,
            datasource: $._config.datasource,
            source: sources.burnRate[b[1]],
            service: b[0],
          }).grafana.dashboard,
          $._config.folders.analysis,
          $._config.tags,
        )
      for b in burnRateBoards
    } + {
      ['analysis-capacity-' + b[0] + '.json']:
        util.place(
          g.libs.analysis.capacity.new({
            uid: 'observ-viz-capacity-' + b[0],
            dashboardTitle: 'Capacity / ' + sources.capacity[b[1]].title,
            datasource: $._config.datasource,
            source: sources.capacity[b[1]],
            service: b[0],
          }).grafana.dashboard,
          $._config.folders.analysis,
          $._config.tags,
        )
      for b in capacityBoards
    },
}
