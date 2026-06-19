// observ-viz query base constructor (hand-written veneer).
// Produces a v2beta1 PanelQuery whose inner query is a DataQuery wrapper:
//   { kind:'DataQuery', group:<dsType>, version:'v0', datasource:{name:<uid>}, spec:<query> }
// refId is left null so panel.withTargets can auto-assign A, B, C, ...
function(dsKind, spec) {
  kind: 'PanelQuery',
  spec: {
    refId: null,
    hidden: false,
    query: {
      kind: 'DataQuery',
      group: dsKind,
      version: 'v0',
      datasource: { name: null },
      spec: spec,
    },
  },
}
