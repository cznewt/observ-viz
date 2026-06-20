// alerts-observ-lib — alert annotations, built from the common-lib annotation
// primitives (reused, not redefined). Faithful to grafana's annotations API:
// the severity preset .new(title, target).
local annotations = import 'libs/common-lib/annotations/main.libsonnet';

local sel(cfg) = if cfg.filteringSelector != '' then ', ' + cfg.filteringSelector else '';
local alertsExpr(cfg, severity) =
  'ALERTS{alertstate="firing", severity="' + severity + '"' + sel(cfg) + '}';
local tgt(cfg, severity) = annotations.base.target(cfg.datasource, alertsExpr(cfg, severity));

function(cfg) {
  critical: annotations.critical.new('Critical alerts', tgt(cfg, 'critical')),
  warning: annotations.warning.new('Warning alerts', tgt(cfg, 'warning')),
  info: annotations.info.new('Info alerts', tgt(cfg, 'info')),
}
