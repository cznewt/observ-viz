// This file is generated, do not manually edit.
// RowsLayout builder (schema-driven from RowsLayoutKind/Spec).
// rows.row(layout) is a RowsLayoutRowKind holding a nested layout.
{
  new(): { kind: 'RowsLayout', spec: { rows: [] } },
  '#withRows':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Set rows ([]RowsLayoutRowKind).' } },
  withRows(value): { spec+: { rows: value } },
  withRowsMixin(value): { spec+: { rows+: value } },
  row: {
    new(layout): { kind: 'RowsLayoutRow', spec: { layout: layout } },
    '#withTitle':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Set title.' } },
    withTitle(value): { spec+: { title: value } },
    '#withCollapse':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['boolean'] }], help: 'Set collapse.' } },
    withCollapse(value): { spec+: { collapse: value } },
    '#withHideHeader':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['boolean'] }], help: 'Set hideHeader.' } },
    withHideHeader(value): { spec+: { hideHeader: value } },
    '#withFillScreen':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['boolean'] }], help: 'Set fillScreen.' } },
    withFillScreen(value): { spec+: { fillScreen: value } },
    '#withConditionalRendering':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'Set conditionalRendering (ConditionalRenderingGroupKind).' } },
    withConditionalRendering(value): { spec+: { conditionalRendering: value } },
    '#withRepeat':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'Set repeat (RowRepeatOptions).' } },
    withRepeat(value): { spec+: { repeat: value } },
    '#withLayout':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'Set layout.' } },
    withLayout(value): { spec+: { layout: value } },
    '#withVariables':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Set variables ([]VariableKind).' } },
    withVariables(value): { spec+: { variables: value } },
    withVariablesMixin(value): { spec+: { variables+: value } },
  },
}
