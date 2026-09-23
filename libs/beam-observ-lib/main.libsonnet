// observ-viz BEAM (Erlang / Elixir) runtime pack (hand-written).
// Built from prometheus.erl's VM collectors (erlang_vm_*), which Elixir's
// prometheus_ex and the Phoenix stacks expose as well. The limits are the
// thing to watch on the BEAM: processes, ports and atoms all have ceilings a
// node dies against, and the run queues show scheduler backlog.
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local processLib = import 'libs/process-observ-lib/main.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-beam',
      dashboardTitle: 'BEAM runtime',
      dashboardTags: ['beam', 'erlang', 'elixir', 'runtime'],
      description: 'The BEAM virtual machine behind an Erlang or Elixir service: memory by kind, processes, ports and atoms against their limits, run queues, reductions, context switches, garbage collection and VM network traffic.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'erlang_vm_processes',
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
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      memory: sig('VM memory', 'erlang_vm_memory_bytes_total{%(queriesSelector)s}', 'bytes', '{{instance}} {{kind}}', desc='Memory the VM holds, split into processes and system.'),
      memProcesses: sig('Process memory', 'erlang_vm_memory_processes_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} {{usage}}', desc='Memory held by BEAM processes.'),
      memSystem: sig('System memory', 'erlang_vm_memory_system_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} {{usage}}', desc='Memory held by the VM itself: atoms, binaries, code and ETS.'),
      memAtom: sig('Atom memory', 'erlang_vm_memory_atom_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} {{usage}}', desc='Memory in the atom table. Atoms are never collected, so this only grows.'),
      memEts: sig('ETS memory', 'erlang_vm_memory_ets_tables{%(queriesSelector)s}', 'bytes', desc='Memory held by ETS tables.'),
      processes: sig('Processes', 'erlang_vm_processes{%(queriesSelector)s}', 'short', desc='Live BEAM processes.'),
      processLimit: sig('Process limit', 'erlang_vm_process_limit{%(queriesSelector)s}', 'short', desc='Ceiling on BEAM processes. Reaching it takes the node down.'),
      processUtil: sig('Process usage', '100 * erlang_vm_processes{%(queriesSelector)s} / clamp_min(erlang_vm_process_limit{%(queriesSelector)s}, 1)', 'percent', desc='Live processes against the limit.'),
      ports: sig('Ports', 'erlang_vm_ports{%(queriesSelector)s}', 'short', desc='Open ports: sockets, files and drivers.'),
      portLimit: sig('Port limit', 'erlang_vm_port_limit{%(queriesSelector)s}', 'short', desc='Ceiling on open ports.'),
      portUtil: sig('Port usage', '100 * erlang_vm_ports{%(queriesSelector)s} / clamp_min(erlang_vm_port_limit{%(queriesSelector)s}, 1)', 'percent', desc='Open ports against the limit.'),
      atoms: sig('Atoms', 'erlang_vm_atoms{%(queriesSelector)s}', 'short', desc='Atoms in the table.'),
      atomLimit: sig('Atom limit', 'erlang_vm_atom_limit{%(queriesSelector)s}', 'short', desc='Ceiling on atoms. Dynamic atom creation exhausts this and kills the node.'),
      atomUtil: sig('Atom usage', '100 * erlang_vm_atoms{%(queriesSelector)s} / clamp_min(erlang_vm_atom_limit{%(queriesSelector)s}, 1)', 'percent', desc='Atoms against the limit.'),
      etsTables: sig('ETS tables', 'erlang_vm_ets_tables{%(queriesSelector)s}', 'short', desc='ETS tables in use.'),
      schedulers: sig('Schedulers', 'erlang_vm_logical_processors_online{%(queriesSelector)s}', 'short', desc='Logical processors the VM schedules on.'),
      runQueueDirtyCpu: sig('Dirty CPU run queue', 'erlang_vm_statistics_dirty_cpu_run_queue_length{%(queriesSelector)s}', 'short', desc='Work waiting on the dirty CPU schedulers, where long-running native calls go.'),
      runQueueDirtyIo: sig('Dirty IO run queue', 'erlang_vm_statistics_dirty_io_run_queue_length{%(queriesSelector)s}', 'short', desc='Work waiting on the dirty IO schedulers.'),
      reductions: sig('Reductions', 'rate(erlang_vm_statistics_reductions_total{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Reductions per second, the BEAM measure of work done.'),
      contextSwitches: sig('Context switches', 'rate(erlang_vm_statistics_context_switches{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Process context switches per second.'),
      gcs: sig('Garbage collections', 'rate(erlang_vm_statistics_garbage_collection_number_of_gcs{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Collections per second across processes.'),
      gcReclaimed: sig('GC bytes reclaimed', 'rate(erlang_vm_statistics_garbage_collection_bytes_reclaimed{%(queriesSelector)s}[$__rate_interval])', 'Bps', desc='Memory the collector frees per second.'),
      bytesIn: sig('VM bytes received', 'rate(erlang_vm_statistics_bytes_received_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', desc='Traffic the VM read from ports.'),
      bytesOut: sig('VM bytes sent', 'rate(erlang_vm_statistics_bytes_output_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', desc='Traffic the VM wrote to ports.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_processes: signals.processes.asStat('Processes'),
          ov2_processUtil: signals.processUtil.asStat('Process usage'),
          ov3_portUtil: signals.portUtil.asStat('Port usage'),
          ov4_atomUtil: signals.atomUtil.asStat('Atom usage'),
          ov5_ets: signals.etsTables.asStat('ETS tables'),
          ov6_schedulers: signals.schedulers.asStat('Schedulers'),
        },
      } + stats,
      {
        title: 'Memory',
        elements: {
          memory: signals.memory.asTimeSeries('VM memory'),
          memProcesses: signals.memProcesses.asTimeSeries('Process memory'),
          memSystem: signals.memSystem.asTimeSeries('System memory'),
          memAtom: signals.memAtom.asTimeSeries('Atom memory'),
        },
      } + charts,
      {
        title: 'Limits',
        elements: {
          processes: signals.processes.asTimeSeries('Processes')
                     + panel.withTargetsMixin([signals.processLimit.asTarget()]),
          ports: signals.ports.asTimeSeries('Ports')
                 + panel.withTargetsMixin([signals.portLimit.asTarget()]),
          atoms: signals.atoms.asTimeSeries('Atoms')
                 + panel.withTargetsMixin([signals.atomLimit.asTarget()]),
          etsTables: signals.etsTables.asTimeSeries('ETS tables'),
        },
      } + charts,
      {
        title: 'Schedulers and work',
        elements: {
          runQueues: signals.runQueueDirtyCpu.asTimeSeries('Run queues')
                     + panel.withTargetsMixin([signals.runQueueDirtyIo.asTarget()]),
          reductions: signals.reductions.asTimeSeries('Reductions/s'),
          contextSwitches: signals.contextSwitches.asTimeSeries('Context switches/s'),
          gcs: signals.gcs.asTimeSeries('Garbage collections/s')
               + panel.withTargetsMixin([signals.gcReclaimed.asTarget()]),
          traffic: signals.bytesIn.asTimeSeries('VM port traffic')
                   + panel.withTargetsMixin([signals.bytesOut.asTarget()]),
        },
      } + charts,
    ], [
      alert.rule.group('beam', [
        alert.rule.new('BeamProcessLimitNear',
                       '100 * erlang_vm_processes' + rsBrace + ' / clamp_min(erlang_vm_process_limit' + rsBrace + ', 1) > 80', '10m', 'warning', {},
                       { summary: 'The BEAM on {{ $labels.instance }} is using over 80 percent of its process limit.' }),
        alert.rule.new('BeamPortLimitNear',
                       '100 * erlang_vm_ports' + rsBrace + ' / clamp_min(erlang_vm_port_limit' + rsBrace + ', 1) > 80', '10m', 'warning', {},
                       { summary: 'The BEAM on {{ $labels.instance }} is using over 80 percent of its port limit.' }),
        alert.rule.new('BeamAtomLimitNear',
                       '100 * erlang_vm_atoms' + rsBrace + ' / clamp_min(erlang_vm_atom_limit' + rsBrace + ', 1) > 80', '30m', 'critical', {},
                       { summary: 'The BEAM on {{ $labels.instance }} is using over 80 percent of its atom limit; atoms are never freed.' }),
        alert.rule.new('BeamRunQueueBacklog',
                       'erlang_vm_statistics_dirty_cpu_run_queue_length' + rsBrace + ' > 10', '10m', 'warning', {},
                       { summary: 'Work is backing up on the dirty CPU schedulers of {{ $labels.instance }}.' }),
      ]),
    ], [
      alert.rule.group('beam.rules', [
        alert.rule.record('instance:erlang_vm_process_usage:ratio',
                          'erlang_vm_processes' + rsBrace + ' / clamp_min(erlang_vm_process_limit' + rsBrace + ', 1)'),
        alert.rule.record('instance:erlang_vm_memory_bytes:sum',
                          'sum by (instance, job) (erlang_vm_memory_bytes_total' + rsBrace + ')'),
      ]),
    ], [
      {
        title: 'Process',
        width: 12,
        height: 7,
        alwaysShow: true,
        elements: processLib.elements(cfg.datasource, cfg.selector, 'proc_'),
      },
    ]),
}
