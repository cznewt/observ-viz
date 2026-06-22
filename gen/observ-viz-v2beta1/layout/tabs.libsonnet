// This file is generated, do not manually edit.
// TabsLayout builder (schema-driven from TabsLayoutKind/Spec).
// tabs.tab(layout) is a TabsLayoutTabKind holding a nested layout.
{
  new(): { kind: 'TabsLayout', spec: { tabs: [] } },
  '#withTabs':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Set tabs ([]TabsLayoutTabKind).' } },
  withTabs(value): { spec+: { tabs: value } },
  withTabsMixin(value): { spec+: { tabs+: value } },
  tab: {
    new(layout): { kind: 'TabsLayoutTab', spec: { layout: layout } },
    '#withTitle':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Set title.' } },
    withTitle(value): { spec+: { title: value } },
    '#withLayout':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'Set layout.' } },
    withLayout(value): { spec+: { layout: value } },
    '#withConditionalRendering':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'Set conditionalRendering (ConditionalRenderingGroupKind).' } },
    withConditionalRendering(value): { spec+: { conditionalRendering: value } },
    '#withRepeat':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'Set repeat (TabRepeatOptions).' } },
    withRepeat(value): { spec+: { repeat: value } },
    '#withVariables':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Set variables ([]VariableKind).' } },
    withVariables(value): { spec+: { variables: value } },
    withVariablesMixin(value): { spec+: { variables+: value } },
  },
}
