// This file is generated, do not manually edit.
// 'stat' viz option + fieldConfig setters (root at spec.vizConfig.spec).
local viz(o) = { spec+: { vizConfig+: { spec+: o } } };
{
  standardOptions+: {
    withUnit(value): viz({ fieldConfig+: { defaults+: { unit: value } } }),
    withMin(value): viz({ fieldConfig+: { defaults+: { min: value } } }),
    withMax(value): viz({ fieldConfig+: { defaults+: { max: value } } }),
    withDecimals(value): viz({ fieldConfig+: { defaults+: { decimals: value } } }),
    thresholds+: {
      withSteps(value): viz({ fieldConfig+: { defaults+: { thresholds+: { steps: value } } } }),
      withMode(value='absolute'): viz({ fieldConfig+: { defaults+: { thresholds+: { mode: value } } } }),
    },
    withMappings(value): viz({ fieldConfig+: { defaults+: { mappings: value } } }),
  },
  options+: {
    withColorMode(value): viz({ options+: { colorMode: value } }),
    withGraphMode(value): viz({ options+: { graphMode: value } }),
    withJustifyMode(value): viz({ options+: { justifyMode: value } }),
    withTextMode(value): viz({ options+: { textMode: value } }),
    reduceOptions+: {
      withCalcs(value): viz({ options+: { reduceOptions+: { calcs: value } } }),
      withValues(value=true): viz({ options+: { reduceOptions+: { values: value } } }),
      withFields(value): viz({ options+: { reduceOptions+: { fields: value } } }),
    },
  },
}
