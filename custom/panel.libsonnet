// observ-viz panel veneer (hand-written, self-contained).
// Exposes the generic base(vizKind, title) PLUS a typed new() for EVERY core
// Grafana panel plugin. The three with rich generated option setters
// (timeSeries/stat/table) merge those; all others get the shared setters +
// generic withOptions/withUnit/etc. (the Python generator enriches the rest).
local panelBase = import 'custom/panelBase.libsonnet';
local util = import 'custom/util/main.libsonnet';
local gp = import 'gen/observ-viz-v2beta1/panel/main.libsonnet';

local viz(o) = { spec+: { vizConfig+: { spec+: o } } };

// Shared PanelKind-level setters, mixed into the top level AND every typed panel.
local shared = {
  withId(value): { spec+: { id: value } },
  withDescription(value): { spec+: { description: value } },
  withLinks(value): { spec+: { links: value } },
  withTransparent(value=true): { spec+: { transparent: value } },
  // v2 wraps each transformation as { kind, spec: { id, options } }; accept the
  // flat { id, options } form and wrap it (a bare flat form is silently dropped).
  withTransformations(value): { spec+: { data+: { spec+: { transformations: [
    { kind: t.id, spec: { id: t.id, options: (if std.objectHas(t, 'options') then t.options else {}) } }
    for t in value
  ] } } } },
  // withTargets auto-assigns refIds (A, B, C, ...) to queries that have none.
  withTargets(targets): { spec+: { data+: { spec+: { queries: util.resource.assignRefIds(targets) } } } },
  withTargetsMixin(targets): { spec+: { data+: { spec+: { queries+: targets } } } },
  // generic vizConfig access — works for every panel type.
  withOptions(obj): viz({ options+: obj }),
  withFieldConfigDefaults(obj): viz({ fieldConfig+: { defaults+: obj } }),
  withOverrides(arr): viz({ fieldConfig+: { overrides: arr } }),
  withUnit(unit): viz({ fieldConfig+: { defaults+: { unit: unit } } }),
  withMin(v): viz({ fieldConfig+: { defaults+: { min: v } } }),
  withMax(v): viz({ fieldConfig+: { defaults+: { max: v } } }),
  withDecimals(v): viz({ fieldConfig+: { defaults+: { decimals: v } } }),
  withThresholds(steps, mode='absolute'): viz({ fieldConfig+: { defaults+: { thresholds: { mode: mode, steps: steps } } } }),
  withMappings(arr): viz({ fieldConfig+: { defaults+: { mappings: arr } } }),
  withPluginVersion(v): { spec+: { vizConfig+: { version: v } } },
};

// friendly name -> Grafana panel plugin id (the full set Grafana ships).
local kinds = {
  timeSeries: 'timeseries',
  barChart: 'barchart',
  histogram: 'histogram',
  heatmap: 'heatmap',
  stat: 'stat',
  gauge: 'gauge',
  barGauge: 'bargauge',
  pieChart: 'piechart',
  table: 'table',
  stateTimeline: 'state-timeline',
  statusHistory: 'status-history',
  text: 'text',
  logs: 'logs',
  news: 'news',
  dashList: 'dashlist',
  alertList: 'alertlist',
  annotationsList: 'annolist',
  nodeGraph: 'nodeGraph',
  traces: 'traces',
  flameGraph: 'flamegraph',
  geomap: 'geomap',
  canvas: 'canvas',
  candlestick: 'candlestick',
  trend: 'trend',
  xyChart: 'xychart',
};

// rich generated option setters exist for these; others use shared/generic.
local genOpts = { timeSeries: gp.timeSeries, stat: gp.stat, table: gp.table };

shared
+ { base(vizKind, title): panelBase(vizKind, title) }
+ {
  [name]:
    (if std.objectHas(genOpts, name) then genOpts[name] else {})
    + shared
    + { new(title): panelBase(kinds[name], title) }
  for name in std.objectFields(kinds)
}
