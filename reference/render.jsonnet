// Render every reference board to a v2 resource, keyed by file name.
//   python3 scripts/load.py reference/render.jsonnet   (creates 3 folders + boards)
local mixin = import 'reference/mixin.libsonnet';
{
  [name]: mixin.grafanaDashboards[name].toResource()
  for name in std.objectFields(mixin.grafanaDashboards)
}
