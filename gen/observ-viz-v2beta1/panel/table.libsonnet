// This file is generated, do not manually edit.
// 'table' viz option + fieldConfig setters (root at spec.vizConfig.spec).
local viz(o) = { spec+: { vizConfig+: { spec+: o } } };
{
  standardOptions+: {
    withUnit(value): viz({ fieldConfig+: { defaults+: { unit: value } } }),
    withDecimals(value): viz({ fieldConfig+: { defaults+: { decimals: value } } }),
    withMappings(value): viz({ fieldConfig+: { defaults+: { mappings: value } } }),
    withOverrides(value): viz({ fieldConfig+: { overrides: value } }),
  },
  options+: {
    withShowHeader(value=true): viz({ options+: { showHeader: value } }),
    footer+: {
      withShow(value=true): viz({ options+: { footer+: { show: value } } }),
      withReducer(value): viz({ options+: { footer+: { reducer: value } } }),
    },
  },
}
