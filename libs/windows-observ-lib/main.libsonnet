// observ-viz Windows host pack (hand-written).
// windows_exporter host observability laid out as tabs: System (uptime/CPU/memory/
// disk/network), Applications (processes + Windows service states), and Logs
// (Windows event log via Loki). Plus windows_exporter alerting/recording rules.
// Emitted as native v2 elements. Usage:
//   g.libs.system.windows.new({ selector: 'job="windows"' }).grafana.dashboard
//   g.libs.system.windows.new({...}).grafana.elements   // reuse in a board
// Per-node board (cluster -> instance cascading selection), mirroring system.linux,
// so the Cluster Overview Servers table can drill straight to a single host.
// Two boards (see .grafana.dashboards):
//   <uid>        Windows Server         — the per-host board described above
//   <fleetUid>   Windows Fleet Overview — every host at once, drills into the above
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'compute-windows-overview',
      // back-link to the fleet view, keeping the selected cluster (node filter
      // reset to All so the whole cluster shows).
      links: [{
        title: 'Cluster Detail',
        type: 'link',
        icon: 'dashboard',
        url: '/d/cluster-detail?var-cluster=${cluster}&var-instance=$__all',
        keepTime: true,
        targetBlank: false,
        asDropdown: false,
        includeVars: false,
        tooltip: 'Open the cluster overview for the selected cluster',
        tags: [],
      }],
      dashboardTitle: 'Windows Server',
      dashboardTags: ['windows'],
      // fleet board: every Windows host in the selected cluster(s) at once.
      fleetUid: 'compute-windows-fleet',
      fleetTitle: 'Windows Fleet Overview',
      // both boards land in Infrastructure / Compute, beside Linux Server (the
      // loader creates the nested folders). Shared by cfg + fleetCfg.
      folderUid: 'observ-viz-compute',
      folderTitle: 'Compute',
      folderParentUid: 'observ-viz-infrastructure',
      folderParentTitle: 'Infrastructure',
      datasource: '${datasource}',
      // cluster -> instance cascading selection (vars built by pack.build), so a
      // per-node drill (e.g. from Cluster Overview) lands on a single host.
      selector: 'job=~"$job", cluster=~"$cluster", instance=~"$instance"',
      varMetric: 'windows_os_info',
      varLabels: ['cluster', 'instance'],
      varMulti: false,
      // System primary tab + Applications/Logs tabs (rendered via showIfData/presence).
      primaryTabTitle: 'System',
      lokiDatasource: true,
      // Windows event logs shipped to Loki are labelled by instance (+ channel/level).
      logsSelector: 'instance=~"$instance"',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      // Temperature alert thresholds (°C) — hardware-specific, so overridable.
      // Dormant until a temperature source emits (metric absent -> no firing).
      tempWarnC: 85,
      tempCritC: 95,
      // Sane window: sensor readings outside [tempMinC, tempMaxC] are dropped as
      // nonsense (negatives / disconnected-sensor garbage / impossible highs).
      tempMinC: 0,
      tempMaxC: 150,
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    // default legend carries the instance; per-dimension signals (disk/net/service)
    // append their volume/nic/name label.
    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);
    // Windows event log lines from Loki, scoped to the selected instance.
    local lsig(name, expr) =
      signal.new(name, 'loki', '${loki_datasource}', expr, 'short').filteringSelector(cfg.logsSelector);
    // Temperature signals filter on cluster+instance only — NOT the windows_exporter
    // $job, since OhmGraphite carries job="integrations/ohmgraphite" (a separate
    // scrape). Same host, different job label.
    local tempSelector = 'cluster=~"$cluster", instance=~"$instance"';
    local tsig(name, expr, legend='{{instance}} / {{sensor}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, 'celsius').withLegendFormat(legend);
    // Unified temperature source: whichever a host emits — OhmGraphite
    // (ohm_<hw>_celsius, labelled `sensor`) OR the windows_exporter thermalzone
    // collector (labelled `name`, relabelled to `sensor` so both share a legend).
    // `or` yields ohm where present, else thermalzone. Range-filtered to drop
    // nonsense (negatives / disconnected-sensor garbage / impossible highs).
    local tempRange = ' > ' + cfg.tempMinC + ' < ' + cfg.tempMaxC;
    local tempUnion(sel) =
      '({__name__=~"ohm_.+_celsius", ' + sel + '}'
      + ' or label_replace(windows_thermalzone_temperature_celsius{' + sel + '}, "sensor", "$1", "name", "(.+)"))';
    // rule-side union (no dashboard vars; the static ruleSelector may be empty).
    local tempUnionRule =
      '({__name__=~"ohm_.+_celsius"' + rsComma + '}'
      + ' or label_replace(windows_thermalzone_temperature_celsius' + rsBrace + ', "sensor", "$1", "name", "(.+)"))';

    // per-dimension legend helpers keep the volume/nic/mode label on multi-series signals.
    local byVol = '{{instance}} / {{volume}}';
    local byNic = '{{instance}} / {{nic}}';
    local signals = {
      // ===== CPU (collector: cpu) =====
      cpuBusy: sig('CPU utilisation', '1 - avg without (core) (rate(windows_cpu_time_total{mode="idle",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      cpuByMode: sig('CPU by mode', 'avg without (core) (rate(windows_cpu_time_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '{{instance}} / {{mode}}'),
      cpuFreq: sig('CPU frequency', 'avg without (core) (windows_cpu_core_frequency_mhz{%(queriesSelector)s}) * 1e6', 'hertz'),
      cpuInterrupts: sig('Interrupts', 'sum without (core) (rate(windows_cpu_interrupts_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{instance}} / interrupts'),
      cpuDpcs: sig('DPCs', 'sum without (core) (rate(windows_cpu_dpcs_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{instance}} / DPCs'),
      cpuCores: sig('Logical processors', 'count without (core) (windows_cpu_time_total{mode="idle",%(queriesSelector)s})', 'short'),
      cpuCState: sig('CPU C-state residency', 'avg without (core) (rate(windows_cpu_cstate_seconds_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '{{instance}} / {{state}}'),

      // ===== Memory (collector: memory; `available` ~ Linux MemAvailable) =====
      memTotal: sig('Physical memory total', 'windows_memory_physical_total_bytes{%(queriesSelector)s}', 'bytes'),
      memAvailable: sig('Physical memory available', 'windows_memory_available_bytes{%(queriesSelector)s}', 'bytes'),
      memFree: sig('Physical memory free', 'windows_memory_physical_free_bytes{%(queriesSelector)s}', 'bytes'),
      memUsed: sig('Physical memory used', 'windows_memory_physical_total_bytes{%(queriesSelector)s} - windows_memory_available_bytes{%(queriesSelector)s}', 'bytes'),
      memUsedRatio: sig('Memory used ratio', '1 - windows_memory_available_bytes{%(queriesSelector)s} / windows_memory_physical_total_bytes{%(queriesSelector)s}', 'percentunit'),
      memCommitted: sig('Committed memory', 'windows_memory_committed_bytes{%(queriesSelector)s}', 'bytes'),
      memCommitLimit: sig('Commit limit', 'windows_memory_commit_limit{%(queriesSelector)s}', 'bytes'),
      memCache: sig('Cache', 'windows_memory_cache_bytes{%(queriesSelector)s}', 'bytes'),
      memPoolPaged: sig('Paged pool', 'windows_memory_pool_paged_bytes{%(queriesSelector)s}', 'bytes'),
      memPoolNonpaged: sig('Nonpaged pool', 'windows_memory_pool_nonpaged_bytes{%(queriesSelector)s}', 'bytes'),
      memPageFaults: sig('Page faults', 'rate(windows_memory_page_faults_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      memSwapOps: sig('Swap page operations', 'rate(windows_memory_swap_page_operations_total{%(queriesSelector)s}[$__rate_interval])', 'short'),

      // ===== Disk (collector: logical_disk) =====
      diskFree: sig('Logical disk free', 'windows_logical_disk_free_bytes{%(queriesSelector)s}', 'bytes', byVol),
      diskSize: sig('Logical disk size', 'windows_logical_disk_size_bytes{%(queriesSelector)s}', 'bytes', byVol),
      diskUsedRatio: sig('Logical disk used ratio', '1 - windows_logical_disk_free_bytes{%(queriesSelector)s} / windows_logical_disk_size_bytes{%(queriesSelector)s}', 'percentunit', byVol),
      diskReadBytes: sig('Disk read', 'rate(windows_logical_disk_read_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', byVol),
      diskWriteBytes: sig('Disk write', 'rate(windows_logical_disk_write_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', byVol),
      diskReadIops: sig('Disk read IOPS', 'rate(windows_logical_disk_reads_total{%(queriesSelector)s}[$__rate_interval])', 'iops', byVol),
      diskWriteIops: sig('Disk write IOPS', 'rate(windows_logical_disk_writes_total{%(queriesSelector)s}[$__rate_interval])', 'iops', byVol),
      diskReadLatency: sig('Disk read latency', 'rate(windows_logical_disk_read_latency_seconds_total{%(queriesSelector)s}[$__rate_interval]) / rate(windows_logical_disk_reads_total{%(queriesSelector)s}[$__rate_interval])', 's', byVol),
      diskWriteLatency: sig('Disk write latency', 'rate(windows_logical_disk_write_latency_seconds_total{%(queriesSelector)s}[$__rate_interval]) / rate(windows_logical_disk_writes_total{%(queriesSelector)s}[$__rate_interval])', 's', byVol),
      diskQueue: sig('Disk queue length', 'windows_logical_disk_requests_queued{%(queriesSelector)s}', 'short', byVol),
      diskActive: sig('Disk active time', '1 - rate(windows_logical_disk_idle_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit', byVol),

      // ===== Network (collector: net) =====
      netRecv: sig('Network received', 'rate(windows_net_bytes_received_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', byNic),
      netSent: sig('Network sent', 'rate(windows_net_bytes_sent_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', byNic),
      netBandwidth: sig('Link speed', 'windows_net_current_bandwidth_bytes{%(queriesSelector)s} * 8', 'bps', byNic),
      netUtil: sig('Network utilisation', 'rate(windows_net_bytes_total{%(queriesSelector)s}[$__rate_interval]) * 8 / (windows_net_current_bandwidth_bytes{%(queriesSelector)s} * 8)', 'percentunit', byNic),
      netPacketsRecv: sig('Packets received', 'rate(windows_net_packets_received_total{%(queriesSelector)s}[$__rate_interval])', 'pps', byNic),
      netPacketsSent: sig('Packets sent', 'rate(windows_net_packets_sent_total{%(queriesSelector)s}[$__rate_interval])', 'pps', byNic),
      netErrors: sig('Network errors', 'rate(windows_net_packets_received_errors_total{%(queriesSelector)s}[$__rate_interval]) + rate(windows_net_packets_outbound_errors_total{%(queriesSelector)s}[$__rate_interval])', 'short', byNic),
      netDiscards: sig('Network discards', 'rate(windows_net_packets_received_discarded_total{%(queriesSelector)s}[$__rate_interval]) + rate(windows_net_packets_outbound_discarded_total{%(queriesSelector)s}[$__rate_interval])', 'short', byNic),
      netQueue: sig('Output queue', 'windows_net_output_queue_length_packets{%(queriesSelector)s}', 'short', byNic),

      // ===== System (collector: system) =====
      uptime: sig('Uptime', 'time() - windows_system_boot_time_timestamp{%(queriesSelector)s}', 's'),
      processes: sig('Processes', 'windows_system_processes{%(queriesSelector)s}', 'short'),
      threads: sig('Threads', 'windows_system_threads{%(queriesSelector)s}', 'short'),
      contextSwitches: sig('Context switches', 'rate(windows_system_context_switches_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      systemCalls: sig('System calls', 'rate(windows_system_system_calls_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      exceptions: sig('Exception dispatches', 'rate(windows_system_exception_dispatches_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      procQueue: sig('Processor queue length', 'windows_system_processor_queue_length{%(queriesSelector)s}', 'short'),

      // ===== OS (collector: os) =====
      osInfo: sig('OS', 'windows_os_info{%(queriesSelector)s}', 'short', '{{instance}} / {{product}}'),

      // ===== Services (collector: service) =====
      servicesRunning: sig('Running services', 'count(windows_service_state{state="running",%(queriesSelector)s} == 1)', 'short', 'running'),
      servicesStopped: sig('Stopped services', 'count(windows_service_state{state="stopped",%(queriesSelector)s} == 1)', 'short', 'stopped'),
      serviceState: sig('Service states', 'windows_service_state{%(queriesSelector)s}', 'short', '{{name}} / {{state}}'),

      // ===== Time (collector: time) — NTP sync health =====
      timeOffset: sig('Clock offset', 'windows_time_computed_time_offset_seconds{%(queriesSelector)s}', 's'),
      ntpRoundTrip: sig('NTP round-trip delay', 'windows_time_ntp_round_trip_delay_seconds{%(queriesSelector)s}', 's'),

      // ===== Scrape health (collector: exporter) =====
      scrapeDuration: sig('Scrape duration', 'windows_exporter_scrape_duration_seconds{%(queriesSelector)s}', 's'),
      collectorSuccess: sig('Collector success', 'windows_exporter_collector_success{%(queriesSelector)s}', 'short', '{{instance}} / {{collector}}'),
      collectorDuration: sig('Collector duration', 'windows_exporter_collector_duration_seconds{%(queriesSelector)s}', 's', '{{instance}} / {{collector}}'),

      // --- Temperature (source-agnostic: OhmGraphite OR windows_exporter thermalzone) ---
      // One unified signal per host — ohm_<hw>_celsius (LibreHardwareMonitor +
      // PawnIO, our fleet) or windows_thermalzone_temperature_celsius (hosts whose
      // ACPI exposes it), nonsense-filtered. Gated on data presence (showIfData),
      // so the tab stays hidden until a host emits any temperature.
      tempMax: tsig('Max temperature', 'max by (instance)(' + tempUnion(tempSelector) + tempRange + ')', '{{instance}}'),
      tempBySensor: tsig('Temperature by sensor', tempUnion(tempSelector) + tempRange),

      // --- Logs (Windows event log via Loki) ---
      winLogs: lsig('Windows event log', '{%(queriesSelector)s}'),
    };

    local main = pack.build(cfg, signals, [
      {
        // at-a-glance stats across the core collectors.
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          local query = import 'custom/query.libsonnet',
          local iq(expr) =
            query.prometheus.new(cfg.datasource, expr)
            + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } },
          local labelStat(title, expr, field) =
            panel.stat.new(title)
            + panel.stat.withTargets([iq(expr)])
            + panel.stat.withOptions({ reduceOptions: { values: true, fields: '/^' + field + '$/' }, colorMode: 'none' }),
          uptime: signals.uptime.asStat('Uptime'),
          cpu: signals.cpuBusy.asStat('CPU utilisation'),
          memRatio: signals.memUsedRatio.asStat('Memory used ratio'),
          cores: signals.cpuCores.asStat('Logical processors'),
          processes: signals.processes.asStat('Processes'),
          threads: signals.threads.asStat('Threads'),
          // generic system facts, mirroring the cluster-detail tables. CPU
          // model comes from OhmGraphite's hardware label (boxes with the
          // hardware_sensors pillar); windows_exporter has no such info.
          ovOs: labelStat('OS', 'windows_os_info{instance=~"$instance"}', 'product'),
          ovBuild: labelStat('Build', 'windows_os_info{instance=~"$instance"}', 'version'),
          ovModel: labelStat('CPU Model', 'sum by (hardware) (ohm_cpu_hertz{instance=~"$instance"})', 'hardware'),
          ovMem: panel.stat.new('Memory')
                 + panel.stat.withTargets([iq('max(windows_memory_physical_total_bytes{instance=~"$instance"})')])
                 + panel.stat.withOptions({ reduceOptions: { values: false, calcs: ['lastNotNull'] }, colorMode: 'value' })
                 + panel.stat.withUnit('bytes'),
          ovTemp: panel.stat.new('CPU Temp')
                  + panel.stat.withTargets([iq('max(ohm_cpu_celsius{instance=~"$instance"})')])
                  + panel.stat.withOptions({ reduceOptions: { values: false, calcs: ['lastNotNull'] }, colorMode: 'value' })
                  + panel.stat.withUnit('celsius')
                  + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 60 }, { color: 'red', value: 80 }]),
        },
      },
      {
        title: 'CPU',  // collector: cpu
        width: 12,
        height: 7,
        elements: {
          cpuBusy: signals.cpuBusy.asTimeSeries('CPU utilisation'),
          cpuByMode: signals.cpuByMode.asTimeSeries('CPU time by mode'),
          cpuFreq: signals.cpuFreq.asTimeSeries('CPU frequency'),
          cpuCState: signals.cpuCState.asTimeSeries('C-state residency'),
          cpuInterrupts: signals.cpuInterrupts.asTimeSeries('Interrupts/s'),
          cpuDpcs: signals.cpuDpcs.asTimeSeries('DPCs/s'),
        },
      },
      {
        title: 'Memory',  // collector: memory
        width: 12,
        height: 7,
        elements: {
          memUsed: signals.memUsed.asTimeSeries('Physical memory used'),
          memAvailable: signals.memAvailable.asTimeSeries('Physical memory available'),
          memCommitted: signals.memCommitted.asTimeSeries('Committed memory'),
          memCommitLimit: signals.memCommitLimit.asTimeSeries('Commit limit'),
          memCache: signals.memCache.asTimeSeries('Cache'),
          memPoolPaged: signals.memPoolPaged.asTimeSeries('Paged pool'),
          memPoolNonpaged: signals.memPoolNonpaged.asTimeSeries('Nonpaged pool'),
          memPageFaults: signals.memPageFaults.asTimeSeries('Page faults/s'),
          memSwapOps: signals.memSwapOps.asTimeSeries('Swap page operations/s'),
        },
      },
      {
        title: 'Disk',  // collector: logical_disk
        width: 12,
        height: 7,
        elements: {
          diskUsedRatio: signals.diskUsedRatio.asTable('Logical disk used ratio'),
          diskFree: signals.diskFree.asTimeSeries('Logical disk free'),
          diskReadBytes: signals.diskReadBytes.asTimeSeries('Disk read'),
          diskWriteBytes: signals.diskWriteBytes.asTimeSeries('Disk write'),
          diskReadIops: signals.diskReadIops.asTimeSeries('Disk read IOPS'),
          diskWriteIops: signals.diskWriteIops.asTimeSeries('Disk write IOPS'),
          diskReadLatency: signals.diskReadLatency.asTimeSeries('Disk read latency'),
          diskWriteLatency: signals.diskWriteLatency.asTimeSeries('Disk write latency'),
          diskQueue: signals.diskQueue.asTimeSeries('Disk queue length'),
          diskActive: signals.diskActive.asTimeSeries('Disk active time'),
        },
      },
      {
        title: 'Network',  // collector: net
        width: 12,
        height: 7,
        elements: {
          netRecv: signals.netRecv.asTimeSeries('Network received'),
          netSent: signals.netSent.asTimeSeries('Network sent'),
          netUtil: signals.netUtil.asTimeSeries('Link utilisation'),
          netBandwidth: signals.netBandwidth.asTimeSeries('Link speed'),
          netPacketsRecv: signals.netPacketsRecv.asTimeSeries('Packets received'),
          netPacketsSent: signals.netPacketsSent.asTimeSeries('Packets sent'),
          netErrors: signals.netErrors.asTimeSeries('Errors/s'),
          netDiscards: signals.netDiscards.asTimeSeries('Discards/s'),
          netQueue: signals.netQueue.asTimeSeries('Output queue length'),
        },
      },
      {
        title: 'System activity',  // collector: system
        width: 12,
        height: 7,
        elements: {
          contextSwitches: signals.contextSwitches.asTimeSeries('Context switches/s'),
          systemCalls: signals.systemCalls.asTimeSeries('System calls/s'),
          exceptions: signals.exceptions.asTimeSeries('Exception dispatches/s'),
          procQueue: signals.procQueue.asTimeSeries('Processor queue length'),
        },
      },
      {
        title: 'Time',  // collector: time — NTP sync health
        width: 12,
        height: 7,
        elements: {
          timeOffset: signals.timeOffset.asTimeSeries('Clock offset'),
          ntpRoundTrip: signals.ntpRoundTrip.asTimeSeries('NTP round-trip delay'),
        },
      },
      {
        title: 'Scrape health',  // collector: exporter — the exporter monitoring itself
        width: 12,
        height: 7,
        elements: {
          osInfo: signals.osInfo.asTable('OS'),
          collectorSuccess: signals.collectorSuccess.asTable('Collector success'),
          scrapeDuration: signals.scrapeDuration.asTimeSeries('Scrape duration'),
          collectorDuration: signals.collectorDuration.asTimeSeries('Collector duration'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('windows', [
        alert.rule.new(
          'WindowsHostDown', 'up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'Windows host {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'WindowsHighCpu',
          '1 - avg without (core) (rate(windows_cpu_time_total{mode="idle"' + rsComma + '}[5m])) > 0.9',
          '15m', 'warning', {},
          { summary: 'CPU on {{ $labels.instance }} is above 90%.' }
        ),
        alert.rule.new(
          'WindowsHighMemory',
          '1 - windows_memory_available_bytes' + rsBrace + ' / windows_memory_physical_total_bytes' + rsBrace + ' > 0.9',
          '15m', 'warning', {},
          { summary: 'Physical memory on {{ $labels.instance }} is above 90%.' }
        ),
        alert.rule.new(
          'WindowsLowDiskSpace',
          'windows_logical_disk_free_bytes' + rsBrace + ' < 5e9',
          '15m', 'warning', {},
          { summary: 'Logical disk {{ $labels.volume }} on {{ $labels.instance }} has less than 5GB free.' }
        ),
        // Temperature (any source) — warning + critical tiers on the per-host max
        // sensor reading, nonsense-filtered. Dormant until a source emits.
        alert.rule.new(
          'WindowsHighTemperature',
          'max by (instance) (' + tempUnionRule + tempRange + ') > ' + cfg.tempWarnC,
          '10m', 'warning', {},
          { summary: 'Temperature on {{ $labels.instance }} is above ' + cfg.tempWarnC + '°C.' }
        ),
        alert.rule.new(
          'WindowsCriticalTemperature',
          'max by (instance) (' + tempUnionRule + tempRange + ') > ' + cfg.tempCritC,
          '5m', 'critical', {},
          { summary: 'Temperature on {{ $labels.instance }} is above ' + cfg.tempCritC + '°C.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('windows.rules', [
        alert.rule.record('instance:windows_cpu_utilisation:rate5m', '1 - avg without (core) (rate(windows_cpu_time_total{mode="idle"' + rsComma + '}[5m]))'),
        alert.rule.record('instance:windows_memory_utilisation:ratio', '1 - windows_memory_available_bytes' + rsBrace + ' / windows_memory_physical_total_bytes' + rsBrace),
        alert.rule.record('instance:windows_logical_disk_free_bytes:sum', 'sum without (volume) (windows_logical_disk_free_bytes' + rsBrace + ')'),
        alert.rule.record('instance:temperature_celsius:max', 'max by (instance) (' + tempUnionRule + tempRange + ')'),
      ]),
    ], [
      // optional tabs — render only when their metrics/logs are present.
      {
        title: 'Workload',
        width: 12,
        height: 7,
        presence: { query: 'windows_service_state{instance=~"$instance"}', label: 'instance' },
        elements: {
          processes: signals.processes.asStat('Processes'),
          servicesRunning: signals.servicesRunning.asStat('Running services'),
          servicesStopped: signals.servicesStopped.asStat('Stopped services'),
          serviceState: signals.serviceState.asTable('Service states'),
        },
      },
      {
        title: 'Logs',
        width: 24,
        height: 12,
        elements: {
          winLogs: panel.logs.new('Windows event log') + panel.logs.withTargets([signals.winLogs.asTarget()]),
        },
      },
      {
        // no `presence` -> showIfData(): hidden until a temperature source emits,
        // then the tab appears on its own (either ohm or thermalzone).
        title: 'Temperature',
        width: 12,
        height: 7,
        elements: {
          tempMax: signals.tempMax.asStat('Max temperature'),
          tempBySensor: signals.tempBySensor.asTimeSeries('Temperature by sensor'),
        },
      },
    ]);

    // ── Fleet overview board (ported from grafana.com dashboard 10467) ──────────
    // 10467 ("Windows Exporter Dashboard 20230531-StarsL.cn") targets windows_exporter
    // 0.22 and its metric vocabulary is gone from current releases: windows_cs_hostname,
    // windows_cs_logical_processors, windows_cs_physical_memory_bytes, windows_os_processes
    // and windows_system_system_up_time no longer exist. Every query below is therefore
    // re-expressed against the names this pack already uses, keeping 10467's *shape*
    // (a resource table over the whole fleet + cross-host utilisation/traffic graphs)
    // rather than its queries:
    //   windows_cs_logical_processors  -> windows_cpu_logical_processor
    //   windows_cs_hostname            -> windows_os_hostname (hostname/fqdn labels)
    //   windows_cs_physical_memory_*   -> windows_memory_physical_total_bytes
    //   windows_os_processes           -> windows_system_processes
    //   windows_system_system_up_time  -> windows_system_boot_time_timestamp
    // 10467's per-host half is intentionally not duplicated — the table drills into
    // the per-host board above, which already covers it.
    local fleetCfg = cfg {
      uid: cfg.fleetUid,
      dashboardTitle: cfg.fleetTitle,
      dashboardTags: cfg.dashboardTags + ['fleet', 'overview'],
      // fleet-wide: cluster is multi-select (defaults to All) and there is no
      // $instance — a row's Instance cell drills into the per-host board instead.
      selector: 'job=~"$job", cluster=~"$cluster"',
      varLabels: ['cluster'],
      varMulti: true,
      lokiDatasource: false,  // no logs on this board -> no Loki variable
      docTabs: false,  // Signals/Runbooks already ship on the per-host board
    };
    local fs = fleetCfg.selector;
    local byNode = 'by (cluster, instance)';
    // EFI/recovery partitions (HarddiskVolumeN) are fixed-size and unactionable,
    // so a full one must not drive the fleet's max() disk column — keep it to
    // lettered volumes. Prometheus regexes are anchored, so this is an exact match.
    local lettered = ', volume=~"[A-Z]:"';

    local fsig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', fleetCfg.datasource, expr, unit).filteringSelector(fs).withLegendFormat(legend);
    // instant table query (labels -> columns, one Value per target), as in common-lib/base.
    local tq(expr) =
      query.prometheus.new(fleetCfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };

    local fleetSignals = {
      fCpu: fsig('CPU utilisation', '1 - avg ' + byNode + ' (rate(windows_cpu_time_total{mode="idle", %(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      fMem: fsig('Memory utilisation', '1 - avg ' + byNode + ' (windows_memory_available_bytes{%(queriesSelector)s}) / avg ' + byNode + ' (windows_memory_physical_total_bytes{%(queriesSelector)s})', 'percentunit'),
      // busiest NIC per host (10467 mirrors sent/received around zero; kept positive
      // here to match the per-host board). isatap/VPN pseudo-NICs are noise.
      fNetSent: fsig('Network sent', 'max ' + byNode + ' (rate(windows_net_bytes_sent_total{%(queriesSelector)s, nic!~"isatap.*|VPN.*"}[$__rate_interval]))', 'Bps', '{{instance}} / sent'),
      fNetRecv: fsig('Network received', 'max ' + byNode + ' (rate(windows_net_bytes_received_total{%(queriesSelector)s, nic!~"isatap.*|VPN.*"}[$__rate_interval]))', 'Bps', '{{instance}} / received'),
      fDiskRead: fsig('Disk read', 'max ' + byNode + ' (rate(windows_logical_disk_read_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} / read'),
      fDiskWrite: fsig('Disk write', 'max ' + byNode + ' (rate(windows_logical_disk_write_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} / write'),
      fDiskReadIops: fsig('Disk read IOPS', 'max ' + byNode + ' (rate(windows_logical_disk_reads_total{%(queriesSelector)s}[$__rate_interval]))', 'iops', '{{instance}} / read'),
      fDiskWriteIops: fsig('Disk write IOPS', 'max ' + byNode + ' (rate(windows_logical_disk_writes_total{%(queriesSelector)s}[$__rate_interval]))', 'iops', '{{instance}} / write'),
    };

    // 10467's "服务器资源总览" table: one row per host, joined from instant queries.
    // A carries no value — it is here for its hostname/product labels only.
    local fleetTable =
      panel.table.new('Servers')
      + panel.table.withTargets([
        tq('windows_os_info{' + fs + '} * on (cluster, instance) group_left(hostname) windows_os_hostname{' + fs + '}'),
        tq('max ' + byNode + ' (time() - windows_system_boot_time_timestamp{' + fs + '})'),
        tq('max ' + byNode + ' (windows_cpu_logical_processor{' + fs + '})'),
        tq('(1 - avg ' + byNode + ' (rate(windows_cpu_time_total{mode="idle", ' + fs + '}[$__rate_interval]))) * 100'),
        tq('max ' + byNode + ' (windows_memory_physical_total_bytes{' + fs + '})'),
        tq('(1 - avg ' + byNode + ' (windows_memory_available_bytes{' + fs + '}) / avg ' + byNode + ' (windows_memory_physical_total_bytes{' + fs + '})) * 100'),
        tq('max ' + byNode + ' (1 - windows_logical_disk_free_bytes{' + fs + lettered + '} / windows_logical_disk_size_bytes{' + fs + lettered + '}) * 100'),
        tq('max ' + byNode + ' (windows_system_processes{' + fs + '})'),
        tq('count ' + byNode + ' (windows_service_state{state="running", ' + fs + '} == 1)'),
      ])
      + panel.table.withTransformations([
        // prometheus instant frames keep labels as metadata, not columns -> promote them
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: [
          'cluster',
          'instance',
          'hostname',
          'product',
          'Value #B',
          'Value #C',
          'Value #D',
          'Value #E',
          'Value #F',
          'Value #G',
          'Value #H',
          'Value #I',
        ] } } },
        { id: 'seriesToColumns', options: { byField: 'instance' } },
        { id: 'organize', options: {
          // the join repeats the cluster column once per extra target.
          excludeByName: { 'Value #A': true } + { ['cluster ' + i]: true for i in std.range(2, 9) },
          indexByName: {
            cluster: 0,
            instance: 1,
            hostname: 2,
            product: 3,
            'Value #B': 4,
            'Value #C': 5,
            'Value #D': 6,
            'Value #E': 7,
            'Value #F': 8,
            'Value #G': 9,
            'Value #H': 10,
            'Value #I': 11,
          },
          renameByName: {
            cluster: 'Cluster',
            instance: 'Instance',
            hostname: 'Hostname',
            product: 'OS',
            'Value #B': 'Uptime',
            'Value #C': 'Cores',
            'Value #D': 'CPU %',
            'Value #E': 'Memory',
            'Value #F': 'Mem %',
            'Value #G': 'Disk %',
            'Value #H': 'Processes',
            'Value #I': 'Services',
          },
        } },
      ])
      + panel.table.withOverrides([
        // drill straight to the per-host board, carrying cluster + datasource.
        ov('^Instance$', [{ id: 'links', value: [{
          title: 'Drill into ${__value.raw}',
          url: '/d/' + cfg.uid + '?var-cluster=${__data.fields["Cluster"]}&var-instance=${__value.raw}&${datasource:queryparam}',
        }] }]),
        ov('^Uptime$', [{ id: 'unit', value: 'dtdurations' }]),
        ov('^Memory$', [{ id: 'unit', value: 'bytes' }]),
        ov('CPU %|Mem %|Disk %', [
          { id: 'unit', value: 'percent' },
          { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } },
          { id: 'min', value: 0 },
          { id: 'max', value: 100 },
        ]),
      ]);

    local ts(title, targets, unit) =
      panel.timeSeries.new(title)
      + panel.timeSeries.withTargets(targets)
      + panel.timeSeries.withUnit(unit);

    local fleet = pack.build(fleetCfg, fleetSignals, [
      {
        title: 'Fleet',
        width: 24,
        height: 12,
        elements: { servers: fleetTable },
      },
      {
        title: 'Utilisation',
        width: 12,
        height: 7,
        elements: {
          fleetCpu: fleetSignals.fCpu.asTimeSeries('CPU utilisation by host'),
          fleetMem: fleetSignals.fMem.asTimeSeries('Memory utilisation by host'),
        },
      },
      {
        title: 'Traffic',
        width: 8,
        height: 7,
        elements: {
          fleetNet: ts('Network by host (busiest NIC)', [fleetSignals.fNetSent.asTarget(), fleetSignals.fNetRecv.asTarget()], 'Bps'),
          fleetDiskBytes: ts('Disk read/write by host', [fleetSignals.fDiskRead.asTarget(), fleetSignals.fDiskWrite.asTarget()], 'Bps'),
          fleetDiskIops: ts('Disk IO by host', [fleetSignals.fDiskReadIops.asTarget(), fleetSignals.fDiskWriteIops.asTarget()], 'iops'),
        },
      },
    ], [], []);

    // expose both boards; render-lib emits every entry in grafana.dashboards.
    main {
      grafana+: {
        dashboards: {
          [cfg.uid + '.json']: main.grafana.dashboard,
          [fleetCfg.uid + '.json']: fleet.grafana.dashboard,
        },
      },
    },
}
