// alerts-observ-lib — ALERTS-metric signals (firing / by-severity).
local alert = import 'libs/common-lib/alert/main.libsonnet';
function(cfg) {
  firing: alert.signals.firing(cfg.datasource, cfg.filteringSelector),
  critical: alert.signals.critical(cfg.datasource, cfg.filteringSelector),
  warning: alert.signals.warning(cfg.datasource, cfg.filteringSelector),
  info: alert.signals.info(cfg.datasource, cfg.filteringSelector),
}
