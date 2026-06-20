// logs-lib — reusable log panels: a logs viz + a stacked log-volume-by-level
// (with per-level colour overrides) + a total log-rate stat.
local panel = import 'custom/panel.libsonnet';

local levelColor(level, color) = {
  matcher: { id: 'byName', options: level },
  properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: color } }],
};

function(cfg, queries) {
  // raw log lines
  logs:
    panel.logs.new('Logs')
    + panel.logs.withTargets([queries.logs])
    + panel.logs.withOptions({
      showTime: true,
      wrapLogMessage: true,
      enableLogDetails: true,
      dedupStrategy: 'none',
      sortOrder: 'Descending',
      prettifyLogMessage: false,
    }),

  // stacked log volume grouped by level
  logsVolume:
    panel.timeSeries.new('Log volume')
    + panel.timeSeries.withTargets([queries.volumeByLevel])
    + panel.timeSeries.standardOptions.withUnit('logs')
    + panel.timeSeries.standardOptions.withMin(0)
    + panel.timeSeries.custom.withDrawStyle('bars')
    + panel.timeSeries.custom.withFillOpacity(60)
    + panel.timeSeries.custom.stacking.withMode('normal')
    + panel.timeSeries.standardOptions.withOverrides([
      levelColor('error', 'red'),
      levelColor('err', 'red'),
      levelColor('critical', 'dark-red'),
      levelColor('warn', 'orange'),
      levelColor('warning', 'orange'),
      levelColor('info', 'green'),
      levelColor('debug', 'blue'),
      levelColor('trace', 'purple'),
      levelColor('unknown', 'gray'),
    ]),

  // total log rate
  rate:
    panel.stat.new('Log rate')
    + panel.stat.withTargets([queries.rate])
    + panel.stat.standardOptions.withUnit('logs'),
}
