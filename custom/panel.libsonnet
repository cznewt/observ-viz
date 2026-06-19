// observ-viz panel veneer (hand-written, self-contained).
// Assembles the full g.panel namespace: generic base(vizKind, title), shared
// PanelKind setters, and typed namespaces that merge the generated option
// setters (gen/panel/*) with shared setters and a new() constructor.
local panelBase = import 'custom/panelBase.libsonnet';
local util = import 'custom/util/main.libsonnet';
local gp = import 'gen/observ-viz-v2beta1/panel/main.libsonnet';

// Shared PanelKind-level setters, mixed into the top level AND every typed
// namespace (so g.panel.withTargets and g.panel.timeSeries.withTargets both work).
local shared = {
  withId(value): { spec+: { id: value } },
  withDescription(value): { spec+: { description: value } },
  withLinks(value): { spec+: { links: value } },
  withTransparent(value=true): { spec+: { transparent: value } },
  withTransformations(value): { spec+: { data+: { spec+: { transformations: value } } } },
  // withTargets auto-assigns refIds (A, B, C, ...) to queries that have none.
  withTargets(targets): {
    spec+: { data+: { spec+: { queries: util.resource.assignRefIds(targets) } } },
  },
  withTargetsMixin(targets): {
    spec+: { data+: { spec+: { queries+: targets } } },
  },
};

shared + {
  // generic escape hatch: works for ANY viz kind by name.
  base(vizKind, title): panelBase(vizKind, title),

  timeSeries: gp.timeSeries + shared + { new(title): panelBase('timeseries', title) },
  stat: gp.stat + shared + { new(title): panelBase('stat', title) },
  table: gp.table + shared + { new(title): panelBase('table', title) },
}
