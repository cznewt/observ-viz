// observ-viz alerts-overview pattern (hand-written).
// A full alerts dashboard: summary stats + alert list + firing table + timeline,
// laid out with a RowsLayout (each row nests a grid). Reuses alert/ panels+signals.
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local element = import 'custom/element.libsonnet';
local layout = import 'custom/layout.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(datasource='${datasource}', selector='', uid='alerts-overview', title='Alerts overview'):
    local elements =
      element.panel('firing', alert.signals.firing(datasource, selector).asStat('Firing'))
      + element.panel('critical', alert.signals.critical(datasource, selector).asStat('Critical'))
      + element.panel('warning', alert.signals.warning(datasource, selector).asStat('Warning'))
      + element.panel('list', alert.panels.list('Alerts', selector))
      + element.panel('byNs', alert.panels.firingTable('Firing by labels', datasource, selector))
      + element.panel('timeline', alert.panels.timeline('Alert state', datasource, selector));

    local summaryRow = layout.rows.row(
      'Summary',
      layout.grid.new() + layout.grid.withItems([
        layout.grid.item('firing', 0, 0, 8, 4),
        layout.grid.item('critical', 8, 0, 8, 4),
        layout.grid.item('warning', 16, 0, 8, 4),
      ])
    );
    local detailRow = layout.rows.row(
      'Detail',
      layout.grid.new() + layout.grid.withItems([
        layout.grid.item('list', 0, 0, 24, 8),
        layout.grid.item('byNs', 0, 8, 12, 8),
        layout.grid.item('timeline', 12, 8, 12, 8),
      ])
    );

    dashboard.new(title)
    + dashboard.withUid(uid)
    + dashboard.withTags(['alerts', 'generated'])
    + dashboard.withElements(elements)
    + dashboard.withLayout(layout.rows.new() + layout.rows.withRows([summaryRow, detailRow])),
}
