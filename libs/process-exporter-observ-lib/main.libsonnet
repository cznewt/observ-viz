// observ-viz process-exporter pack (hand-written).
// Process groups from process-exporter (namedprocess_namegroup_*): CPU,
// memory, processes and threads, file descriptors, IO and page faults per
// group and host, plus top-N tables and scrape health.
//   g.libs.system.processExporter.new({}).grafana.dashboard
//   g.libs.system.processExporter.group(ds, 'instance=~"$host"', 'alloy')
//     -> { stats: {..}, charts: {..} } element maps for embedding in a service board
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

// signals for a host selector and a groupname regex.
local groupSignals(datasource, selector, group) = {
  local g = 'groupname=~"' + group + '", ',
  local sig(name, expr, unit, legend='{{instance}} {{groupname}}', desc='') =
    signal.new(name, 'prometheus', datasource, expr, unit).filteringSelector(selector).withLegendFormat(legend).withDescription(desc),
  cpu: sig('Process CPU', 'sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total{' + g + '%(queriesSelector)s}[$__rate_interval]))', 'short', desc='CPU cores used by the process group (all its processes summed).'),
  rss: sig('Process RSS', 'sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{' + g + 'memtype="resident", %(queriesSelector)s})', 'bytes', desc='Resident memory of the process group.'),
  procs: sig('Processes', 'sum by (instance, groupname) (namedprocess_namegroup_num_procs{' + g + '%(queriesSelector)s})', 'short', desc='Processes in the group. More than expected usually means forks or workers piling up.'),
  threads: sig('Threads', 'sum by (instance, groupname) (namedprocess_namegroup_num_threads{' + g + '%(queriesSelector)s})', 'short', desc='Threads across the process group.'),
  fds: sig('Open file descriptors', 'sum by (instance, groupname) (namedprocess_namegroup_open_filedesc{' + g + '%(queriesSelector)s})', 'short', desc='Open file descriptors across the process group.'),
  fdRatio: sig('Worst FD ratio', 'max by (instance, groupname) (namedprocess_namegroup_worst_fd_ratio{' + g + '%(queriesSelector)s})', 'percentunit', desc='Open descriptors of the worst process divided by its soft limit. Near 1 the process starts failing with too many open files.'),
  uptime: sig('Process uptime', 'time() - min by (instance, groupname) (namedprocess_namegroup_oldest_start_time_seconds{' + g + '%(queriesSelector)s})', 'dtdurations', desc='Time since the oldest process of the group started.'),
  ioRead: sig('Process read', 'sum by (instance, groupname) (rate(namedprocess_namegroup_read_bytes_total{' + g + '%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} {{groupname}} read', desc='Bytes read from storage by the process group per second, with writes alongside.'),
  ioWrite: sig('Process write', 'sum by (instance, groupname) (rate(namedprocess_namegroup_write_bytes_total{' + g + '%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} {{groupname}} write', desc='Bytes written to storage by the process group per second.'),
  majFaults: sig('Major page faults', 'sum by (instance, groupname) (rate(namedprocess_namegroup_major_page_faults_total{' + g + '%(queriesSelector)s}[$__rate_interval]))', 'short', desc='Major page faults per second: the process is reading pages back from disk, a sign of memory pressure.'),
  ctxSwitches: sig('Context switches', 'sum by (instance, groupname, ctxswitchtype) (rate(namedprocess_namegroup_context_switches_total{' + g + '%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{instance}} {{groupname}} {{ctxswitchtype}}', desc='Voluntary and non-voluntary context switches per second. Many non-voluntary switches mean CPU contention.'),
  states: sig('Process states', 'sum by (instance, groupname, state) (namedprocess_namegroup_states{' + g + '%(queriesSelector)s})', 'short', '{{instance}} {{groupname}} {{state}}', desc='Processes of the group by kernel state (Running, Sleeping, Waiting, Zombie, Other).'),
};

local groupElements(signals, prefix='') = {
  signals:: signals,
  stats: {
    [prefix + 'h01_procs']: signals.procs.asStat('Processes'),
    [prefix + 'h02_threads']: signals.threads.asStat('Threads'),
    [prefix + 'h03_fds']: signals.fds.asStat('Open file descriptors'),
    [prefix + 'h04_fdRatio']: signals.fdRatio.asStat('Worst FD ratio')
                              + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.6 }, { color: 'red', value: 0.8 }]),
    [prefix + 'h05_uptime']: signals.uptime.asStat('Uptime'),
  },
  charts: {
    [prefix + 'h11_cpu']: signals.cpu.asTimeSeries('CPU (cores)'),
    [prefix + 'h12_rss']: signals.rss.asTimeSeries('Resident memory'),
    [prefix + 'h13_io']: signals.ioRead.asTimeSeries('Disk read / write')
                         + panel.withTargetsMixin([signals.ioWrite.asTarget()]),
    [prefix + 'h14_majFaults']: signals.majFaults.asTimeSeries('Major page faults/s'),
    [prefix + 'h15_ctx']: signals.ctxSwitches.asTimeSeries('Context switches/s'),
    [prefix + 'h16_states']: signals.states.asTimeSeries('Process states'),
  },
};

