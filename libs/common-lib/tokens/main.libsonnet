// common-lib tokens — onboard of grafana/jsonnet-libs common-lib/common/tokens.
{
  base: {
    colors: import 'libs/common-lib/tokens/colors.libsonnet',
  },
  panels: {
    timeSeries: import 'libs/common-lib/tokens/timeSeries.libsonnet',
  },
}
