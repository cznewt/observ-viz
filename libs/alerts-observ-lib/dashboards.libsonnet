// alerts-observ-lib — the alerts-overview dashboard (summary stats row + an
// alert-list / firing-table / timeline detail row), with alert annotations.
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local element = import 'custom/element.libsonnet';
local layout = import 'custom/layout.libsonnet';

function(cfg, signals, annotations, panels)
  local elements =
    element.panel('firing', panels.firing)
    + element.panel('critical', panels.critical)
    + element.panel('warning', panels.warning)
    + element.panel('alertsOverview', panels.alertsOverview)
    + element.panel('firingTable', panels.firingTable)
    + element.panel('timeline', panels.timeline);

  local summaryRow = layout.rows.row(
    'Summary',
    layout.grid.new() + layout.grid.withItems([
      layout.grid.item('firing', 0, 0, 8, 4),
      layout.grid.item('critical', 8, 0, 8, 4),
      layout.grid.item('warning', 16, 0, 8, 4),
    ])
  );
  local detailRow = layout.rows.row(
    'Alerts',
    layout.grid.new() + layout.grid.withItems([
      layout.grid.item('alertsOverview', 0, 0, 24, 8),
      layout.grid.item('firingTable', 0, 8, 12, 8),
      layout.grid.item('timeline', 12, 8, 12, 8),
    ])
  );

  dashboard.new(cfg.dashboardTitle)
  + dashboard.withUid(cfg.uid)
  + dashboard.withTags(cfg.dashboardTags)
  + dashboard.withAnnotations([annotations.critical, annotations.warning, annotations.info])
  + dashboard.withElements(elements)
  + dashboard.withLayout(layout.rows.new() + layout.rows.withRows([summaryRow, detailRow]))
