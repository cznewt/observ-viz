// This file is generated, do not manually edit.
// v2 variable-kind field setters (root at `spec`). Constructors (new) and the
// kind tag live in custom/variable.libsonnet, merged over these per kind.
local common = {
  withName(value): { spec+: { name: value } },
  withLabel(value): { spec+: { label: value } },
  withDescription(value): { spec+: { description: value } },
  withHide(value): { spec+: { hide: value } },
  withSkipUrlSync(value=true): { spec+: { skipUrlSync: value } },
};
local selection = {
  withMulti(value=true): { spec+: { multi: value } },
  withIncludeAll(value=true): { spec+: { includeAll: value } },
  withAllValue(value): { spec+: { allValue: value } },
};
local withDsRef = {
  withDatasource(value): { spec+: { datasource: value } },
  withDatasourceFromVariable(name): { spec+: { datasource: { uid: '${' + name + '}' } } },
};
{
  query: common + selection + withDsRef + {
    withQuery(value): { spec+: { query: value } },
    withRegex(value): { spec+: { regex: value } },
    withSort(value): { spec+: { sort: value } },
    withRefresh(value): { spec+: { refresh: value } },
  },
  datasource: common + selection + {
    withPluginId(value): { spec+: { pluginId: value } },
    withRegex(value): { spec+: { regex: value } },
  },
  custom: common + selection + {
    withQuery(value): { spec+: { query: value } },
    withOptions(value): { spec+: { options: value } },
  },
  interval: common + {
    withQuery(value): { spec+: { query: value } },
    withOptions(value): { spec+: { options: value } },
    withAuto(value=true): { spec+: { auto: value } },
  },
  text: common + { withQuery(value): { spec+: { query: value } } },
  constant: common + { withQuery(value): { spec+: { query: value } } },
  groupBy: common + withDsRef,
  adhoc: common + withDsRef,
}
