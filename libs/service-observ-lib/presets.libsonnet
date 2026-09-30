// Ready service boards: the composer around a whitebox pack with that
// service's platform identity filled in. Each is an observ-lib (new(config)),
// reachable as g.libs.services.<key>; config overrides the preset per key
// (e.g. scope: { namespace: 'infra-grafana' } to pin a deployment).
local svc = import 'libs/service-observ-lib/main.libsonnet';
local preset(defaults) = { new(config={}): svc.new(defaults + config) };

local packs = {
  alloy: import 'libs/alloy-observ-lib/main.libsonnet',
  grafana: import 'libs/grafana-observ-lib/main.libsonnet',
  mimir: import 'libs/mimir-observ-lib/main.libsonnet',
  loki: import 'libs/loki-observ-lib/main.libsonnet',
  tempo: import 'libs/tempo-observ-lib/main.libsonnet',
  pyroscope: import 'libs/pyroscope-observ-lib/main.libsonnet',
  prometheus: import 'libs/prometheus-observ-lib/main.libsonnet',
  redis: import 'libs/redis-observ-lib/main.libsonnet',
  postgres: import 'libs/postgres-observ-lib/main.libsonnet',
  golang: import 'libs/golang-observ-lib/main.libsonnet',
  python: import 'libs/python-observ-lib/main.libsonnet',
  jvm: import 'libs/jvm-observ-lib/main.libsonnet',
  alertmanager: import 'libs/alertmanager-observ-lib/main.libsonnet',
  alertHandler: import 'libs/alert-handler-observ-lib/main.libsonnet',
  opencost: import 'libs/opencost-observ-lib/main.libsonnet',
  anomalyExporter: import 'libs/anomaly-exporter-observ-lib/main.libsonnet',
  argocd: import 'libs/argocd-observ-lib/main.libsonnet',
};

// one row per service: app = the short name (uid observ-viz-svc-<app>, the
// Backstage component, systemd unit / process group / container defaults),
// workload = pod-name regex for the Kubernetes workload panels and the rule
// scopes, service = ingress-nginx backend Service regex.
local catalog = [
  { key: 'alloy', app: 'alloy', whitebox: packs.alloy, tags: ['collector'], workload: 'alloy.*', service: 'alloy.*', windows: '(?i)alloy', unit: 'alloy.service', folder: 'collectors' },
  { key: 'k8sMonitoring', app: 'k8s-monitoring', title: 'k8s-monitoring (Alloy) service', whitebox: packs.alloy, tags: ['collector', 'kubernetes'], workload: 'k8s-monitoring-alloy.*', service: 'k8s-monitoring-alloy.*', folder: 'collectors' },
  { key: 'grafana', app: 'grafana', whitebox: packs.grafana, tags: ['monitoring'], workload: 'grafana.*', service: 'grafana.*', unit: 'grafana(-server)?.service', process: 'grafana(-server)?', windows: '(?i)grafana(-server)?', folder: 'alerting' },
  { key: 'grafanaTest', app: 'grafana-test', title: 'Grafana (test) service', whitebox: packs.grafana, tags: ['monitoring', 'lab'], workload: 'grafana.*', service: 'grafana.*', folder: 'alerting' },
  { key: 'mimir', app: 'mimir', whitebox: packs.mimir, tags: ['lgtm'], workload: 'mimir.*', service: 'mimir.*', folder: 'storage' },
  { key: 'loki', app: 'loki', whitebox: packs.loki, tags: ['lgtm'], workload: 'loki.*', service: 'loki.*', folder: 'storage' },
  { key: 'tempo', app: 'tempo', whitebox: packs.tempo, tags: ['lgtm'], workload: 'tempo.*', service: 'tempo.*', folder: 'storage' },
  { key: 'pyroscope', app: 'pyroscope', whitebox: packs.pyroscope, tags: ['lgtm'], workload: 'pyroscope.*', service: 'pyroscope.*', folder: 'storage' },
  { key: 'prometheus', app: 'prometheus', whitebox: packs.prometheus, tags: ['lgtm'], workload: 'prometheus-server.*', service: 'prometheus-server.*', unit: 'prometheus.service', folder: 'storage' },
  { key: 'redisTest', app: 'redis-test', title: 'Redis (test) service', whitebox: packs.redis, tags: ['database', 'lab'], workload: 'redis-test.*', service: 'redis-test.*' },
  // the course demos: one board per runtime. The environments are namespaces
  // (monitor-lab-model manifests/monitor-lab/demo-{apps,envs}.yaml): the
  // workshop set in global-monitor-demo (Mimir tenant anonymous), dev in
  // demo-dev (tenant dev), prod in demo-prod (tenant prod) - an `env` variable
  // over them scopes the namespace menu. Pick the tenant's datasource too.
  { key: 'demoGo', app: 'demo-go', title: 'Demo Go', whitebox: packs.golang, tags: ['demo', 'golang'], workload: 'demo-.*go.*', service: 'demo-.*go.*', folder: 'demos', variant: 'env' },
  { key: 'demoPython', app: 'demo-python', title: 'Demo Python', whitebox: packs.python, tags: ['demo', 'python'], workload: 'demo-.*python.*', service: 'demo-.*python.*', folder: 'demos', variant: 'env' },
  // cznewt/sample-java-app: three JVM services (sre-back / sre-front /
  // sre-reader) in one namespace; a `service` variable picks among them.
  { key: 'demoJvm', app: 'demo-jvm', title: 'Demo JVM', whitebox: packs.jvm, tags: ['demo', 'sample', 'jvm'], workload: 'sre-(back|front|reader).*', service: 'sre-(back|front|reader).*', folder: 'demos', variant: 'service', namespace: 'sample-java-app|sre.*' },
  { key: 'backstage', app: 'backstage', title: 'Backstage service (Postgres)', whitebox: packs.postgres, tags: ['cicd'], workload: 'backstage.*', service: 'backstage.*' },
  { key: 'alertmanager', app: 'alertmanager', whitebox: packs.alertmanager, tags: ['monitoring'], workload: 'alertmanager-server.*', service: 'alertmanager.*', folder: 'alerting' },
  { key: 'alertHandler', app: 'alert-handler', whitebox: packs.alertHandler, tags: ['monitoring'], workload: 'alert-handler.*', service: 'alert-handler.*', folder: 'alerting' },
  { key: 'opencost', app: 'opencost', title: 'OpenCost service', whitebox: packs.opencost, tags: ['cost', 'kubernetes'], workload: '.*opencost.*', service: '.*opencost.*', folder: 'collectors' },
  { key: 'argocd', app: 'argo-cd', title: 'Argo CD service', whitebox: packs.argocd, tags: ['cicd', 'gitops'], workload: 'argo-cd-argocd.*', service: 'argo-cd.*' },
  { key: 'anomalyExporter', app: 'anomaly-exporter', whitebox: packs.anomalyExporter, tags: ['monitoring'], workload: 'anomaly-exporter.*', service: 'anomaly-exporter.*', folder: 'collectors' },
];

