// A Go-runtime dashboard from the golang pack — reusable signal-based elements.
local g = import 'g.libsonnet';

g.libs.runtimes.golang.new({
  uid: 'go-api',
  dashboardTitle: 'Go runtime — API',
  selector: 'job="api"',
}).grafana.dashboard.toResource()
