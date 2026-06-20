// Render this deployment's boards to v2 resources (applied by scripts/deploy.py linux-server).
local scenario = import 'scenarios/_scenario.libsonnet';
local s = scenario.new(import 'scenarios/linux-server/config.libsonnet');
{ [k]: s.grafanaDashboards[k].toResource() for k in std.objectFields(s.grafanaDashboards) }
