// common-lib tokens/timeSeries — onboard of grafana/jsonnet-libs
// common-lib/common/tokens/timeSeries. Time-series styling tokens reused by the
// panel presets.
{
  lines: {
    width: {
      default: 2,
      alternative: 1,
    },
    opacity: {
      default: 30,
      full: 100,
      none: 0,
    },
    showPoints: {
      default: 'never',
    },
    gradientMode: {
      default: 'opacity',
    },
    interpolation: {
      default: 'smooth',
    },
  },
}
