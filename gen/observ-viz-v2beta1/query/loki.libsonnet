// This file is generated, do not manually edit.
// Loki query-spec setters (root at spec.query.spec).
local q(o) = { spec+: { query+: { spec+: o } } };
{
  '#withExpr':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'LogQL expression.' } },
  withExpr(value): q({ expr: value }),
  '#withLegendFormat':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Legend template.' } },
  withLegendFormat(value): q({ legendFormat: value }),
  '#withQueryType':: { 'function': { args: [{ default: null, enums: ['range', 'instant'], name: 'value', type: ['string'] }], help: 'Loki query type.' } },
  withQueryType(value): q({ queryType: value }),
  '#withMaxLines':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['integer'] }], help: 'Max log lines.' } },
  withMaxLines(value): q({ maxLines: value }),
  '#withDirection':: { 'function': { args: [{ default: null, enums: ['forward', 'backward'], name: 'value', type: ['string'] }], help: 'Sort direction.' } },
  withDirection(value): q({ direction: value }),
}
