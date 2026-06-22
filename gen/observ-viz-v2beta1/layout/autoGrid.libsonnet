// This file is generated, do not manually edit.
// AutoGridLayout builder (schema-driven from AutoGridLayoutKind/Spec).
// autoGrid.item(element) wraps an element NAME in an AutoGridLayoutItemKind.
{
  new(columnWidthMode='standard', rowHeightMode='standard'): { kind: 'AutoGridLayout', spec: { columnWidthMode: columnWidthMode, rowHeightMode: rowHeightMode, items: [] } },
  '#withMaxColumnCount':: { 'function': { args: [{ default: 3, enums: null, name: 'value', type: ['number'] }], help: 'Set maxColumnCount.' } },
  withMaxColumnCount(value): { spec+: { maxColumnCount: value } },
  '#withColumnWidthMode':: { 'function': { args: [{ default: 'standard', enums: ['narrow', 'standard', 'wide', 'custom'], name: 'value', type: ['string'] }], help: 'Set columnWidthMode.' } },
  withColumnWidthMode(value): { spec+: { columnWidthMode: value } },
  '#withColumnWidth':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['number'] }], help: 'Set columnWidth.' } },
  withColumnWidth(value): { spec+: { columnWidth: value } },
  '#withRowHeightMode':: { 'function': { args: [{ default: 'standard', enums: ['short', 'standard', 'tall', 'custom'], name: 'value', type: ['string'] }], help: 'Set rowHeightMode.' } },
  withRowHeightMode(value): { spec+: { rowHeightMode: value } },
  '#withRowHeight':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['number'] }], help: 'Set rowHeight.' } },
  withRowHeight(value): { spec+: { rowHeight: value } },
  '#withFillScreen':: { 'function': { args: [{ default: false, enums: null, name: 'value', type: ['boolean'] }], help: 'Set fillScreen.' } },
  withFillScreen(value=false): { spec+: { fillScreen: value } },
  '#withItems':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Set items ([]AutoGridLayoutItemKind).' } },
  withItems(value): { spec+: { items: value } },
  withItemsMixin(value): { spec+: { items+: value } },
  item: {
    new(element): { kind: 'AutoGridLayoutItem', spec: { element: { kind: 'ElementReference', name: element } } },
    '#withRepeat':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'Set repeat (AutoGridRepeatOptions).' } },
    withRepeat(value): { spec+: { repeat: value } },
    '#withConditionalRendering':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'Set conditionalRendering (ConditionalRenderingGroupKind).' } },
    withConditionalRendering(value): { spec+: { conditionalRendering: value } },
  },
}
