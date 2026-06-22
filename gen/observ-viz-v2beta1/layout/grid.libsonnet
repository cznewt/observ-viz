// This file is generated, do not manually edit.
// GridLayout builder (schema-driven from GridLayoutKind/Spec).
// grid.item(element, x, y, width, height) wraps an element NAME in a
// GridLayoutItemKind (ElementReference) — never a panel object.
{
  new(): { kind: 'GridLayout', spec: { items: [] } },
  '#withItems':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Set items ([]GridLayoutItemKind).' } },
  withItems(value): { spec+: { items: value } },
  withItemsMixin(value): { spec+: { items+: value } },
  item: {
    new(x, y, width, height, element): { kind: 'GridLayoutItem', spec: { x: x, y: y, width: width, height: height, element: { kind: 'ElementReference', name: element } } },
    '#withX':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['integer'] }], help: 'Set x.' } },
    withX(value): { spec+: { x: value } },
    '#withY':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['integer'] }], help: 'Set y.' } },
    withY(value): { spec+: { y: value } },
    '#withWidth':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['integer'] }], help: 'Set width.' } },
    withWidth(value): { spec+: { width: value } },
    '#withHeight':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['integer'] }], help: 'Set height.' } },
    withHeight(value): { spec+: { height: value } },
    '#withRepeat':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'Set repeat (RepeatOptions).' } },
    withRepeat(value): { spec+: { repeat: value } },
  },
}
