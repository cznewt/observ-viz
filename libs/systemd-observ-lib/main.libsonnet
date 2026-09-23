// observ-viz systemd pack (hand-written).
// systemd units from the node_exporter systemd collector: unit state over
// time, active/failed counts, failed units, restarts (when the collector's
// restart metrics are enabled) and the overall system state.
//   g.libs.system.systemd.new({}).grafana.dashboard
//   g.libs.system.systemd.units(ds, 'instance=~"$host"', 'alloy.service')
//     -> { stats: {..}, wide: {..} } element maps for embedding in a service board
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

local unitMappings = [{ type: 'value', options: {
  '1': { text: 'active', color: 'green', index: 0 },
  '2': { text: 'transitioning', color: 'yellow', index: 1 },
  '3': { text: 'inactive', color: 'text', index: 2 },
  '4': { text: 'failed', color: 'red', index: 3 },
} }];

// signals for a host selector and a unit-name regex.
local unitSignals(datasource, selector, unit) = {
  local u = 'name=~"' + unit + '", ',
  local sig(name, expr, unit_, legend='{{instance}}', desc='') =
    signal.new(name, 'prometheus', datasource, expr, unit_).filteringSelector(selector).withLegendFormat(legend).withDescription(desc),
  state: sig('Unit state', 'max by (instance, name) ((node_systemd_unit_state{' + u + 'state="active", %(queriesSelector)s} == 1) * 1 or (node_systemd_unit_state{' + u + 'state=~"activating|deactivating", %(queriesSelector)s} == 1) * 2 or (node_systemd_unit_state{' + u + 'state="inactive", %(queriesSelector)s} == 1) * 3 or (node_systemd_unit_state{' + u + 'state="failed", %(queriesSelector)s} == 1) * 4)', 'short', '{{instance}} {{name}}', desc='State of each unit on each host: active, transitioning (activating/deactivating), inactive or failed.'),
  active: sig('Active units', 'count(node_systemd_unit_state{' + u + 'state="active", %(queriesSelector)s} == 1) or vector(0)', 'short', 'active', desc='Units in the active state.'),
  failed: sig('Failed units', 'count(node_systemd_unit_state{' + u + 'state="failed", %(queriesSelector)s} == 1) or vector(0)', 'short', 'failed', desc='Units in the failed state.'),
  inactive: sig('Inactive units', 'count(node_systemd_unit_state{' + u + 'state="inactive", %(queriesSelector)s} == 1) or vector(0)', 'short', 'inactive', desc='Units that are loaded but not running.'),
  hosts: sig('Hosts', 'count(count by (instance) (node_systemd_unit_state{' + u + '%(queriesSelector)s}))', 'short', 'hosts', desc='Hosts that have a matching unit at all.'),
  failedTable: sig('Failed units', 'node_systemd_unit_state{' + u + 'state="failed", %(queriesSelector)s} == 1', 'short', '{{instance}} {{name}}', desc='Units currently failed, by host.'),
  restarts: sig('Unit restarts', 'sum by (instance, name) (increase(node_systemd_service_restart_total{' + u + '%(queriesSelector)s}[$__rate_interval]))', 'short', '{{instance}} {{name}}', desc='Service restarts (needs the collector restart metrics: --collector.systemd.enable-restarts-metrics).'),
  // resource use per unit, from the collector's task metrics
  tasks: sig('Tasks', 'node_systemd_unit_tasks_current{' + u + '%(queriesSelector)s}', 'short', '{{instance}} {{name}}', desc='Tasks (threads and processes) the unit runs. Needs --collector.systemd.enable-task-metrics.'),
  tasksMax: sig('Task limit', 'node_systemd_unit_tasks_max{' + u + '%(queriesSelector)s}', 'short', '{{instance}} {{name}} limit', desc='TasksMax for the unit. Hitting it blocks the unit from forking.'),
  tasksUtil: sig('Task usage', '100 * node_systemd_unit_tasks_current{' + u + '%(queriesSelector)s} / clamp_min(node_systemd_unit_tasks_max{' + u + '%(queriesSelector)s}, 1)', 'percent', '{{instance}} {{name}}', desc='Tasks against the unit limit.'),
  uptime: sig('Uptime', 'time() - node_systemd_unit_start_time_seconds{' + u + '%(queriesSelector)s}', 's', '{{instance}} {{name}}', desc='Time since the unit last started. A drop marks a restart.'),
};

