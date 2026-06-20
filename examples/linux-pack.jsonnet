// Linux host dashboard from the node-exporter pack (real data in the local stack).
local g = import 'g.libsonnet';

g.libs.system.linux.new({
  uid: 'linux-node',
  dashboardTitle: 'Linux node',
}).grafana.dashboard.toResource()
