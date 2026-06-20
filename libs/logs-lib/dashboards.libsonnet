// logs-lib — a logs dashboard: log-volume + rate, then the log stream.
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local element = import 'custom/element.libsonnet';
local layout = import 'custom/layout.libsonnet';

function(cfg, panels)
  local elements =
    element.panel('rate', panels.rate)
    + element.panel('volume', panels.logsVolume)
    + element.panel('logs', panels.logs);

  dashboard.new(cfg.dashboardTitle)
  + dashboard.withUid(cfg.uid)
  + dashboard.withTags(cfg.dashboardTags)
  + dashboard.withElements(elements)
  + dashboard.withLayout(
    layout.rows.new() + layout.rows.withRows([
      layout.rows.row('Volume', layout.grid.new() + layout.grid.withItems([
        layout.grid.item('rate', 0, 0, 4, 8),
        layout.grid.item('volume', 4, 0, 20, 8),
      ])),
      layout.rows.row('Logs', layout.grid.new() + layout.grid.withItems([
        layout.grid.item('logs', 0, 0, 24, 16),
      ])),
    ])
  )
