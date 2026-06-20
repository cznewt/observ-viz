// Render EVERY deployment profile's boards to v2 resources (keyed by file name).
//   python3 scripts/load.py scenarios/render.jsonnet
local scenarios = import 'scenarios/main.libsonnet';
std.foldl(
  function(acc, name) acc + {
    [k]: scenarios[name].grafanaDashboards[k].toResource()
    for k in std.objectFields(scenarios[name].grafanaDashboards)
  },
  std.objectFields(scenarios),
  {}
)
