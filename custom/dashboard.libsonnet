// observ-viz dashboard veneer (hand-written).
// Builds the v2 Dashboard envelope; merged over gen/dashboard.libsonnet setters.
local util = import 'custom/util/main.libsonnet';
{
  // new(title) seeds the full k8s envelope with sensible defaults. toSpec/
  // toResource are hidden methods on the built object (late-bound self) so id
  // assignment sees the final elements map.
  new(title): {
    apiVersion: 'dashboard.grafana.app/v2beta1',
    kind: 'Dashboard',
    metadata: { name: util.string.slugify(title) },
    spec: {
      title: title,
      description: '',
      cursorSync: 'Off',
      liveNow: false,
      preload: false,
      editable: true,
      links: [],
      tags: [],
      timeSettings: { from: 'now-6h', to: 'now', autoRefresh: '' },
      variables: [],
      elements: {},
      annotations: [],
      layout: { kind: 'GridLayout', spec: { items: [] } },
    },

    toSpec()::
      local s = self.spec;
      s { elements: util.resource.assignElementIds(s.elements) },
    toResource(apiVersion='dashboard.grafana.app/v2beta1')::
      local s = self.spec;
      local m = self.metadata;
      {
        apiVersion: apiVersion,
        kind: 'Dashboard',
        metadata: m,
        spec: s { elements: util.resource.assignElementIds(s.elements) },
      },
  },

  withUid(uid): { metadata+: { name: uid } },
  withDescription(value): { spec+: { description: value } },
  // place the dashboard in a Grafana folder (by folder uid / k8s name). An
  // optional title is carried in a private annotation that the loader uses to
  // create the folder with a readable name (and strips before pushing).
  // parentUid/parentTitle nest the folder under a parent (loader creates both).
  // Re-filing a board replaces its whole placement: the folder hints it already
  // carried (a pack's default folderPath or parent) are dropped, so the loader
  // does not walk the old chain instead.
  withFolder(folderUid, folderTitle=null, parentUid=null, parentTitle=null): {
    local hints = ['observ-viz.dev/folder-path', 'observ-viz.dev/folder-title', 'observ-viz.dev/folder-parent-uid', 'observ-viz.dev/folder-parent-title'],
    metadata+: {
      local prev = if 'annotations' in super then super.annotations else {},
      annotations: { [k]: prev[k] for k in std.objectFields(prev) if std.count(hints, k) == 0 }
                    + { 'grafana.app/folder': folderUid }
                    + (if folderTitle != null then { 'observ-viz.dev/folder-title': folderTitle } else {})
                    + (if parentUid != null then { 'observ-viz.dev/folder-parent-uid': parentUid } else {})
                    + (if parentTitle != null then { 'observ-viz.dev/folder-parent-title': parentTitle } else {}),
    },
  },
  // place the dashboard deeper than one level: an ancestor chain, root first,
  // e.g. [{uid:'components',title:'Components'},{uid:'components-database',title:'Database'}]
  // plus the folder itself. The chain rides in a private annotation the loader
  // walks (creating each folder under the one before it) and strips.
  withFolderPath(path): {
    assert std.length(path) > 0 : 'withFolderPath needs at least one folder',
    local leaf = path[std.length(path) - 1],
    // the chain replaces a single-level parent the board may already carry
    local dropped = ['observ-viz.dev/folder-parent-uid', 'observ-viz.dev/folder-parent-title'],
    metadata+: {
      local prev = if 'annotations' in super then super.annotations else {},
      annotations: { [k]: prev[k] for k in std.objectFields(prev) if std.count(dropped, k) == 0 } + {
        'grafana.app/folder': leaf.uid,
        'observ-viz.dev/folder-title': leaf.title,
        'observ-viz.dev/folder-path': std.manifestJsonMinified(path),
      },
    },
  },
  withElements(elements): { spec+: { elements+: elements } },
  withElementsMixin(elements): { spec+: { elements+: elements } },
  withLayout(layout): { spec+: { layout: layout } },
  withVariables(vars): { spec+: { variables: vars } },
  withVariablesMixin(vars): { spec+: { variables+: vars } },
  withAnnotations(anns): { spec+: { annotations: anns } },
  withAnnotationsMixin(anns): { spec+: { annotations+: anns } },
  withTimeSettings(ts): { spec+: { timeSettings+: ts } },
  withRefresh(value): { spec+: { timeSettings+: { autoRefresh: value } } },

  time: {
    withFrom(value='now-6h'): { spec+: { timeSettings+: { from: value } } },
    withTo(value='now'): { spec+: { timeSettings+: { to: value } } },
  },

  cursorSync: {
    withOff(): { spec+: { cursorSync: 'Off' } },
    withCrosshair(): { spec+: { cursorSync: 'Crosshair' } },
    withTooltip(): { spec+: { cursorSync: 'Tooltip' } },
  },
}
