// This file is generated, do not manually edit.
// Prometheus query-spec setters. Root at spec.query.spec so they compose with
// custom/query.libsonnet new('prometheus', ...).
local q(o) = { spec+: { query+: { spec+: o } } };
{
  '#withExpr':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'PromQL expression.' } },
  withExpr(value): q({ expr: value }),
  '#withLegendFormat':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Legend template.' } },
  withLegendFormat(value): q({ legendFormat: value }),
  '#withFormat':: { 'function': { args: [{ default: null, enums: ['time_series', 'table', 'heatmap'], name: 'value', type: ['string'] }], help: 'Result format.' } },
  withFormat(value): q({ format: value }),
  '#withInstant':: { 'function': { args: [{ default: true, enums: null, name: 'value', type: ['boolean'] }], help: 'Instant query.' } },
  withInstant(value=true): q({ instant: value }),
  '#withRange':: { 'function': { args: [{ default: true, enums: null, name: 'value', type: ['boolean'] }], help: 'Range query.' } },
  withRange(value=true): q({ range: value }),
  '#withInterval':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Min step interval.' } },
  withInterval(value): q({ interval: value }),
  '#withEditorMode':: { 'function': { args: [{ default: null, enums: ['code', 'builder'], name: 'value', type: ['string'] }], help: 'Query editor mode.' } },
  withEditorMode(value): q({ editorMode: value }),
  '#withExemplar':: { 'function': { args: [{ default: true, enums: null, name: 'value', type: ['boolean'] }], help: 'Query exemplars.' } },
  withExemplar(value=true): q({ exemplar: value }),
}
