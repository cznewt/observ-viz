// Render this deployment's boards to v2 resources (applied by scripts/deploy.py kubernetes).
local scenario = import 'scenarios/_scenario.libsonnet';
local s = scenario.new(import 'scenarios/kubernetes/config.libsonnet');
{ [k]: s.grafanaDashboards[k].toResource() for k in std.objectFields(s.grafanaDashboards) }
