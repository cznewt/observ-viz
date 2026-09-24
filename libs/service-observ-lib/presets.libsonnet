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
  { key: 'alloy', app: 'alloy', whitebox: packs.alloy, tags: ['collector'], workload: 'alloy.*', service: 'alloy.*', windows: '(?i)alloy', unit: 'alloy.service', folder: 'monitoring' },
  { key: 'k8sMonitoring', app: 'k8s-monitoring', title: 'k8s-monitoring (Alloy) service', whitebox: packs.alloy, tags: ['collector', 'kubernetes'], workload: 'k8s-monitoring-alloy.*', service: 'k8s-monitoring-alloy.*', folder: 'monitoring' },
  { key: 'grafana', app: 'grafana', whitebox: packs.grafana, tags: ['monitoring'], workload: 'grafana.*', service: 'grafana.*', unit: 'grafana(-server)?.service', process: 'grafana(-server)?', windows: '(?i)grafana(-server)?', folder: 'monitoring' },
  { key: 'grafanaTest', app: 'grafana-test', title: 'Grafana (test) service', whitebox: packs.grafana, tags: ['monitoring', 'lab'], workload: 'grafana.*', service: 'grafana.*', folder: 'monitoring' },
  { key: 'mimir', app: 'mimir', whitebox: packs.mimir, tags: ['lgtm'], workload: 'mimir.*', service: 'mimir.*', folder: 'monitoring' },
  { key: 'loki', app: 'loki', whitebox: packs.loki, tags: ['lgtm'], workload: 'loki.*', service: 'loki.*', folder: 'monitoring' },
  { key: 'tempo', app: 'tempo', whitebox: packs.tempo, tags: ['lgtm'], workload: 'tempo.*', service: 'tempo.*', folder: 'monitoring' },
  { key: 'pyroscope', app: 'pyroscope', whitebox: packs.pyroscope, tags: ['lgtm'], workload: 'pyroscope.*', service: 'pyroscope.*', folder: 'monitoring' },
  { key: 'redisTest', app: 'redis-test', title: 'Redis (test) service', whitebox: packs.redis, tags: ['database', 'lab'], workload: 'redis-test.*', service: 'redis-test.*' },
  { key: 'demoGoDev', app: 'demo-go-dev', title: 'Demo Go (dev) service', whitebox: packs.golang, tags: ['demo', 'golang'], workload: 'demo-.*go.*', service: 'demo-.*go.*' },
  { key: 'demoGoProd', app: 'demo-go-prod', title: 'Demo Go (prod) service', whitebox: packs.golang, tags: ['demo', 'golang'], workload: 'demo-.*go.*', service: 'demo-.*go.*' },
  { key: 'demoGoWorkshop', app: 'demo-go-workshop', title: 'Demo Go (workshop) service', whitebox: packs.golang, tags: ['demo', 'golang'], workload: 'demo-.*go.*', service: 'demo-.*go.*' },
  { key: 'demoPythonDev', app: 'demo-python-dev', title: 'Demo Python (dev) service', whitebox: packs.python, tags: ['demo', 'python'], workload: 'demo-.*python.*', service: 'demo-.*python.*' },
  { key: 'demoPythonProd', app: 'demo-python-prod', title: 'Demo Python (prod) service', whitebox: packs.python, tags: ['demo', 'python'], workload: 'demo-.*python.*', service: 'demo-.*python.*' },
  { key: 'demoPythonWorkshop', app: 'demo-python-workshop', title: 'Demo Python (workshop) service', whitebox: packs.python, tags: ['demo', 'python'], workload: 'demo-.*python.*', service: 'demo-.*python.*' },
  { key: 'sreBack', app: 'sre-back', title: 'SRE sample: back (JVM) service', whitebox: packs.jvm, tags: ['sample', 'jvm'], workload: 'sre-back.*', service: 'sre-back.*' },
  { key: 'sreFront', app: 'sre-front', title: 'SRE sample: front (JVM) service', whitebox: packs.jvm, tags: ['sample', 'jvm'], workload: 'sre-front.*', service: 'sre-front.*' },
  { key: 'sreReader', app: 'sre-reader', title: 'SRE sample: reader (JVM) service', whitebox: packs.jvm, tags: ['sample', 'jvm'], workload: 'sre-reader.*', service: 'sre-reader.*' },
  { key: 'backstage', app: 'backstage', title: 'Backstage service (Postgres)', whitebox: packs.postgres, tags: ['cicd'], workload: 'backstage.*', service: 'backstage.*' },
  { key: 'alertmanager', app: 'alertmanager', whitebox: packs.alertmanager, tags: ['monitoring'], workload: 'alertmanager-server.*', service: 'alertmanager.*', folder: 'monitoring' },
  { key: 'alertHandler', app: 'alert-handler', whitebox: packs.alertHandler, tags: ['monitoring'], workload: 'alert-handler.*', service: 'alert-handler.*', folder: 'monitoring' },
  { key: 'opencost', app: 'opencost', title: 'OpenCost service', whitebox: packs.opencost, tags: ['cost', 'kubernetes'], workload: '.*opencost.*', service: '.*opencost.*' },
  { key: 'argocd', app: 'argo-cd', title: 'Argo CD service', whitebox: packs.argocd, tags: ['cicd', 'gitops'], workload: 'argo-cd-argocd.*', service: 'argo-cd.*' },
  { key: 'anomalyExporter', app: 'anomaly-exporter', whitebox: packs.anomalyExporter, tags: ['monitoring'], workload: 'anomaly-exporter.*', service: 'anomaly-exporter.*', folder: 'monitoring' },
];

local cap(s) = std.asciiUpper(std.substr(s, 0, 1)) + std.substr(s, 1, std.length(s));
// Where a service board lands. Services default to Components / Services; a
// monitoring-stack service sits with its component boards in Components /
// Monitoring instead (catalog entry: folder: 'monitoring').
local folders = {
  services: { uid: 'components-services', title: 'Services' },
  monitoring: { uid: 'components-monitoring', title: 'Monitoring' },
};
local folderOf(c) =
  local f = folders[if std.objectHas(c, 'folder') then c.folder else 'services'];
  { folderUid: f.uid, folderTitle: f.title };
local entry(c) = preset(folderOf(c) {
  app: c.app,
  whitebox: c.whitebox,
  // one convention for the whole catalog: "<Name> service", which also keeps a
  // service board apart from the component board of the same app in one folder
  dashboardTitle: if std.objectHas(c, 'title') then c.title else cap(c.app) + ' service',
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