local cap(s) = std.asciiUpper(std.substr(s, 0, 1)) + std.substr(s, 1, std.length(s));
// Where a service board lands. Services default to Components / Services (the
// composer's own folderUid); a monitoring-stack service sits under Platform /
// Monitoring instead (catalog entry folder:): 'storage' = the telemetry
// stores, 'collectors' = what collects/exports telemetry, 'alerting' =
// Alertmanager / alert handler / Grafana. See libs/common-lib/folders.libsonnet.
local tree = import 'libs/common-lib/folders.libsonnet';
local folders = {
  services: {},
  monitoring: { folderPath: tree.monitoring },
  storage: { folderPath: tree.monitoringStorage },
  collectors: { folderPath: tree.monitoringCollectors },
  alerting: { folderPath: tree.monitoringAlerting },
  demos: { folderPath: tree.demos },
};
local folderOf(c) = folders[if std.objectHas(c, 'folder') then c.folder else 'services'];
// A demo board folds what used to be one board per environment (or per
// service) into a variable: `env` maps an environment to its namespace,
// `service` maps a service to its pod-name prefix. The composer's namespace /
// pod menus are scoped by it (scope), so every panel follows. Values are plain
// names, not regexes: Grafana regex-escapes multi-value interpolations.
local customVar(name, label, description, pairs) = {
  kind: 'CustomVariable',
  spec: {
    name: name,
    label: label,
    description: description,
    query: std.join(', ', [p[0] + ' : ' + p[1] for p in pairs]),
    current: { text: 'All', value: '$__all' },
    options: [{ text: p[0], value: p[1], selected: false } for p in pairs],
    multi: true,
    includeAll: true,
    allowCustomValue: false,
    hide: 'dontHide',
    skipUrlSync: false,
  },
};
local variants = {
  env: {
    extraVariables: [customVar('env', 'Environment', 'Demo environment: each one is a namespace (and a Mimir tenant - pick the matching datasource).',
                               [['workshop', 'global-monitor-demo'], ['dev', 'demo-dev'], ['prod', 'demo-prod']])],
    scope(c): { cluster: '', namespace: '$env', pod: c.workload },
  },
  service: {
    extraVariables: [customVar('service', 'Service', 'Sample service (pod-name prefix).',
                               [['back', 'sre-back'], ['front', 'sre-front'], ['reader', 'sre-reader']])],
    scope(c): { cluster: '', namespace: c.namespace, pod: '${service}.*' },
  },
};
local variantOf(c) =
  if std.objectHas(c, 'variant') then
    local v = variants[c.variant];
    { extraVariables: v.extraVariables, scope: v.scope(c) }
  else {};
local entry(c) = preset(folderOf(c) + variantOf(c) {
  app: c.app,
  whitebox: c.whitebox,
  // named for the app alone. A service board embeds the app's component pack
  // and adds the platform tabs around it, so where both exist only the service
  // board is deployed - two boards called "Grafana" in one folder is the bug
  // the suffix used to paper over.
  dashboardTitle: if std.objectHas(c, 'title') then c.title else cap(c.app),
  dashboardTags: ['service', c.app, 'app-level'] + c.tags,
  kubernetes: { workload: c.workload },
  ingress: { service: c.service },
  backstage: { name: c.app },
  docker: { container: '.*' + c.app + '.*' },
  systemd: { unit: if std.objectHas(c, 'unit') then c.unit else c.app + '.service' },
  process: { group: if std.objectHas(c, 'process') then c.process else c.app },
  windows: { service: if std.objectHas(c, 'windows') then c.windows else '(?i)' + c.app, process: if std.objectHas(c, 'windows') then c.windows else '(?i)' + c.app },
});

{ [c.key]: entry(c) for c in catalog } + { catalog:: catalog }
