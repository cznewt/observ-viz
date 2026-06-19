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
