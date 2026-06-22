// This file is generated, do not manually edit.
// ConditionalRendering builders (schema-driven from the
// ConditionalRendering{Group,Data,Variable,TimeRangeSize}Kind/Spec defs).
// Attach a group to a row/tab/auto-grid item via withConditionalRendering.
{
  group: {
    new(visibility, condition, items=[]): { kind: 'ConditionalRenderingGroup', spec: { visibility: visibility, condition: condition, items: items } },
    '#withVisibility':: { 'function': { args: [{ default: null, enums: ['show', 'hide'], name: 'value', type: ['string'] }], help: 'Set visibility.' } },
    withVisibility(value): { spec+: { visibility: value } },
    '#withCondition':: { 'function': { args: [{ default: null, enums: ['and', 'or'], name: 'value', type: ['string'] }], help: 'Set condition.' } },
    withCondition(value): { spec+: { condition: value } },
    '#withItems':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Set items.' } },
    withItems(value): { spec+: { items: value } },
    withItemsMixin(value): { spec+: { items+: value } },
  },
  data: {
    new(value): { kind: 'ConditionalRenderingData', spec: { value: value } },
    '#withValue':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['boolean'] }], help: 'Set value.' } },
    withValue(value): { spec+: { value: value } },
  },
  variable: {
    new(variable, operator, value): { kind: 'ConditionalRenderingVariable', spec: { variable: variable, operator: operator, value: value } },
    '#withVariable':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Set variable.' } },
    withVariable(value): { spec+: { variable: value } },
    '#withOperator':: { 'function': { args: [{ default: null, enums: ['equals', 'notEquals', 'matches', 'notMatches'], name: 'value', type: ['string'] }], help: 'Set operator.' } },
    withOperator(value): { spec+: { operator: value } },
    '#withValue':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Set value.' } },
    withValue(value): { spec+: { value: value } },
  },
  timeRangeSize: {
    new(value): { kind: 'ConditionalRenderingTimeRangeSize', spec: { value: value } },
    '#withValue':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Set value.' } },
    withValue(value): { spec+: { value: value } },
  },
  withConditionalRendering(group): { spec+: { conditionalRendering: group } },
}
