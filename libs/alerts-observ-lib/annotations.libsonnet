// alerts-observ-lib — alert annotations, built from the common-lib annotation
// primitives (reused, not redefined).
local annotations = import 'libs/common-lib/annotations.libsonnet';

local sel(cfg) = if cfg.filteringSelector != '' then ', ' + cfg.filteringSelector else '';
local alertsExpr(cfg, severity) =
  'ALERTS{alertstate="firing", severity="' + severity + '"' + sel(cfg) + '}';

function(cfg) {
  critical: annotations.critical('Critical alerts', cfg.datasource, alertsExpr(cfg, 'critical')),
  warning: annotations.warning('Warning alerts', cfg.datasource, alertsExpr(cfg, 'warning')),
  info: annotations.info('Info alerts', cfg.datasource, alertsExpr(cfg, 'info')),
}
