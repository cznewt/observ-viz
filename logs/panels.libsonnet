// observ-viz reusable log panels (hand-written). Return PanelKind elements.
local panel = import 'custom/panel.libsonnet';
local lq = import 'logs/query.libsonnet';

{
  // A logs viz showing raw log lines for a stream.
  logs(title, datasource, selector, pipeline=''):
    panel.base('logs', title)
    + panel.withTargets([lq.loki(datasource, selector, pipeline)])
    + { spec+: { vizConfig+: { spec+: { options+: {
      showTime: true,
      wrapLogMessage: false,
      enableLogDetails: true,
      dedupStrategy: 'none',
      sortOrder: 'Descending',
    } } } } },

  // Log volume over time as stacked bars.
  volume(title, datasource, selector, pipeline=''):
    panel.timeSeries.new(title)
    + panel.timeSeries.withTargets([lq.rate(datasource, selector, pipeline)])
    + panel.timeSeries.standardOptions.withUnit('logs')
    + panel.timeSeries.standardOptions.withMin(0)
    + panel.timeSeries.custom.withDrawStyle('bars')
    + panel.timeSeries.custom.stacking.withMode('normal'),
}
