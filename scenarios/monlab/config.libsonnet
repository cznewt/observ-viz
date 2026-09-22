// Deployment profile — the monitoring-lab cluster: one service board per
// Backstage catalog component that has a whitebox observ-lib, each pinned to
// the namespace (and pod) it runs in there. Boards land in one folder;
// the merged alert rules of every member are the profile's rule set.
local libs = import 'libs/observ-libs.libsonnet';
local s = libs.services;
local scoped(key, pack, namespace, pod='', title=null) =
  { key: key, pack: pack, config: { scope: { cluster: 'monitoring-lab', namespace: namespace, pod: pod } } }
  + (if title != null then { title: title } else {});
{
  uid: 'monlab',
  title: 'Monitoring lab',
  datasource: '${datasource}',
  tags: ['monlab', 'services'],
  folder: { uid: 'monlab-services', title: 'Monitoring lab — services' },
  includeAlerts: false,
  includeLogs: false,
  members: [
    scoped('grafana', s.grafana, 'global-monitor-grafana', 'grafana-server.*', 'Grafana'),
    scoped('grafanaTest', s.grafanaTest, 'global-monitor-grafana-test', '', 'Grafana (test)'),
    scoped('mimir', s.mimir, 'global-monitor-mimir', '', 'Mimir'),
    scoped('loki', s.loki, 'global-monitor-loki', '', 'Loki'),
    scoped('tempo', s.tempo, 'global-monitor-tempo', '', 'Tempo'),
    scoped('pyroscope', s.pyroscope, 'global-monitor-pyroscope', '', 'Pyroscope'),
    scoped('k8sMonitoring', s.k8sMonitoring, 'kube-monitor', 'k8s-monitoring-alloy.*', 'k8s-monitoring (Alloy)'),
    scoped('redisTest', s.redisTest, 'global-monitor-redis', 'redis-test.*', 'Redis (test)'),
    scoped('demoGoDev', s.demoGoDev, 'demo-dev', 'demo-.*go.*', 'Demo Go (dev)'),
    scoped('demoGoProd', s.demoGoProd, 'demo-prod|onlinestore-prod', 'demo-.*go.*', 'Demo Go (prod)'),
    scoped('demoGoWorkshop', s.demoGoWorkshop, 'demo-workshop|onlinestore-workshop', 'demo-.*go.*', 'Demo Go (workshop)'),
    scoped('demoPythonDev', s.demoPythonDev, 'demo-dev', 'demo-.*python.*', 'Demo Python (dev)'),
    scoped('demoPythonProd', s.demoPythonProd, 'demo-prod|onlinestore-prod', 'demo-.*python.*', 'Demo Python (prod)'),
    scoped('demoPythonWorkshop', s.demoPythonWorkshop, 'demo-workshop|onlinestore-workshop', 'demo-.*python.*', 'Demo Python (workshop)'),
    scoped('sreBack', s.sreBack, 'sample-java-app|sre.*', 'sre-back.*', 'SRE sample: back'),
    scoped('sreFront', s.sreFront, 'sample-java-app|sre.*', 'sre-front.*', 'SRE sample: front'),
    scoped('sreReader', s.sreReader, 'sample-java-app|sre.*', 'sre-reader.*', 'SRE sample: reader'),
    scoped('backstage', s.backstage, 'global-control-backstage', 'backstage-postgres.*', 'Backstage (Postgres)'),
    scoped('alertmanager', s.alertmanager, 'global-monitor-alertmanager', 'alertmanager-server.*', 'Alertmanager'),
    scoped('alertHandler', s.alertHandler, 'global-monitor-alert-handler', '', 'Alert handler'),
    scoped('opencost', s.opencost, 'kube-monitor', '.*opencost.*', 'OpenCost'),
    scoped('anomalyExporter', s.anomalyExporter, 'global-monitor-anomaly-scorer', '', 'Anomaly exporter'),
  ],
}
