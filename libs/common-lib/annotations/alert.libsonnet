// common-lib annotations — firing alerts. One region per firing alert (the
// ALERTS series a Mimir / Prometheus ruler writes is 1 while it fires), in the
// severity presets' colours, titled with the alert name and tagged with where
// it fires. No Alertmanager datasource needed.
//   annotations.alert.bySeverity(ds, 'cluster=~"$cluster"')   // critical + warning on, info off
local base = import 'libs/common-lib/annotations/base.libsonnet';
local critical = import 'libs/common-lib/annotations/critical.libsonnet';
local warning = import 'libs/common-lib/annotations/warning.libsonnet';
local info = import 'libs/common-lib/annotations/info.libsonnet';
local tagKeys = ['alertname', 'severity', 'namespace', 'pod', 'instance'];
base {
  // ALERTS{alertstate="firing"} narrowed to a severity matcher and the board selector
  firing(datasource, selector='', severity='')::
    local m = std.filter(function(p) p != '', ['alertstate="firing"', severity, selector]);
    base.target(datasource, 'ALERTS{' + std.join(', ', m) + '}'),

  // preset: 'critical' | 'warning' | 'info' (colour); a viewer toggle either way
  new(title, target, preset='warning', enabled=true)::
    local p = if preset == 'critical' then critical else if preset == 'info' then info else warning;
    p.new(title, target)
    + base.withTitleFormat('{{alertname}}')
    + base.withTagKeys(tagKeys)
    + base.asToggle(enabled),

  // the three toggles a board carries: critical (also error / page) and
  // warning on, info off - it is context, and on a busy cluster it is noise
  bySeverity(datasource, selector='', prefix='')::
    local t(s) = if prefix != '' then prefix + ' ' + s else s;
    [
      self.new(t('Critical alerts'), self.firing(datasource, selector, 'severity=~"critical|error|page"'), 'critical'),
      self.new(t('Warning alerts'), self.firing(datasource, selector, 'severity="warning"'), 'warning'),
      self.new(t('Info alerts'), self.firing(datasource, selector, 'severity!~"critical|error|page|warning"'), 'info', false),
    ],
}
