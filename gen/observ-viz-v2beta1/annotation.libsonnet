// This file is generated, do not manually edit.
// AnnotationQueryKind field setters (root at `spec`). Compose with the
// hand-written custom/annotation.libsonnet `new(name)`.
{
  '#withName':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Annotation name.' } },
  withName(value): { spec+: { name: value } },
  '#withDatasource':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'DataSourceRef {type,uid}.' } },
  withDatasource(value): { spec+: { datasource: value } },
  '#withQuery':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['object'] }], help: 'DataQueryKind.' } },
  withQuery(value): { spec+: { query: value } },
  '#withEnable':: { 'function': { args: [{ default: true, enums: null, name: 'value', type: ['boolean'] }], help: 'Enable annotation.' } },
  withEnable(value=true): { spec+: { enable: value } },
  '#withHide':: { 'function': { args: [{ default: true, enums: null, name: 'value', type: ['boolean'] }], help: 'Hide annotation toggle.' } },
  withHide(value=true): { spec+: { hide: value } },
  '#withIconColor':: { 'function': { args: [{ default: null, enums: null, name: 'value', type: ['string'] }], help: 'Annotation icon color.' } },
  withIconColor(value): { spec+: { iconColor: value } },
}