{
  // for embedding: element maps for a host selector and groupname regex.
  group(datasource, selector, group, prefix='')::
    groupElements(groupSignals(datasource, selector, group), prefix),

  new(config={}):
    local cfg = {
      uid: 'observ-viz-process-exporter',
      dashboardTitle: 'Process groups',
      dashboardTags: ['process-exporter', 'linux', 'node-level'],
      description: 'Process groups from process-exporter: CPU, memory, processes and threads, file descriptors, IO and page faults per group and host, top-N tables and scrape health.',
      datasource: '${datasource}',
      selector: 'cluster=~"$cluster", instance=~"$instance", groupname=~"$groupname"',
      varMetric: 'namedprocess_namegroup_num_procs',
      varLabels: ['cluster', 'instance', 'groupname'],
      group: '.*',
      ruleSelector: '',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table
      overviewSignals: ['procs', 'cpu', 'rss', 'fds', 'threads'],
      folderUid: 'components-system',
      folderTitle: 'System',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local hostSel = 'cluster=~"$cluster", instance=~"$instance"';
    local hsig(name, expr, unit, legend='{{instance}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(hostSel).withLegendFormat(legend).withDescription(desc);
    local g = groupSignals(cfg.datasource, cfg.selector, cfg.group);
    local host = {
      topCpu: hsig('Top CPU groups', 'topk(10, sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])))', 'short', '{{instance}} {{groupname}}', desc='The ten process groups using the most CPU on the selected hosts.'),
      topRss: hsig('Top memory groups', 'topk(10, sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{memtype="resident", %(queriesSelector)s}))', 'bytes', '{{instance}} {{groupname}}', desc='The ten process groups using the most resident memory on the selected hosts.'),
      scrapeErrors: hsig('Scrape errors', 'sum by (instance) (rate(namedprocess_scrape_errors{%(queriesSelector)s}[$__rate_interval]) + rate(namedprocess_scrape_partial_errors{%(queriesSelector)s}[$__rate_interval]) + rate(namedprocess_scrape_procread_errors{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='process-exporter scrape errors per second (full, partial and /proc read errors). Usually permissions on /proc.'),
    };
    local els = groupElements(g);

    pack.build(cfg, g + host, [
      { title: 'Overview', width: 4, height: 4, elements: els.stats },
      { title: 'Usage', width: 12, height: 7, elements: els.charts },
      { title: 'Hosts', width: 12, height: 7, elements: {
        t01_topCpu: host.topCpu.asTimeSeries('Top CPU groups'),
        t02_topRss: host.topRss.asTimeSeries('Top memory groups'),
        t03_scrapeErrors: host.scrapeErrors.asTimeSeries('Scrape errors/s'),
      } },
    ], [
      alert.rule.group('process-exporter', [
        alert.rule.new(
          'ProcessGroupFdRatioHigh',
          'namedprocess_namegroup_worst_fd_ratio' + rsBrace + ' > 0.8',
          '15m',
          'warning',
          {},
          { summary: 'Process group {{ $labels.groupname }} on {{ $labels.instance }} has a process at more than 80% of its file descriptor limit.' }
        ),
        alert.rule.new(
          'ProcessGroupGone',
          'namedprocess_namegroup_num_procs' + rsBrace + ' == 0',
          '10m',
          'warning',
          {},
          { summary: 'Process group {{ $labels.groupname }} on {{ $labels.instance }} has no running process.' }
        ),
        alert.rule.new(
          'ProcessExporterScrapeErrors',
          'rate(namedprocess_scrape_errors' + rsBrace + '[5m]) > 0',
          '15m',
          'warning',
          {},
          { summary: 'process-exporter on {{ $labels.instance }} is failing to read process information.' }
        ),
      ]),
    ], [
      alert.rule.group('process-exporter.rules', [
        alert.rule.record('instance_groupname:namedprocess_cpu:rate5m', 'sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total' + rsBrace + '[5m]))'),
        alert.rule.record('instance_groupname:namedprocess_rss:sum', 'sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{memtype="resident"' + rsComma + '})'),
      ]),
    ]),
}
