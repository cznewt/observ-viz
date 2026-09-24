// observ-viz base process pack (hand-written).
// The metrics every Prometheus client library exposes for its own process
// (process_* from the Go, Python, Java, Ruby, Rust, PHP and C++ clients) plus
// the scrape's own health. It is the base layer under every runtime pack: a
// language without runtime metrics of its own (Rust, C, C++) is still covered
// here, and every other runtime pack embeds these elements.
//   g.libs.runtimes.process.new({ selector: 'job="api"' }).grafana.dashboard
//   g.libs.runtimes.process.new({...}).grafana.elements   // reuse in a board
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  // elements(datasource, selector, prefix) -> the element map on its own, for
  // embedding these rows in a service or host board under a prefix.
  elements(datasource, selector, prefix='')::
    local p = $.new({ datasource: datasource, selector: selector, docTabs: false });
    { [prefix + k]: p.grafana.elements[k] for k in std.objectFields(p.grafana.elements) },

  new(config={}):
    local cfg = {
      uid: 'observ-viz-process',
      dashboardTitle: 'Process (base instrumentation)',
      dashboardTags: ['process', 'runtime', 'base'],
      description: 'The base instrumentation every Prometheus client library exposes about its own process: CPU, memory, file descriptors, threads, uptime and restarts, next to the health of the scrape itself. Any language is covered here, whether or not it also has a runtime pack.',
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal (process_*, go_*) cannot reach another component's
      // instances where the job label does not discriminate them
      selector: 'job=~"$job", instance=~"$instance"',
      varLabels: ['instance'],
      varMetric: 'process_start_time_seconds',
      ruleSelector: '',
      legend: '{{instance}}',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-runtimes',
      folderTitle: 'Runtimes',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      up: sig('Targets up', 'sum(up{%(queriesSelector)s})', 'short', 'up', desc='Targets answering their scrape.'),
      down: sig('Targets down', 'sum(up{%(queriesSelector)s} == 0) or vector(0)', 'short', 'down', desc='Targets that failed their last scrape.'),
      cpu: sig('CPU', 'rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='CPU cores the process burns. Compare with its CPU limit, not with the node.'),
      rss: sig('Resident memory', 'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes', desc='Memory actually held in RAM. This is what an out-of-memory kill looks at.'),
      vsz: sig('Virtual memory', 'process_virtual_memory_bytes{%(queriesSelector)s}', 'bytes', desc='Address space the process has mapped. Usually far larger than resident memory and rarely a problem on its own.'),
      openFds: sig('Open file descriptors', 'process_open_fds{%(queriesSelector)s}', 'short', desc='Open files and sockets. A leak here ends in "too many open files".'),
      maxFds: sig('File descriptor limit', 'process_max_fds{%(queriesSelector)s}', 'short', desc='The process ulimit for open files.'),
      fdUtil: sig('File descriptor usage', '100 * process_open_fds{%(queriesSelector)s} / process_max_fds{%(queriesSelector)s}', 'percent', desc='Open descriptors against the limit.'),
      threads: sig('Threads', 'process_threads{%(queriesSelector)s}', 'short', desc='OS threads the process runs. Absent from some client libraries.'),
      uptime: sig('Uptime', 'time() - process_start_time_seconds{%(queriesSelector)s}', 's', desc='Time since the process started. A drop to zero is a restart.'),
      restarts1h: sig('Restarts (1h)', 'sum(changes(process_start_time_seconds{%(queriesSelector)s}[1h])) or vector(0)', 'short', 'restarts', desc='Process starts in the last hour, counted from the start time moving.'),
      scrapeDuration: sig('Scrape duration', 'scrape_duration_seconds{%(queriesSelector)s}', 's', desc='How long the target takes to answer. Approaching the scrape interval means missed samples.'),
      scrapeSamples: sig('Scraped samples', 'scrape_samples_scraped{%(queriesSelector)s}', 'short', desc='Series the target returns per scrape. A jump is new cardinality.'),
      targetTable: sig('Targets', 'max by (job, instance) (up{%(queriesSelector)s})', 'short', '{{instance}}', desc='Every target with its current scrape state.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_up: signals.up.asStat('Targets up'),
          ov2_down: signals.down.asStat('Targets down') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]),
          ov3_restarts: signals.restarts1h.asStat('Restarts (1h)') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 1 }]),
          ov4_cpu: signals.cpu.asStat('CPU (cores)'),
          ov5_rss: signals.rss.asStat('Resident memory'),
          ov6_fd: signals.fdUtil.asStat('File descriptor usage'),
        },
      } + stats,
      {
        title: 'Process',
        elements: {
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          rss: signals.rss.asTimeSeries('Resident memory')
               + panel.withTargetsMixin([signals.vsz.asTarget()]),
          threads: signals.threads.asTimeSeries('Threads'),
          uptime: signals.uptime.asTimeSeries('Uptime'),
        },
      } + charts,
      {
        title: 'File descriptors',
        elements: {
          openFds: signals.openFds.asTimeSeries('Open file descriptors')
                   + panel.withTargetsMixin([signals.maxFds.asTarget()]),
          fdUtil: signals.fdUtil.asTimeSeries('File descriptor usage'),
        },
      } + charts,
      {
        title: 'Scrape',
        elements: {
          scrapeDuration: signals.scrapeDuration.asTimeSeries('Scrape duration'),
          scrapeSamples: signals.scrapeSamples.asTimeSeries('Scraped samples'),
          targetTable: signals.targetTable.asTable('Targets'),
        },
      } + charts,
    ], [
      alert.rule.group('process', [
        alert.rule.new('ProcessDown', alert.rule.targetDown('process_start_time_seconds', cfg.ruleSelector), '5m', 'critical', {},
                       { summary: 'Target {{ $labels.instance }} ({{ $labels.job }}) stopped answering its scrape.' }),
        alert.rule.new('ProcessRestartLoop', 'changes(process_start_time_seconds' + rsBrace + '[15m]) > 2', '5m', 'warning', {},
                       { summary: 'Process {{ $labels.instance }} restarted more than twice in 15 minutes.' }),
        alert.rule.new('ProcessFileDescriptorsNearLimit',
                       'process_open_fds' + rsBrace + ' / process_max_fds' + rsBrace + ' > 0.8', '10m', 'warning', {},
                       { summary: 'Process {{ $labels.instance }} holds over 80 percent of its file descriptor limit.' }),
        alert.rule.new('ScrapeSlow', 'scrape_duration_seconds' + rsBrace + ' > 10', '15m', 'info', {},
                       { summary: 'Target {{ $labels.instance }} takes more than 10 seconds to answer a scrape.' }),
      ]),
    ], [
      alert.rule.group('process.rules', [
        alert.rule.record('job_instance:process_cpu_seconds:rate5m', 'rate(process_cpu_seconds_total' + rsBrace + '[5m])'),
        alert.rule.record('job:process_resident_memory_bytes:sum', 'sum by (job) (process_resident_memory_bytes' + rsBrace + ')'),
      ]),
    ]),
}
