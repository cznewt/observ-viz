// Monitoring mixin for this observ-lib — the render entry point the generic
// justfile drives. Exposes the outputs of the container:
//   grafanaDashboards : { '<uid>.json': <v2 dashboard spec> }
//   grafanaResources  : { '<name>.json': <app-platform resource> }  folders + dashboards
//   prometheusAlerts  : { groups: [ alerting rule group ] }
//   prometheusRules   : { groups: [ recording rule group ] }
local config = import 'config.libsonnet';
local lib = (import 'main.libsonnet').new(config);

local dashboards =
  if std.objectHas(lib.grafana, 'dashboards')
  then [lib.grafana.dashboards[k] for k in std.objectFields(lib.grafana.dashboards)]
  else [lib.grafana.dashboard];

local ann(d, key) =
  local a = if std.objectHas(d.metadata, 'annotations') then d.metadata.annotations else {};
  if std.objectHas(a, key) then a[key] else null;

// A dashboard carries its folder as an annotation and Grafana rejects a push
// into a folder that does not exist yet, so emit the Folder resources too. The
// observ-viz.dev/* hints are consumed here and dropped from what is pushed.
local folder(uid, title, parentUid) = {
  ['folder-' + uid + '.json']: {
    apiVersion: 'folder.grafana.app/v1beta1',
    kind: 'Folder',
    metadata: { name: uid }
              + (if parentUid != null then { annotations: { 'grafana.app/folder': parentUid } } else {}),
    spec: { title: if title != null then title else uid },
  },
};

local foldersOf(d) =
  local uid = ann(d, 'grafana.app/folder');
  local parentUid = ann(d, 'observ-viz.dev/folder-parent-uid');
  if uid == null then {}
  else
    (if parentUid != null then folder(parentUid, ann(d, 'observ-viz.dev/folder-parent-title'), null) else {})
    + folder(uid, ann(d, 'observ-viz.dev/folder-title'), parentUid);

local resourceOf(d) =
  local r = d.toResource();
  r {
    metadata: { name: r.metadata.name }
              + (if ann(d, 'grafana.app/folder') != null
                 then { annotations: { 'grafana.app/folder': ann(d, 'grafana.app/folder') } }
                 else {}),
  };

{
  grafanaDashboards:
    if std.objectHas(lib.grafana, 'dashboards')
    then { [k]: lib.grafana.dashboards[k].toSpec() for k in std.objectFields(lib.grafana.dashboards) }
    else { [lib.config.uid + '.json']: lib.grafana.dashboard.toSpec() },
  grafanaResources:
    std.foldl(function(acc, d) acc + foldersOf(d), dashboards, {})
    + { [d.metadata.name + '.json']: resourceOf(d) for d in dashboards },
  prometheusAlerts: { groups: if std.objectHas(lib, 'prometheus') then lib.prometheus.alerts else [] },
  prometheusRules: { groups: if std.objectHas(lib, 'prometheus') && std.objectHas(lib.prometheus, 'rules') then lib.prometheus.rules else [] },
}
