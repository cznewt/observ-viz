// Render this deployment's boards to v2 resources (applied by scripts/deploy.py linux-docker).
local scenario = import 'scenarios/_scenario.libsonnet';
local s = scenario.new(import 'scenarios/linux-docker/config.libsonnet');
{ [k]: s.grafanaDashboards[k].toResource() for k in std.objectFields(s.grafanaDashboards) }
