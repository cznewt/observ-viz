// This file is generated, do not manually edit.
// DashboardV2Spec field setters. These root at `spec` so they compose with the
// hand-written custom/dashboard.libsonnet `new(title)` envelope.
{
  '#withTitle':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Dashboard title.' } },
  withTitle(value): { spec+: { title: value } },
  '#withDescription':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Dashboard description.' } },
  withDescription(value): { spec+: { description: value } },
  '#withCursorSync':: { 'function': { args: [{ default: 'Off', enums: ['Off', 'Crosshair', 'Tooltip'], name: 'value', type: ['string'] }], help: 'Cursor sync mode (string enum).' } },
  withCursorSync(value): { spec+: { cursorSync: value } },
  '#withLiveNow':: { 'function': { args: [{ default: true, enums: null, name: 'value', type: ['boolean'] }], help: 'Continuously re-evaluate "now".' } },
  withLiveNow(value=true): { spec+: { liveNow: value } },
  '#withPreload':: { 'function': { args: [{ default: true, enums: null, name: 'value', type: ['boolean'] }], help: 'Load all panels on dashboard load.' } },
  withPreload(value=true): { spec+: { preload: value } },
  '#withEditable':: { 'function': { args: [{ default: true, enums: null, name: 'value', type: ['boolean'] }], help: 'Allow editing.' } },
  withEditable(value=true): { spec+: { editable: value } },
  '#withTags':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Dashboard tags.' } },
  withTags(value): { spec+: { tags: value } },
  '#withTagsMixin':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Append dashboard tags.' } },
  withTagsMixin(value): { spec+: { tags+: value } },
  '#withLinks':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Dashboard links.' } },
  withLinks(value): { spec+: { links: value } },
  '#withLinksMixin':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['array'] }], help: 'Append dashboard links.' } },
  withLinksMixin(value): { spec+: { links+: value } },
}
