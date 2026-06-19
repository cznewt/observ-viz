// This file is generated, do not manually edit.
// 'timeseries' viz option + fieldConfig setters. Each roots at
// spec.vizConfig.spec so it composes with custom/panel.libsonnet new('timeseries').
local viz(o) = { spec+: { vizConfig+: { spec+: o } } };
{
  standardOptions+: {
    withUnit(value): viz({ fieldConfig+: { defaults+: { unit: value } } }),
    withMin(value): viz({ fieldConfig+: { defaults+: { min: value } } }),
    withMax(value): viz({ fieldConfig+: { defaults+: { max: value } } }),
    withDecimals(value): viz({ fieldConfig+: { defaults+: { decimals: value } } }),
    withNoValue(value): viz({ fieldConfig+: { defaults+: { noValue: value } } }),
    thresholds+: {
      withSteps(value): viz({ fieldConfig+: { defaults+: { thresholds+: { steps: value } } } }),
      withMode(value='absolute'): viz({ fieldConfig+: { defaults+: { thresholds+: { mode: value } } } }),
    },
    withOverrides(value): viz({ fieldConfig+: { overrides: value } }),
  },
  options+: {
    legend+: {
      withShowLegend(value=true): viz({ options+: { legend+: { showLegend: value } } }),
      withDisplayMode(value): viz({ options+: { legend+: { displayMode: value } } }),
      withPlacement(value): viz({ options+: { legend+: { placement: value } } }),
      withCalcs(value): viz({ options+: { legend+: { calcs: value } } }),
    },
    tooltip+: {
      withMode(value): viz({ options+: { tooltip+: { mode: value } } }),
    },
  },
  custom+: {
    withFillOpacity(value): viz({ fieldConfig+: { defaults+: { custom+: { fillOpacity: value } } } }),
    withLineWidth(value): viz({ fieldConfig+: { defaults+: { custom+: { lineWidth: value } } } }),
    withShowPoints(value): viz({ fieldConfig+: { defaults+: { custom+: { showPoints: value } } } }),
    withDrawStyle(value): viz({ fieldConfig+: { defaults+: { custom+: { drawStyle: value } } } }),
    withGradientMode(value): viz({ fieldConfig+: { defaults+: { custom+: { gradientMode: value } } } }),
    stacking+: {
      withMode(value): viz({ fieldConfig+: { defaults+: { custom+: { stacking+: { mode: value } } } } }),
    },
    scaleDistribution+: {
      withType(value): viz({ fieldConfig+: { defaults+: { custom+: { scaleDistribution+: { type: value } } } } }),
      withLog(value): viz({ fieldConfig+: { defaults+: { custom+: { scaleDistribution+: { log: value } } } } }),
    },
  },
}
