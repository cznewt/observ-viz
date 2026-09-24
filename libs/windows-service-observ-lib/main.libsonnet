// observ-viz Windows service pack (hand-written).
// Windows services from the windows_exporter `service` collector, the Windows
// counterpart of the systemd board: what each service is doing, how many are
// running or stopped, and - the one that matters - services set to start
// automatically that are not running.
//   g.libs.system.windowsService.new({}).grafana.dashboard
//   g.libs.system.windowsService.services(ds, 'instance=~"$instance"', 'Alloy')
//     -> element maps for embedding in a service board
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

// windows_service_state carries one series per state with a 0/1 value, so a
// single number per service comes from folding the states into one scale.
local stateMappings = [{ type: 'value', options: {
  '1': { text: 'running', color: 'green', index: 0 },
  '2': { text: 'pending', color: 'yellow', index: 1 },
  '3': { text: 'paused', color: 'orange', index: 2 },
  '4': { text: 'stopped', color: 'red', index: 3 },
} }];

local serviceSignals(datasource, selector, name) = {
  local n = 'name=~"' + name + '", ',
  local sig(sname, expr, unit, legend='{{instance}}', desc='') =
    signal.new(sname, 'prometheus', datasource, expr, unit).filteringSelector(selector).withLegendFormat(legend).withDescription(desc),
  state: sig(
    'Service state',
    'max by (instance, name) ((windows_service_state{' + n + 'state="running", %(queriesSelector)s} == 1) * 1'
    + ' or (windows_service_state{' + n + 'state=~"start pending|continue pending", %(queriesSelector)s} == 1) * 2'
    + ' or (windows_service_state{' + n + 'state=~"paused|pause pending|stop pending", %(queriesSelector)s} == 1) * 3'
    + ' or (windows_service_state{' + n + 'state="stopped", %(queriesSelector)s} == 1) * 4)',
    'short', '{{instance}} {{name}}',
    'State of each service on each host: running, pending, paused or stopped.'
  ),
  running: sig('Running services', 'count(windows_service_state{' + n + 'state="running", %(queriesSelector)s} == 1) or vector(0)', 'short', 'running', 'Services currently running.'),
  stopped: sig('Stopped services', 'count(windows_service_state{' + n + 'state="stopped", %(queriesSelector)s} == 1) or vector(0)', 'short', 'stopped', 'Services currently stopped, whatever their start mode.'),
  // the Windows equivalent of a failed unit: set to start on boot, not running
  autoStopped: sig(
    'Automatic but stopped',
    'count((windows_service_state{' + n + 'state="stopped", %(queriesSelector)s} == 1)'
    + ' and on (instance, name) (windows_service_start_mode{' + n + 'start_mode="auto", %(queriesSelector)s} == 1)) or vector(0)',
    'short', 'auto but stopped',
    'Services Windows is supposed to start at boot that are not running. This is the number to watch.'
  ),
  autoStoppedTable: sig(
    'Automatic but stopped',
    '(windows_service_state{' + n + 'state="stopped", %(queriesSelector)s} == 1)'
    + ' and on (instance, name) (windows_service_start_mode{' + n + 'start_mode="auto", %(queriesSelector)s} == 1)',
    'short', '{{instance}} {{name}}',
    'Which ones, by host.'
  ),
  hosts: sig('Hosts', 'count(count by (instance) (windows_service_state{' + n + '%(queriesSelector)s}))', 'short', 'hosts', 'Hosts exporting a matching service at all.'),
  byStartMode: sig('Services by start mode', 'sum by (start_mode) (windows_service_start_mode{' + n + '%(queriesSelector)s} == 1)', 'short', '{{start_mode}}', 'How services are set to start: automatic, manual or disabled.'),
  byState: sig('Services by state', 'sum by (state) (windows_service_state{' + n + '%(queriesSelector)s} == 1)', 'short', '{{state}}', 'Services by the state they are in.'),
};

{
  // for embedding: element maps for a host selector and a service-name regex
  services(datasource, selector, name, prefix='')::
    local s = serviceSignals(datasource, selector, name);
    {
      signals:: s,
      stats: {
        [prefix + 's01_running']: s.running.asStat('Running'),
        [prefix + 's02_stopped']: s.stopped.asStat('Stopped'),
        [prefix + 's03_auto']: s.autoStopped.asStat('Automatic but stopped')
                               + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]),
      },
      wide: {
        [prefix + 's11_state']: s.state.asTimeSeries('Service state')
                                + panel.timeSeries.withMappings(stateMappings),
        [prefix + 's12_auto']: s.autoStoppedTable.asTable('Automatic but stopped'),
      },
    },

  new(config={}):
    local cfg = {
      uid: 'observ-viz-windows-service',
      dashboardTitle: 'Windows service',
      dashboardTags: ['windows', 'service', 'node-level'],
      description: 'Windows services from the windows_exporter service collector: what each one is doing, how many run, and the ones set to start automatically that are stopped.',
      datasource: '${datasource}',
      selector: 'instance=~"$instance"',
      varMetric: 'windows_service_state',
      varLabels: ['instance'],
      // service-name regex shown; the collector's own allowlist decides what
      // is exported in the first place
      service: '.*',
      ruleSelector: '',
      docTabs: true,
      tabbed: true,
      overviewSignals: ['running', 'stopped', 'autoStopped', 'hosts'],
    } + config;
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local s = serviceSignals(cfg.datasource, cfg.selector, cfg.service);
    local els = $.services(cfg.datasource, cfg.selector, cfg.service);

    pack.build(cfg, s, [
      { title: 'Overview', width: 4, height: 4, elements: els.stats {
        s04_hosts: s.hosts.asStat('Hosts'),
      } },
      { title: 'Services', width: 24, height: 8, elements: els.wide },
      { title: 'Detail', width: 12, height: 7, elements: {
        s21_byState: s.byState.asTimeSeries('Services by state'),
        s22_byStartMode: s.byStartMode.asTimeSeries('Services by start mode'),
      } },
    ], [
      alert.rule.group('windows-service', [
        alert.rule.new(
          'WindowsServiceAutoStopped',
          '(windows_service_state{state="stopped"' + rsComma + '} == 1) and on (instance, name) (windows_service_start_mode{start_mode="auto"' + rsComma + '} == 1)',
          '10m',
          'critical',
          {},
          {
            summary: 'Windows service {{ $labels.name }} on {{ $labels.instance }} is set to start automatically but is stopped.',
            description: 'Either it failed and did not recover, or someone stopped it by hand and Windows will start it again only at the next boot. Check the service recovery settings and the event log around the time it stopped.',
          }
        ),
        alert.rule.new(
          'WindowsServicePending',
          '(windows_service_state{state=~"start pending|stop pending|continue pending|pause pending"' + rsComma + '} == 1)',
          '15m',
          'warning',
          {},
          {
            summary: 'Windows service {{ $labels.name }} on {{ $labels.instance }} has been mid-transition for 15 minutes.',
            description: 'A service stuck in a pending state is usually one waiting on something that will not arrive: a dependency, a network share, a driver.',
          }
        ),
      ]),
    ]),
}
