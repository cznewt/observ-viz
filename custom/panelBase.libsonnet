// observ-viz panel base constructor (hand-written veneer).
// Produces a v2 PanelKind element for any viz kind. Typed panel builders
// (g.panel.timeSeries.new, ...) and the generic g.panel.base both route here.
local versions = import 'gen/observ-viz-v2beta1/_versions.libsonnet';

function(vizKind, title) {
  kind: 'Panel',
  spec: {
    id: 0,
    title: title,
    description: '',
    links: [],
    data: {
      kind: 'QueryGroup',
      spec: {
        queries: [],
        transformations: [],
        queryOptions: {},
      },
    },
    vizConfig: {
      kind: vizKind,
      spec: {
        pluginVersion: if std.objectHas(versions, vizKind) then versions[vizKind] else '',
        options: {},
        fieldConfig: { defaults: {}, overrides: [] },
      },
    },
    transparent: false,
  },
}
