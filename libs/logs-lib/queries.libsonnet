// logs-lib — Loki query builders.
local query = import 'custom/query.libsonnet';

function(cfg) {
  local stream = '{' + cfg.filterSelector + '}' + (if cfg.pipeline != '' then ' ' + cfg.pipeline else ''),

  // raw log stream
  logs: query.loki.new(cfg.datasource, stream),

  // log volume grouped by level (for the stacked volume panel)
  volumeByLevel:
    query.loki.new(cfg.datasource, 'sum by (' + cfg.levelLabel + ') (count_over_time(' + stream + ' [$__auto]))')
    + query.loki.withLegendFormat('{{' + cfg.levelLabel + '}}'),

  // total log rate
  rate: query.loki.new(cfg.datasource, 'sum(rate(' + stream + ' [$__rate_interval]))'),
}
