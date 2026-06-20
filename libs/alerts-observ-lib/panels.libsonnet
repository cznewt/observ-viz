// alerts-observ-lib — reusable alert panels (alert-list overview + firing table
// + state timeline + by-severity stats). Returns PanelKind elements.
local alert = import 'libs/common-lib/alert/main.libsonnet';
function(cfg, signals) {
  alertsOverview: alert.panels.list('Alerts', cfg.filteringSelector, cfg.groupMode, cfg.groupLabels),
  firingTable: alert.panels.firingTable('Firing by labels', cfg.datasource, cfg.filteringSelector),
  timeline: alert.panels.timeline('Alert state', cfg.datasource, cfg.filteringSelector),
  firing: signals.firing.asStat('Firing'),
  critical: signals.critical.asStat('Critical'),
  warning: signals.warning.asStat('Warning'),
}
