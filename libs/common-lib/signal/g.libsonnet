// observ-viz-native `g` shim for the ported grafana signal library.
//
// The upstream grafana common-lib/signal modules are written against grafonnet's
// `g` (g.query.*, g.panel.*, g.dashboard.variable.*). observ-viz does NOT ship
// grafonnet; instead it has its own v2beta1 veneers under custom/. This shim
// re-expresses exactly the subset of the grafonnet `g` surface that the ported
// signal modules use, rendered through observ-viz's v2 builders so the output is
// native v2beta1 (Panel / PanelQuery / *Variable) resources.
//
// Only the methods actually used by base/info/log/stub + variables are provided.
local vpanel = import 'custom/panel.libsonnet';
local vquery = import 'custom/query.libsonnet';
local vvar = import 'custom/variable.libsonnet';

// ---- query helpers --------------------------------------------------------
// Each query is a v2beta1 PanelQuery whose inner DataQuery.spec holds the
// datasource query spec (expr/legendFormat/format/instant/range...).
local qspec(o) = { spec+: { query+: { spec+: o } } };

local promQuery = vquery.prometheus + {
  new(datasource, expr):: vquery.prometheus.new(datasource, expr),
  withRefId(value):: { spec+: { refId: value } },
  withLegendFormat(value):: qspec({ legendFormat: value }),
  withFormat(value):: qspec({ format: value }),
  withInstant(value=true):: qspec({ instant: value }),
  withRange(value=true):: qspec({ range: value }),
  withDatasource(uid):: vquery.withDatasource(uid),
};

local lokiQuery = vquery.loki + {
  new(datasource, expr):: vquery.loki.new(datasource, expr),
  withRefId(value):: { spec+: { refId: value } },
  withLegendFormat(value):: qspec({ legendFormat: value }),
  withDatasource(uid):: vquery.withDatasource(uid),
};

// ---- panel helpers --------------------------------------------------------
// vizConfig spec mutators (options / fieldConfig) and queryGroup mutators.
local viz(o) = { spec+: { vizConfig+: { spec+: o } } };

// Turn a partial vizConfig fieldConfig.defaults object (as produced by
// standardOptions.withUnit / withMappings) into a flat list of override
// properties [{id,value}, ...]. Mirrors grafonnet withPropertiesFromOptions.
local util = {
  propsFromOptions(options)::
    local defs =
      if std.objectHasAll(options, 'spec')
         && std.objectHasAll(options.spec, 'vizConfig')
         && std.objectHasAll(options.spec.vizConfig, 'spec')
         && std.objectHasAll(options.spec.vizConfig.spec, 'fieldConfig')
         && std.objectHasAll(options.spec.vizConfig.spec.fieldConfig, 'defaults')
      then options.spec.vizConfig.spec.fieldConfig.defaults
      else {};
    [{ id: k, value: defs[k] } for k in std.objectFields(defs)],
};

// standardOptions / queryOptions / options / custom helpers shared by every
// panel kind (the grafana base uses g.panel.timeSeries.* / g.panel.table.* /
// g.panel.stat.* interchangeably as namespaced helpers, so we provide one shared
// helper object and alias it under each panel type).
local panelHelpers = {
  standardOptions: {
    withUnit(unit):: viz({ fieldConfig+: { defaults+: { unit: unit } } }),
    withMappings(value):: viz({ fieldConfig+: { defaults+: { mappings: value } } }),
    withOverridesMixin(value)::
      viz({ fieldConfig+: { overrides+: if std.isArray(value) then value else [value] } }),
    color: {
      withMode(value):: viz({ fieldConfig+: { defaults+: { color+: { mode: value } } } }),
    },
  },
  queryOptions: {
    withTargets(value):: { spec+: { data+: { spec+: { queries: if std.isArray(value) then value else [value] } } } },
    withTargetsMixin(value):: { spec+: { data+: { spec+: { queries+: if std.isArray(value) then value else [value] } } } },
    withMaxDataPoints(value):: { spec+: { data+: { spec+: { queryOptions+: { maxDataPoints: value } } } } },
    withTransformations(value):: { spec+: { data+: { spec+: { transformations: value } } } },
    transformation: {
      withId(value):: { kind: value, spec: {} },
      withOptions(value):: { spec+: value },
    },
  },
  options: {
    withShowValue(value):: viz({ options+: { showValue: value } }),
    withContent(value):: viz({ options+: { content: value } }),
  },
  panelOptions: {
    withTransparent(value=true):: { spec+: { transparent: value } },
    withDescription(value):: { spec+: { description: value } },
  },
  // field overrides: a matcher (byName/byQuery) + a list of {id,value} props.
  fieldOverride: {
    byName: {
      new(name):: { matcher: { id: 'byName', options: name }, properties: [] },
      withProperty(id, value):: { properties+: [{ id: id, value: value }] },
      withPropertiesFromOptions(options):: { properties+: util.propsFromOptions(options) },
    },
    byQuery: {
      new(name):: { matcher: { id: 'byFrameRefID', options: name }, properties: [] },
      withProperty(id, value):: { properties+: [{ id: id, value: value }] },
      withPropertiesFromOptions(options):: { properties+: util.propsFromOptions(options) },
    },
  },
};

local panelType(kind) = vpanel[kind] + panelHelpers + {
  new(title):: vpanel[kind].new(title),
};

{
  query: {
    prometheus: promQuery,
    loki: lokiQuery,
  },
  panel: {
    timeSeries: panelType('timeSeries'),
    stat: panelType('stat'),
    table: panelType('table'),
    gauge: panelType('gauge'),
    statusHistory: panelType('statusHistory'),
    text: panelType('text'),
    logs: panelType('logs'),
  },
  dashboard: {
    variable: vvar,
  },
}
