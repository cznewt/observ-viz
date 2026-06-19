// Render every reference board to a full v2 resource, keyed by file name.
// `python3 scripts/load.py reference-mixin/render.jsonnet` pushes them into the
// reference folder; or `jsonnet -m out -J <repo> reference-mixin/render.jsonnet`.
local mixin = import 'reference-mixin/mixin.libsonnet';
{
  [name]: mixin.grafanaDashboards[name].toResource()
  for name in std.objectFields(mixin.grafanaDashboards)
}
