// Deployment profile — the monitoring-lab cluster. The platform's own services
// (Grafana, Mimir, Loki, Tempo, Pyroscope, Alloy, Alertmanager, the alert
// handler, OpenCost, Backstage) are component boards in Components; what is
// left here is what the lab exists to run: the instrumentation demos and the
// test instances. Their boards land in Lab, and the merged alert rules of
// every member are the profile's rule set.
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
  folder: { uid: 'lab', title: 'Lab' },
  includeAlerts: false,
  includeLogs: false,
  // the lab's own workloads: three instrumented demos per environment, the
  // SRE sample's three services, and the two test instances
  members: [
    scoped('grafanaTest', s.grafanaTest, 'global-monitor-grafana-test', '', 'Grafana (test)'),
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
  ],
}
