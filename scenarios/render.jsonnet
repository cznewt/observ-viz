// Render every scenario's boards to v2 resources, keyed by file name.
//   python3 scripts/load.py scenarios/render.jsonnet
local scenarios = import 'scenarios/main.libsonnet';
local all = [
  scenarios.linux.new(),
  scenarios.docker.new(),
  scenarios.kubernetes.new(),
  scenarios.lgtm.new(),
];
std.foldl(
  function(acc, s) acc + {
    [k]: s.grafanaDashboards[k].toResource()
    for k in std.objectFields(s.grafanaDashboards)
  },
  all,
  {}
)
