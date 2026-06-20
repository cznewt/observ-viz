// Prometheus self-monitoring dashboard (real data in the local stack).
local g = import 'g.libsonnet';

g.libs.monitoring.prometheus.new({
  uid: 'prometheus-self',
  dashboardTitle: 'Prometheus',
}).grafana.dashboard.toResource()
