// observ-viz query base constructor (hand-written veneer).
// Produces a v2 PanelQueryKind for any datasource kind. Typed query builders
// (g.query.prometheus.new, ...) and the generic g.query.base both route here.
// refId is left null so panel.withTargets can auto-assign A, B, C, ...
function(dsKind, spec) {
  kind: 'PanelQuery',
  spec: {
    refId: null,
    hidden: false,
    datasource: { type: dsKind, uid: null },
    query: {
      kind: dsKind,
      spec: spec,
    },
  },
}