local unitElements(signals, prefix='') = {
  signals:: signals,
  stats: {
    [prefix + 's01_active']: signals.active.asStat('Active'),
    [prefix + 's02_failed']: signals.failed.asStat('Failed')
                             + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]),
    [prefix + 's03_inactive']: signals.inactive.asStat('Inactive'),
    [prefix + 's04_hosts']: signals.hosts.asStat('Hosts'),
  },
  wide: {
    [prefix + 's11_state']: panel.base('state-timeline', 'Unit state')
                            + panel.withDescription(signals.state._description)
                            + panel.withTargets([signals.state.asTarget()])
                            + panel.withOptions({ legend: { showLegend: false }, rowHeight: 0.85 })
                            + panel.withFieldConfigDefaults({ custom: { fillOpacity: 72, lineWidth: 0 } })
                            + panel.withMappings(unitMappings),
  },
  charts: {
    [prefix + 's21_restarts']: signals.restarts.asTimeSeries('Unit restarts'),
    [prefix + 's22_failedTable']: signals.failedTable.asTable('Failed units'),
  },
};

{
  // for embedding: unit element maps for a host selector and unit regex.
  units(datasource, selector, unit, prefix='')::
    unitElements(unitSignals(datasource, selector, unit), prefix),

  new(config={}):
    local cfg = {
      uid: 'observ-viz-systemd',
      dashboardTitle: 'systemd units',
      dashboardTags: ['systemd', 'linux', 'node-level'],
      description: 'systemd units from node_exporter: unit state over time, active and failed counts, failed units, restarts and the overall system state.',
      datasource: '${datasource}',
      selector: 'cluster=~"$cluster", instance=~"$instance"',
      varMetric: 'node_systemd_unit_state',
      varLabels: ['cluster', 'instance'],
      // unit-name regex shown; the collector-side allowlist decides what is exported.
      unit: '.*',
      ruleSelector: '',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-system',
      folderTitle: 'System',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend='{{instance}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local u = unitSignals(cfg.datasource, cfg.selector, cfg.unit);
    local sys = {
      running: sig('System running', 'node_systemd_system_running{%(queriesSelector)s}', 'short', desc='1 when systemd reports the system as running, 0 when degraded (a unit failed at boot or since).'),
      unitsByState: sig('Units by state', 'sum by (state) (node_systemd_units{%(queriesSelector)s})', 'short', '{{state}}', desc='Loaded units by state, all units on the host (not just the selected regex).'),
    };
    local els = unitElements(u);

    pack.build(cfg, u + sys, [
      { title: 'Overview', width: 4, height: 4, elements: els.stats {
        s05_system: sys.running.asStat('System state')
                    + panel.stat.withMappings([{ type: 'value', options: { '0': { text: 'degraded', color: 'red', index: 0 }, '1': { text: 'running', color: 'green', index: 1 } } }]),
      } },
      { title: 'Units', width: 24, height: 8, elements: els.wide },
      { title: 'Detail', width: 12, height: 7, elements: els.charts {
        s23_byState: sys.unitsByState.asTimeSeries('Units by state'),
      } },
      // what the units use, next to what they are doing
      { title: 'Resources', width: 12, height: 7, elements: {
        s31_tasks: u.tasks.asTimeSeries('Tasks')
                   + panel.withTargetsMixin([u.tasksMax.asTarget()]),
        s32_tasksUtil: u.tasksUtil.asTimeSeries('Task usage'),
        s33_uptime: u.uptime.asTimeSeries('Uptime'),
        s34_restarts: u.restarts.asTimeSeries('Unit restarts'),
      } },
    ], [
      alert.rule.group('systemd', [
        alert.rule.new(
          'SystemdUnitFailed',
          'node_systemd_unit_state{state="failed"' + rsComma + '} == 1',
          '5m',
          'critical',
          {},
          { summary: 'systemd unit {{ $labels.name }} on {{ $labels.instance }} is failed.' }
        ),
        alert.rule.new(
          'SystemdUnitRestarting',
          'increase(node_systemd_service_restart_total' + rsBrace + '[15m]) > 2',
          '0m',
          'warning',
          {},
          { summary: 'systemd unit {{ $labels.name }} on {{ $labels.instance }} restarted more than twice in 15 minutes.' }
        ),
        alert.rule.new(
          'SystemdSystemDegraded',
          'node_systemd_system_running' + rsBrace + ' == 0',
          '15m',
          'warning',
          {},
          { summary: 'systemd on {{ $labels.instance }} reports the system as degraded.' }
        ),
      ]),
    ], [
      alert.rule.group('systemd.rules', [
        alert.rule.record('instance:node_systemd_units_failed:count', 'count by (instance) (node_systemd_unit_state{state="failed"' + rsComma + '} == 1)'),
        alert.rule.record('instance:node_systemd_units_active:count', 'count by (instance) (node_systemd_unit_state{state="active"' + rsComma + '} == 1)'),
      ]),
    ]),
}
