// observ-viz reusable deploy panels (hand-written). Return PanelKind elements.
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  // Build/version info table from a *_build_info metric (instant, table).
  versionInfo(title='Build info', datasource='${datasource}', metric='build_info', selector=''):
    panel.table.new(title)
    + panel.table.withTargets([
      query.prometheus.new(datasource, metric + '{' + selector + '}')
      + query.prometheus.withInstant(true)
      + query.prometheus.withFormat('table'),
    ]),

  // Deploy frequency (restarts) over time as bars.
  deployFrequency(title='Deploys', datasource='${datasource}', selector=''):
    panel.timeSeries.new(title)
    + panel.timeSeries.withTargets([
      query.prometheus.new(datasource, 'sum(changes(process_start_time_seconds{' + selector + '}[$__rate_interval]))'),
    ])
    + panel.timeSeries.standardOptions.withUnit('short')
    + panel.timeSeries.standardOptions.withMin(0)
    + panel.timeSeries.custom.withDrawStyle('bars'),

  // Uptime since last restart (stat).
  uptime(title='Uptime', datasource='${datasource}', selector=''):
    panel.stat.new(title)
    + panel.stat.withTargets([
      query.prometheus.new(datasource, 'time() - process_start_time_seconds{' + selector + '}')
      + query.prometheus.withInstant(true),
    ])
    + panel.stat.standardOptions.withUnit('s'),
}
