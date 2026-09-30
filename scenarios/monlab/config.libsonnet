// Deployment profile — the monitoring-lab cluster. The platform's own services
// (Grafana, Mimir, Loki, Tempo, Pyroscope, Alloy, Alertmanager, the alert
// handler, OpenCost, Backstage) are the component libraries' boards in Platform /
// Monitoring and Platform / Configuration (list them in a site's libs); what is
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
  // the lab's own workloads: the instrumented demos (one board per runtime,
  // environment / service as a variable) and the two test instances
  members: [
    scoped('grafanaTest', s.grafanaTest, 'global-monitor-grafana-test', '', 'Grafana (test)'),
    scoped('redisTest', s.redisTest, 'global-monitor-redis', 'redis-test.*', 'Redis (test)'),
    // one board per demo runtime; the environment (Go / Python) or the
    // service (JVM) is a variable on the board, scoped by the preset
    scoped('demoGo', s.demoGo, '$env', 'demo-.*go.*', 'Demo Go'),
    scoped('demoPython', s.demoPython, '$env', 'demo-.*python.*', 'Demo Python'),
    scoped('demoJvm', s.demoJvm, 'sample-java-app|sre.*', '${service}.*', 'Demo JVM'),
  ],
}
