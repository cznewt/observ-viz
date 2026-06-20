// Render this deployment's boards to v2 resources (applied by scripts/deploy.py linux-podman).
local scenario = import 'scenarios/_scenario.libsonnet';
local s = scenario.new(import 'scenarios/linux-podman/config.libsonnet');
{ [k]: s.grafanaDashboards[k].toResource() for k in std.objectFields(s.grafanaDashboards) }
