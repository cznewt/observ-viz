// observ-viz Linux node pack (hand-written).
// Comprehensive node_exporter host observability: CPU/load, memory, disk space,
// disk IO, network, and system signals, plus the upstream prometheus node-mixin
// alerting rules and node.rules recording rules. Emitted as native v2 elements.
// Usage:
//   g.libs.system.linux.new({ selector: 'job="node"' }).grafana.dashboard
//   g.libs.system.linux.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'compute-linux-overview',
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
      dashboardTitle: 'Linux Server',
      dashboardTags: ['linux', 'node'],
      datasource: '${datasource}',
      // cluster -> instance cascading selection (vars built by pack.build).
      selector: 'job=~"$job", cluster=~"$cluster", instance=~"$instance"',
      varMetric: 'node_uname_info',
      varLabels: ['cluster', 'instance'],
      // proxmox-exporter metrics key on the PVE node name; assume it matches the
      // node_exporter instance (override if your PVE node names differ).
      proxmoxSelector: 'node=~"$instance"',
      // per-node board: single cluster/instance + a "System" primary tab, plus
      // optional exporter tabs (docker/batocera/services/logs) that show via showIfData.
      primaryTabTitle: 'System',
      varMulti: false,
      lokiDatasource: true,
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      dockerSelector: 'instance=~"$instance", container!=""',
      logsSelector: 'instance=~"$instance"',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      // runbook base; runbook_url = runbookBase + lower(name) -> the official
      // prometheus-operator runbooks (one page per alert).
      runbookBase: 'https://runbooks.prometheus-operator.dev/runbooks/node/',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local runbook(name) = cfg.runbookBase + std.asciiLower(name);

    // default legend carries cluster/instance; per-dimension signals (disk/net/fs/temp)
    // append their device/mountpoint/sensor label.
    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);
    // proxmox VE signals use the proxmox node correlation selector.
    local psig(name, expr, unit, legend='{{node}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.proxmoxSelector).withLegendFormat(legend);
    // docker/container signals (cadvisor, by node) + loki journal signals.
    local dsig(name, expr, unit, legend='{{pod}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.dockerSelector).withLegendFormat(legend);
    local lsig(name, expr) =
      signal.new(name, 'loki', '${loki_datasource}', expr, 'short').filteringSelector(cfg.logsSelector);

    local signals = {
      // --- CPU / Load ---
      cpuBusy: sig('CPU busy', '1 - avg without(cpu,mode)(rate(node_cpu_seconds_total{mode="idle",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      // one aggregate signal: usage per CPU mode (user/system/iowait/steal/...) — one series per mode, stacked.
      cpuMode: sig('CPU by mode', 'avg without(cpu)(rate(node_cpu_seconds_total{mode!="idle",%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '{{instance}} / {{mode}}'),
      load1: sig('Load 1m', 'node_load1{%(queriesSelector)s}', 'short'),
      load5: sig('Load 5m', 'node_load5{%(queriesSelector)s}', 'short'),
      load15: sig('Load 15m', 'node_load15{%(queriesSelector)s}', 'short'),
      loadPerCpu: sig('Load per core', 'node_load1{%(queriesSelector)s} / count without (cpu, mode) (node_cpu_seconds_total{mode="idle",%(queriesSelector)s})', 'short'),

      // --- Memory ---
      memUsed: sig('Memory used', 'node_memory_MemTotal_bytes{%(queriesSelector)s} - node_memory_MemAvailable_bytes{%(queriesSelector)s}', 'bytes'),
      memAvailable: sig('Memory available', 'node_memory_MemAvailable_bytes{%(queriesSelector)s}', 'bytes'),
      memFree: sig('Memory free', 'node_memory_MemFree_bytes{%(queriesSelector)s}', 'bytes'),
      memCached: sig('Memory cached', 'node_memory_Cached_bytes{%(queriesSelector)s}', 'bytes'),
      memBuffers: sig('Memory buffers', 'node_memory_Buffers_bytes{%(queriesSelector)s}', 'bytes'),
      memUsedRatio: sig('Memory used ratio', '1 - node_memory_MemAvailable_bytes{%(queriesSelector)s} / node_memory_MemTotal_bytes{%(queriesSelector)s}', 'percentunit'),
      swapUsed: sig('Swap used', 'node_memory_SwapTotal_bytes{%(queriesSelector)s} - node_memory_SwapFree_bytes{%(queriesSelector)s}', 'bytes'),
      swapIoPages: sig('Swap IO pages', 'rate(node_vmstat_pgpgin{%(queriesSelector)s}[$__rate_interval]) + rate(node_vmstat_pgpgout{%(queriesSelector)s}[$__rate_interval])', 'short'),

      // --- Disk space / Filesystem ---
      fsUsed: sig('Filesystem used', '1 - node_filesystem_avail_bytes{fstype!="",%(queriesSelector)s} / node_filesystem_size_bytes{fstype!="",%(queriesSelector)s}', 'percentunit', '{{instance}} / {{mountpoint}}'),
      fsAvail: sig('Filesystem available', 'node_filesystem_avail_bytes{fstype!="",%(queriesSelector)s}', 'bytes', '{{instance}} / {{mountpoint}}'),
      fsSize: sig('Filesystem size', 'node_filesystem_size_bytes{fstype!="",%(queriesSelector)s}', 'bytes', '{{instance}} / {{mountpoint}}'),
      inodesUsed: sig('Inodes used', '1 - node_filesystem_files_free{fstype!="",%(queriesSelector)s} / node_filesystem_files{fstype!="",%(queriesSelector)s}', 'percentunit', '{{instance}} / {{mountpoint}}'),

      // --- Disk IO ---
      diskReadBps: sig('Disk read', 'rate(node_disk_read_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}}'),
      diskWriteBps: sig('Disk write', 'rate(node_disk_written_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}}'),
      diskReadIops: sig('Disk read IOPS', 'rate(node_disk_reads_completed_total{%(queriesSelector)s}[$__rate_interval])', 'iops', '{{instance}} / {{device}}'),
      diskWriteIops: sig('Disk write IOPS', 'rate(node_disk_writes_completed_total{%(queriesSelector)s}[$__rate_interval])', 'iops', '{{instance}} / {{device}}'),
      diskIoLatency: sig('Disk IO latency', 'rate(node_disk_io_time_weighted_seconds_total{%(queriesSelector)s}[$__rate_interval])', 's', '{{instance}} / {{device}}'),
      diskIo: sig('Disk IO time', 'rate(node_disk_io_time_seconds_total{device!="",%(queriesSelector)s}[$__rate_interval])', 'percentunit', '{{instance}} / {{device}}'),

      // --- Network ---
      netRx: sig('Network received', 'rate(node_network_receive_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}}'),
      netTx: sig('Network transmitted', 'rate(node_network_transmit_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}}'),
      netRxErrs: sig('Network receive errors', 'rate(node_network_receive_errs_total{%(queriesSelector)s}[$__rate_interval])', 'pps', '{{instance}} / {{device}}'),
      netTxErrs: sig('Network transmit errors', 'rate(node_network_transmit_errs_total{%(queriesSelector)s}[$__rate_interval])', 'pps', '{{instance}} / {{device}}'),
      netRxDrop: sig('Network receive drops', 'rate(node_network_receive_drop_total{%(queriesSelector)s}[$__rate_interval])', 'pps', '{{instance}} / {{device}}'),
      netTxDrop: sig('Network transmit drops', 'rate(node_network_transmit_drop_total{%(queriesSelector)s}[$__rate_interval])', 'pps', '{{instance}} / {{device}}'),
      netRxExclLo: sig('Network received (excl lo)', 'sum without (device) (rate(node_network_receive_bytes_total{device!="lo",%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      netTxExclLo: sig('Network transmitted (excl lo)', 'sum without (device) (rate(node_network_transmit_bytes_total{device!="lo",%(queriesSelector)s}[$__rate_interval]))', 'Bps'),

      // --- System ---
      uptime: sig('Uptime', 'time() - node_boot_time_seconds{%(queriesSelector)s}', 's'),
      contextSwitches: sig('Context switches', 'rate(node_context_switches_total{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      fdUsed: sig('File descriptors used', 'node_filefd_allocated{%(queriesSelector)s}', 'short'),
      fdMax: sig('File descriptors max', 'node_filefd_maximum{%(queriesSelector)s}', 'short'),
      conntrackUsed: sig('Conntrack used', 'node_nf_conntrack_entries{%(queriesSelector)s}', 'short'),
      conntrackMax: sig('Conntrack max', 'node_nf_conntrack_entries_limit{%(queriesSelector)s}', 'short'),

      // --- Temperature / power (hwmon, thermal_zone, rapl) ---
      tempCelsius: sig('Temperature', 'node_hwmon_temp_celsius{%(queriesSelector)s}', 'celsius', '{{instance}} / {{chip}} {{sensor}}'),
      thermalZone: sig('Thermal zone', 'node_thermal_zone_temp{%(queriesSelector)s}', 'celsius', '{{instance}} / {{type}}'),
      raplPower: sig('CPU package power', 'sum without (index, path) (rate(node_rapl_package_joules_total{%(queriesSelector)s}[$__rate_interval]))', 'watt'),

      // --- CPU frequency / scheduler (cpufreq, schedstat) ---
      cpuFreq: sig('CPU frequency', 'avg without (cpu) (node_cpu_scaling_frequency_hertz{%(queriesSelector)s})', 'hertz'),
      schedWait: sig('Scheduler wait time', 'sum without (cpu) (rate(node_schedstat_waiting_seconds_total{%(queriesSelector)s}[$__rate_interval]))', 's'),

      // --- Paging / faults (vmstat) ---
      pgFaults: sig('Page faults', 'rate(node_vmstat_pgfault{%(queriesSelector)s}[$__rate_interval])', 'short'),
      pgMajFaults: sig('Major page faults', 'rate(node_vmstat_pgmajfault{%(queriesSelector)s}[$__rate_interval])', 'short'),
      swapIn: sig('Swap in', 'rate(node_vmstat_pswpin{%(queriesSelector)s}[$__rate_interval])', 'short'),
      swapOut: sig('Swap out', 'rate(node_vmstat_pswpout{%(queriesSelector)s}[$__rate_interval])', 'short'),

      // --- Processes / entropy (stat, entropy) ---
      procsRunning: sig('Processes running', 'node_procs_running{%(queriesSelector)s}', 'short'),
      procsBlocked: sig('Processes blocked (uninterruptible)', 'node_procs_blocked{%(queriesSelector)s}', 'short'),
      entropy: sig('Entropy available', 'node_entropy_available_bits{%(queriesSelector)s}', 'short'),

      // --- TCP / sockets / softnet (netstat, sockstat, softnet, udp_queues) ---
      tcpEstablished: sig('TCP established', 'node_netstat_Tcp_CurrEstab{%(queriesSelector)s}', 'short'),
      tcpActiveOpens: sig('TCP active opens', 'rate(node_netstat_Tcp_ActiveOpens{%(queriesSelector)s}[$__rate_interval])', 'short'),
      tcpRetrans: sig('TCP SYN retransmits', 'rate(node_netstat_TcpExt_TCPSynRetrans{%(queriesSelector)s}[$__rate_interval])', 'short'),
      tcpInErrs: sig('TCP in errors', 'rate(node_netstat_Tcp_InErrs{%(queriesSelector)s}[$__rate_interval])', 'short'),
      socketsTcp: sig('TCP sockets in use', 'node_sockstat_TCP_inuse{%(queriesSelector)s}', 'short'),
      socketsMem: sig('TCP socket memory', 'node_sockstat_TCP_mem_bytes{%(queriesSelector)s}', 'bytes'),
      softnetDropped: sig('Softnet dropped', 'sum without (cpu) (rate(node_softnet_dropped_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      softnetSqueezed: sig('Softnet times squeezed', 'sum without (cpu) (rate(node_softnet_times_squeezed_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      udpQueues: sig('UDP queue', 'node_udp_queues{%(queriesSelector)s}', 'bytes', '{{instance}} / {{queue}}'),

      // --- Pressure stall information (collector: pressure / PSI) ---
      psiCpu: sig('CPU pressure', 'rate(node_pressure_cpu_waiting_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit'),
      psiMem: sig('Memory pressure (some)', 'rate(node_pressure_memory_waiting_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit'),
      psiMemFull: sig('Memory pressure (full)', 'rate(node_pressure_memory_stalled_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit'),
      psiIo: sig('IO pressure (some)', 'rate(node_pressure_io_waiting_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit'),
      psiIoFull: sig('IO pressure (full)', 'rate(node_pressure_io_stalled_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit'),

      // --- Proxmox VE (optional tab; renders only on PVE hosts via showIfData) ---
      pveUp: psig('PVE node up', 'proxmox_node_up{%(queriesSelector)s}', 'short'),
      pveCpusAllocated: psig('vCPUs allocated', 'proxmox_node_cpus_allocated{%(queriesSelector)s}', 'short'),
      pveMemAllocated: psig('Memory allocated', 'proxmox_node_memory_allocated_bytes{%(queriesSelector)s}', 'bytes'),

      // --- Docker / containers (optional tab; cadvisor, by node) ---
      dockerContainers: dsig('Containers', 'count(container_last_seen{%(queriesSelector)s})', 'short', 'containers'),
      dockerCpu: dsig('Container CPU', 'sum by (pod) (rate(container_cpu_usage_seconds_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      dockerMem: dsig('Container memory', 'sum by (pod) (container_memory_usage_bytes{%(queriesSelector)s})', 'bytes'),

      // --- Services (optional tab; node_exporter systemd collector) ---
      servicesActive: sig('Active services', 'sum(node_systemd_unit_state{state="active",%(queriesSelector)s})', 'short', 'active'),
      servicesFailed: sig('Failed services', 'node_systemd_unit_state{state="failed",%(queriesSelector)s} == 1', 'short', '{{name}}'),

      // --- Batocera (optional tab; gated on presence of batocera_* metrics) ---
      batoceraOs: signal.new('Batocera', 'prometheus', cfg.datasource, 'node_os_info{id=~"batocera", instance=~"$instance"}', 'short').withLegendFormat('{{instance}} {{pretty_name}}'),
      batoceraTemp: signal.new('Batocera temperature', 'prometheus', cfg.datasource, 'node_hwmon_temp_celsius{instance=~"$instance"} and on (instance) node_os_info{id=~"batocera"}', 'celsius').withLegendFormat('{{instance}} / {{chip}}'),

      // --- ZFS ARC (optional tab; zfs collector, gated on presence) ---
      zfsArcSize: sig('ZFS ARC size', 'node_zfs_arc_size{%(queriesSelector)s}', 'bytes'),
      zfsArcCMax: sig('ZFS ARC target max', 'node_zfs_arc_c_max{%(queriesSelector)s}', 'bytes'),
      zfsArcHitRatio: sig('ZFS ARC hit ratio', 'rate(node_zfs_arc_hits{%(queriesSelector)s}[$__rate_interval]) / clamp_min(rate(node_zfs_arc_hits{%(queriesSelector)s}[$__rate_interval]) + rate(node_zfs_arc_misses{%(queriesSelector)s}[$__rate_interval]), 1)', 'percentunit'),
      zfsArcHits: sig('ZFS ARC hits', 'rate(node_zfs_arc_hits{%(queriesSelector)s}[$__rate_interval])', 'short'),
      zfsArcMisses: sig('ZFS ARC misses', 'rate(node_zfs_arc_misses{%(queriesSelector)s}[$__rate_interval])', 'short'),

      // --- NFS client (optional tab; nfs collector, gated on presence) ---
      nfsRpcs: sig('NFS RPCs', 'rate(node_nfs_rpcs_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      nfsRetransmissions: sig('NFS RPC retransmissions', 'rate(node_nfs_rpc_retransmissions_total{%(queriesSelector)s}[$__rate_interval])', 'short'),

      // --- Battery / power supply (optional tab; powersupplyclass collector, gated) ---
      batteryCapacity: sig('Battery capacity', 'node_power_supply_capacity{%(queriesSelector)s}', 'percent', '{{instance}} / {{power_supply}}'),
      batteryOnline: sig('AC online', 'node_power_supply_online{%(queriesSelector)s}', 'short', '{{instance}} / {{power_supply}}'),
      batteryPower: sig('Power draw', 'node_power_supply_power_watt{%(queriesSelector)s}', 'watt', '{{instance}} / {{power_supply}}'),
      batteryVoltage: sig('Battery voltage', 'node_power_supply_voltage_volt{%(queriesSelector)s}', 'volt', '{{instance}} / {{power_supply}}'),

      // --- Logs (optional tab; loki journal for the node) ---
      nodeLogs: lsig('Journal', '{%(queriesSelector)s}'),
    };

    local query = import 'custom/query.libsonnet';
    local iq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    // label-value stat tile (shows a label like pretty_name instead of the value)
    local labelStat(title, expr, field) =
      panel.stat.new(title)
      + panel.stat.withTargets([iq(expr)])
      + panel.stat.withOptions({ reduceOptions: { values: true, fields: '/^' + field + '$/' }, colorMode: 'none' });
    local numStat(title, expr, unit) =
      panel.stat.new(title)
      + panel.stat.withTargets([iq(expr)])
      + panel.stat.withOptions({ reduceOptions: { values: false, calcs: ['lastNotNull'] }, colorMode: 'value' })
      + panel.stat.withUnit(unit);
    local inst = 'instance=~"$instance"';
    pack.build(cfg, signals, [
      // generic system facts, mirroring the cluster-detail tables.
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          ovDevice: labelStat('Device', 'sum by (device) (label_join((label_replace(node_dmi_info{' + inst + ', product_version!~"Default string|System Version|System Product Name|To Be Filled.*|"}, "dev", "$1", "product_version", "(.+)")) or (label_replace(node_dmi_info{' + inst + ', product_version=~"Default string|System Version|System Product Name|To Be Filled.*|"}, "dev", "$1", "product_name", "(.+)")), "device", " ", "system_vendor", "dev"))', 'device'),
          ovOs: labelStat('OS', 'node_os_info{' + inst + '}', 'pretty_name'),
          ovKernel: labelStat('Kernel', 'node_uname_info{' + inst + '}', 'release'),
          ovModel: labelStat('CPU Model', 'sum by (model_name) (node_cpu_info{' + inst + '})', 'model_name'),
          ovArch: labelStat('Arch', 'node_uname_info{' + inst + '}', 'machine'),
          ovType: labelStat('Type', 'label_replace(label_replace(sum by (product_name) (node_dmi_info{' + inst + '}), "kind", "physical", "", ""), "kind", "virtual", "product_name", "Standard PC.*|KVM.*|.*[Vv]irtual.*|VMware.*|Bochs.*")', 'kind'),
          ovCores: numStat('Cores', 'count(node_cpu_seconds_total{mode="idle", ' + inst + '})', 'short'),
          ovMem: numStat('Memory', 'max(node_memory_MemTotal_bytes{' + inst + '})', 'bytes'),
          ovUptime: numStat('Uptime', 'max(time() - node_boot_time_seconds{' + inst + '})', 'dtdurations'),
          ovLoad: numStat('Load 1m', 'max(node_load1{' + inst + '})', 'short'),
          ovTemp: numStat('CPU Temp', 'max(node_hwmon_temp_celsius{chip=~".*coretemp.*|.*k10temp.*|.*zenpower.*|.*cpu_thermal.*|pci0000:00_0000:00:18_3", ' + inst + '})', 'celsius')
                  + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 60 }, { color: 'red', value: 80 }]),
        },
      },
      {
        title: 'System',
        width: 12,
        height: 7,
        elements: {
          uptime: signals.uptime.asStat('Uptime'),
          procsRunning: signals.procsRunning.asStat('Processes running'),
          procsBlocked: signals.procsBlocked.asStat('Processes blocked'),
          contextSwitches: signals.contextSwitches.asTimeSeries('Context switches'),
          fdUsed: signals.fdUsed.asTimeSeries('File descriptors used'),
          conntrackUsed: signals.conntrackUsed.asTimeSeries('Conntrack used'),
          entropy: signals.entropy.asTimeSeries('Entropy available'),
        },
      },
      {
        title: 'CPU / Load',
        width: 12,
        height: 7,
        elements: {
          // single aggregate CPU chart: all modes stacked.
          cpuMode: signals.cpuMode.asTimeSeries('CPU usage by mode')
                   + { spec+: { vizConfig+: { spec+: { fieldConfig+: { defaults+: { custom+: { stacking: { mode: 'normal', group: 'A' }, fillOpacity: 30 } } } } } } },
          cpuBusy: signals.cpuBusy.asStat('CPU busy'),
          load1: signals.load1.asTimeSeries('Load 1m'),
          load5: signals.load5.asTimeSeries('Load 5m'),
          load15: signals.load15.asTimeSeries('Load 15m'),
          loadPerCpu: signals.loadPerCpu.asTimeSeries('Load per core'),
          cpuFreq: signals.cpuFreq.asTimeSeries('CPU frequency'),
          schedWait: signals.schedWait.asTimeSeries('Scheduler wait time'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memUsedRatio: signals.memUsedRatio.asStat('Memory used ratio'),
          memUsed: signals.memUsed.asTimeSeries('Memory used'),
          memAvailable: signals.memAvailable.asTimeSeries('Memory available'),
          memCached: signals.memCached.asTimeSeries('Memory cached'),
          memBuffers: signals.memBuffers.asTimeSeries('Memory buffers'),
          memFree: signals.memFree.asTimeSeries('Memory free'),
          swapUsed: signals.swapUsed.asTimeSeries('Swap used'),
          pgFaults: signals.pgFaults.asTimeSeries('Page faults'),
          pgMajFaults: signals.pgMajFaults.asTimeSeries('Major page faults'),
          swapIn: signals.swapIn.asTimeSeries('Swap in'),
          swapOut: signals.swapOut.asTimeSeries('Swap out'),
        },
      },
      {
        title: 'Disk space',
        width: 12,
        height: 7,
        elements: {
          fsUsed: signals.fsUsed.asTable('Filesystem used ratio'),
          inodesUsed: signals.inodesUsed.asTable('Inodes used ratio'),
          fsAvail: signals.fsAvail.asTimeSeries('Filesystem available'),
          fsSize: signals.fsSize.asTimeSeries('Filesystem size'),
        },
      },
      {
        title: 'Disk IO',
        width: 12,
        height: 7,
        elements: {
          diskReadBps: signals.diskReadBps.asTimeSeries('Disk read'),
          diskWriteBps: signals.diskWriteBps.asTimeSeries('Disk write'),
          diskReadIops: signals.diskReadIops.asTimeSeries('Disk read IOPS'),
          diskWriteIops: signals.diskWriteIops.asTimeSeries('Disk write IOPS'),
          diskIoLatency: signals.diskIoLatency.asTimeSeries('Disk IO latency'),
          diskIo: signals.diskIo.asTimeSeries('Disk IO utilization'),
        },
      },
      {
        title: 'Network',
        width: 12,
        height: 7,
        elements: {
          netRx: signals.netRx.asTimeSeries('Network received'),
          netTx: signals.netTx.asTimeSeries('Network transmitted'),
          netRxErrs: signals.netRxErrs.asTimeSeries('Network receive errors'),
          netTxErrs: signals.netTxErrs.asTimeSeries('Network transmit errors'),
          netRxDrop: signals.netRxDrop.asTimeSeries('Network receive drops'),
          netTxDrop: signals.netTxDrop.asTimeSeries('Network transmit drops'),
          tcpEstablished: signals.tcpEstablished.asTimeSeries('TCP established'),
          tcpActiveOpens: signals.tcpActiveOpens.asTimeSeries('TCP active opens'),
          tcpRetrans: signals.tcpRetrans.asTimeSeries('TCP SYN retransmits'),
          tcpInErrs: signals.tcpInErrs.asTimeSeries('TCP in errors'),
          socketsTcp: signals.socketsTcp.asTimeSeries('TCP sockets in use'),
          socketsMem: signals.socketsMem.asTimeSeries('TCP socket memory'),
          softnetDropped: signals.softnetDropped.asTimeSeries('Softnet dropped'),
          softnetSqueezed: signals.softnetSqueezed.asTimeSeries('Softnet times squeezed'),
          udpQueues: signals.udpQueues.asTimeSeries('UDP queue'),
        },
      },
      {
        title: 'Temperature / power',
        width: 12,
        height: 7,
        elements: {
          tempCelsius: signals.tempCelsius.asTimeSeries('Hardware temperature'),
          thermalZone: signals.thermalZone.asTimeSeries('Thermal zone'),
          raplPower: signals.raplPower.asTimeSeries('CPU package power'),
        },
      },
      {
        title: 'Pressure (PSI)',
        width: 12,
        height: 7,
        elements: {
          psiCpu: signals.psiCpu.asTimeSeries('CPU pressure'),
          psiMem: signals.psiMem.asTimeSeries('Memory pressure (some)'),
          psiMemFull: signals.psiMemFull.asTimeSeries('Memory pressure (full)'),
          psiIo: signals.psiIo.asTimeSeries('IO pressure (some)'),
          psiIoFull: signals.psiIoFull.asTimeSeries('IO pressure (full)'),
        },
      },
    ], [
      // alerting rule group — upstream prometheus node-mixin (group: node-exporter)
      alert.rule.group('node-exporter', [
        // --- Filesystem space filling up ---
        alert.rule.new(
          'NodeFilesystemSpaceFillingUp',
          |||
            (
              node_filesystem_avail_bytes{fstype!="",mountpoint!=""%(rs)s} / node_filesystem_size_bytes{fstype!="",mountpoint!=""%(rs)s} * 100 < 40
            and
              predict_linear(node_filesystem_avail_bytes{fstype!="",mountpoint!=""%(rs)s}[6h], 24*60*60) < 0
            and
              node_filesystem_readonly{fstype!="",mountpoint!=""%(rs)s} == 0
            )
          ||| % { rs: rsComma },
          '1h', 'warning', {},
          {
            summary: 'Filesystem is predicted to run out of space within the next 24 hours.',
            description: 'Filesystem on {{ $labels.device }}, mounted on {{ $labels.mountpoint }}, at {{ $labels.instance }} has only {{ printf "%.2f" $value }}% available space left and is filling up.',
            runbook_url: runbook('NodeFilesystemSpaceFillingUp'),
          }
        ),
        alert.rule.new(
          'NodeFilesystemSpaceFillingUp',
          |||
            (
              node_filesystem_avail_bytes{fstype!="",mountpoint!=""%(rs)s} / node_filesystem_size_bytes{fstype!="",mountpoint!=""%(rs)s} * 100 < 20
            and
              predict_linear(node_filesystem_avail_bytes{fstype!="",mountpoint!=""%(rs)s}[6h], 4*60*60) < 0
            and
              node_filesystem_readonly{fstype!="",mountpoint!=""%(rs)s} == 0
            )
          ||| % { rs: rsComma },
          '1h', 'critical', {},
          {
            summary: 'Filesystem is predicted to run out of space within the next 4 hours.',
            description: 'Filesystem on {{ $labels.device }}, mounted on {{ $labels.mountpoint }}, at {{ $labels.instance }} has only {{ printf "%.2f" $value }}% available space left and is filling up fast.',
            runbook_url: runbook('NodeFilesystemSpaceFillingUp'),
          }
        ),
        // --- Filesystem almost out of space ---
        alert.rule.new(
          'NodeFilesystemAlmostOutOfSpace',
          |||
            (
              node_filesystem_avail_bytes{fstype!="",mountpoint!=""%(rs)s} / node_filesystem_size_bytes{fstype!="",mountpoint!=""%(rs)s} * 100 < 5
            and
              node_filesystem_readonly{fstype!="",mountpoint!=""%(rs)s} == 0
            )
          ||| % { rs: rsComma },
          '30m', 'warning', {},
          {
            summary: 'Filesystem has less than 5% space left.',
            description: 'Filesystem on {{ $labels.device }}, mounted on {{ $labels.mountpoint }}, at {{ $labels.instance }} has only {{ printf "%.2f" $value }}% available space left.',
            runbook_url: runbook('NodeFilesystemAlmostOutOfSpace'),
          }
        ),
        alert.rule.new(
          'NodeFilesystemAlmostOutOfSpace',
          |||
            (
              node_filesystem_avail_bytes{fstype!="",mountpoint!=""%(rs)s} / node_filesystem_size_bytes{fstype!="",mountpoint!=""%(rs)s} * 100 < 3
            and
              node_filesystem_readonly{fstype!="",mountpoint!=""%(rs)s} == 0
            )
          ||| % { rs: rsComma },
          '30m', 'critical', {},
          {
            summary: 'Filesystem has less than 3% space left.',
            description: 'Filesystem on {{ $labels.device }}, mounted on {{ $labels.mountpoint }}, at {{ $labels.instance }} has only {{ printf "%.2f" $value }}% available space left.',
            runbook_url: runbook('NodeFilesystemAlmostOutOfSpace'),
          }
        ),
        // --- Filesystem files (inodes) filling up ---
        alert.rule.new(
          'NodeFilesystemFilesFillingUp',
          |||
            (
              node_filesystem_files_free{fstype!="",mountpoint!=""%(rs)s} / node_filesystem_files{fstype!="",mountpoint!=""%(rs)s} * 100 < 40
            and
              predict_linear(node_filesystem_files_free{fstype!="",mountpoint!=""%(rs)s}[6h], 24*60*60) < 0
            and
              node_filesystem_readonly{fstype!="",mountpoint!=""%(rs)s} == 0
            )
          ||| % { rs: rsComma },
          '1h', 'warning', {},
          {
            summary: 'Filesystem is predicted to run out of inodes within the next 24 hours.',
            description: 'Filesystem on {{ $labels.device }}, mounted on {{ $labels.mountpoint }}, at {{ $labels.instance }} has only {{ printf "%.2f" $value }}% available inodes left and is filling up.',
            runbook_url: runbook('NodeFilesystemFilesFillingUp'),
          }
        ),
        alert.rule.new(
          'NodeFilesystemFilesFillingUp',
          |||
            (
              node_filesystem_files_free{fstype!="",mountpoint!=""%(rs)s} / node_filesystem_files{fstype!="",mountpoint!=""%(rs)s} * 100 < 20
            and
              predict_linear(node_filesystem_files_free{fstype!="",mountpoint!=""%(rs)s}[6h], 4*60*60) < 0
            and
              node_filesystem_readonly{fstype!="",mountpoint!=""%(rs)s} == 0
            )
          ||| % { rs: rsComma },
          '1h', 'critical', {},
          {
            summary: 'Filesystem is predicted to run out of inodes within the next 4 hours.',
            description: 'Filesystem on {{ $labels.device }}, mounted on {{ $labels.mountpoint }}, at {{ $labels.instance }} has only {{ printf "%.2f" $value }}% available inodes left and is filling up fast.',
            runbook_url: runbook('NodeFilesystemFilesFillingUp'),
          }
        ),
        // --- Filesystem almost out of files (inodes) ---
        alert.rule.new(
          'NodeFilesystemAlmostOutOfFiles',
          |||
            (
              node_filesystem_files_free{fstype!="",mountpoint!=""%(rs)s} / node_filesystem_files{fstype!="",mountpoint!=""%(rs)s} * 100 < 5
            and
              node_filesystem_readonly{fstype!="",mountpoint!=""%(rs)s} == 0
            )
          ||| % { rs: rsComma },
          '1h', 'warning', {},
          {
            summary: 'Filesystem has less than 5% inodes left.',
            description: 'Filesystem on {{ $labels.device }}, mounted on {{ $labels.mountpoint }}, at {{ $labels.instance }} has only {{ printf "%.2f" $value }}% available inodes left.',
            runbook_url: runbook('NodeFilesystemAlmostOutOfFiles'),
          }
        ),
        alert.rule.new(
          'NodeFilesystemAlmostOutOfFiles',
          |||
            (
              node_filesystem_files_free{fstype!="",mountpoint!=""%(rs)s} / node_filesystem_files{fstype!="",mountpoint!=""%(rs)s} * 100 < 3
            and
              node_filesystem_readonly{fstype!="",mountpoint!=""%(rs)s} == 0
            )
          ||| % { rs: rsComma },
          '1h', 'critical', {},
          {
            summary: 'Filesystem has less than 3% inodes left.',
            description: 'Filesystem on {{ $labels.device }}, mounted on {{ $labels.mountpoint }}, at {{ $labels.instance }} has only {{ printf "%.2f" $value }}% available inodes left.',
            runbook_url: runbook('NodeFilesystemAlmostOutOfFiles'),
          }
        ),
        // --- Network errors ---
        alert.rule.new(
          'NodeNetworkReceiveErrs',
          'rate(node_network_receive_errs_total' + rsBrace + '[2m]) / rate(node_network_receive_packets_total' + rsBrace + '[2m]) > 0.01',
          '1h', 'warning', {},
          {
            summary: 'Network interface is reporting many receive errors.',
            description: '{{ $labels.instance }} interface {{ $labels.device }} has encountered {{ printf "%.0f" $value }} receive errors in the last two minutes.',
            runbook_url: runbook('NodeNetworkReceiveErrs'),
          }
        ),
        alert.rule.new(
          'NodeNetworkTransmitErrs',
          'rate(node_network_transmit_errs_total' + rsBrace + '[2m]) / rate(node_network_transmit_packets_total' + rsBrace + '[2m]) > 0.01',
          '1h', 'warning', {},
          {
            summary: 'Network interface is reporting many transmit errors.',
            description: '{{ $labels.instance }} interface {{ $labels.device }} has encountered {{ printf "%.0f" $value }} transmit errors in the last two minutes.',
            runbook_url: runbook('NodeNetworkTransmitErrs'),
          }
        ),
        // --- Conntrack ---
        alert.rule.new(
          'NodeHighNumberConntrackEntriesUsed',
          '(node_nf_conntrack_entries' + rsBrace + ' / node_nf_conntrack_entries_limit) > 0.75',
          '0m', 'warning', {},
          {
            summary: 'Number of conntrack are getting close to the limit.',
            description: '{{ $labels.instance }} {{ $value | humanizePercentage }} of conntrack entries are used.',
            runbook_url: runbook('NodeHighNumberConntrackEntriesUsed'),
          }
        ),
        // --- Textfile collector ---
        alert.rule.new(
          'NodeTextFileCollectorScrapeError',
          'node_textfile_scrape_error' + rsBrace + ' == 1',
          '0m', 'warning', {},
          {
            summary: 'Node Exporter text file collector failed to scrape.',
            description: 'Node Exporter text file collector on {{ $labels.instance }} failed to scrape.',
            runbook_url: runbook('NodeTextFileCollectorScrapeError'),
          }
        ),
        // --- Clock ---
        alert.rule.new(
          'NodeClockSkewDetected',
          |||
            (
              node_timex_offset_seconds%(rb)s > 0.05
            and
              deriv(node_timex_offset_seconds%(rb)s[5m]) >= 0
            )
            or
            (
              node_timex_offset_seconds%(rb)s < -0.05
            and
              deriv(node_timex_offset_seconds%(rb)s[5m]) <= 0
            )
          ||| % { rb: rsBrace },
          '10m', 'warning', {},
          {
            summary: 'Clock skew detected.',
            description: 'Clock at {{ $labels.instance }} is out of sync by more than 0.05s. Ensure NTP is configured correctly on this host.',
            runbook_url: runbook('NodeClockSkewDetected'),
          }
        ),
        alert.rule.new(
          'NodeClockNotSynchronising',
          'min_over_time(node_timex_sync_status' + rsBrace + '[5m]) == 0\nand\nnode_timex_maxerror_seconds' + rsBrace + ' >= 16',
          '10m', 'warning', {},
          {
            summary: 'Clock not synchronising.',
            description: 'Clock at {{ $labels.instance }} is not synchronising. Ensure NTP is configured on this host.',
            runbook_url: runbook('NodeClockNotSynchronising'),
          }
        ),
        // --- RAID ---
        alert.rule.new(
          'NodeRAIDDegraded',
          'node_md_disks_required{device!=""' + rsComma + '} - ignoring (state) (node_md_disks{state="active",device!=""' + rsComma + '}) > 0',
          '15m', 'critical', {},
          {
            summary: 'RAID Array is degraded.',
            description: "RAID array '{{ $labels.device }}' at {{ $labels.instance }} is in degraded state due to one or more disks failures. Number of spare drives is insufficient to fix issue automatically.",
            runbook_url: runbook('NodeRAIDDegraded'),
          }
        ),
        alert.rule.new(
          'NodeRAIDDiskFailure',
          'node_md_disks{state="failed",device!=""' + rsComma + '} > 0',
          '0m', 'warning', {},
          {
            summary: 'Failed device in RAID array.',
            description: "At least one device in RAID array at {{ $labels.instance }} failed. Array '{{ $labels.device }}' needs attention and possibly a disk swap.",
            runbook_url: runbook('NodeRAIDDiskFailure'),
          }
        ),
        // --- File descriptors ---
        alert.rule.new(
          'NodeFileDescriptorLimit',
          '(\n  node_filefd_allocated' + rsBrace + ' * 100 / node_filefd_maximum' + rsBrace + ' > 70\n)',
          '15m', 'warning', {},
          {
            summary: 'Kernel is predicted to exhaust file descriptors limit soon.',
            description: 'File descriptors limit at {{ $labels.instance }} is currently at {{ printf "%.2f" $value }}%.',
            runbook_url: runbook('NodeFileDescriptorLimit'),
          }
        ),
        alert.rule.new(
          'NodeFileDescriptorLimit',
          '(\n  node_filefd_allocated' + rsBrace + ' * 100 / node_filefd_maximum' + rsBrace + ' > 90\n)',
          '15m', 'critical', {},
          {
            summary: 'Kernel is predicted to exhaust file descriptors limit soon.',
            description: 'File descriptors limit at {{ $labels.instance }} is currently at {{ printf "%.2f" $value }}%.',
            runbook_url: runbook('NodeFileDescriptorLimit'),
          }
        ),
        // --- CPU / saturation / memory / disk IO ---
        alert.rule.new(
          'NodeCPUHighUsage',
          'sum without(mode) (avg without (cpu) (rate(node_cpu_seconds_total{mode!~"idle|iowait"' + rsComma + '}[2m]))) * 100 > 90',
          '15m', 'info', {},
          {
            summary: 'High CPU usage.',
            description: 'CPU usage at {{ $labels.instance }} has been above 90% for the last 15 minutes, is currently at {{ printf "%.2f" $value }}%.',
            runbook_url: runbook('NodeCPUHighUsage'),
          }
        ),
        alert.rule.new(
          'NodeSystemSaturation',
          'node_load1' + rsBrace + '\n/ count without (cpu, mode) (node_cpu_seconds_total{mode="idle"' + rsComma + '}) > 2',
          '15m', 'warning', {},
          {
            summary: 'System saturated, load per core is very high.',
            description: 'System load per core at {{ $labels.instance }} has been above 2 for the last 15 minutes, is currently at {{ printf "%.2f" $value }}.\nThis might indicate this instance resources saturation and can cause it becoming unresponsive.',
            runbook_url: runbook('NodeSystemSaturation'),
          }
        ),
        alert.rule.new(
          'NodeMemoryMajorPagesFaults',
          'rate(node_vmstat_pgmajfault' + rsBrace + '[5m]) > 500',
          '15m', 'warning', {},
          {
            summary: 'Memory major page faults are occurring at very high rate.',
            description: 'Memory major pages are occurring at very high rate at {{ $labels.instance }}, 500 major page faults per second for the last 15 minutes, is currently at {{ printf "%.2f" $value }}.\nPlease check that there is enough memory available at this instance.',
            runbook_url: runbook('NodeMemoryMajorPagesFaults'),
          }
        ),
        alert.rule.new(
          'NodeMemoryHighUtilization',
          '100 - (node_memory_MemAvailable_bytes' + rsBrace + ' / node_memory_MemTotal_bytes' + rsBrace + ' * 100) > 90',
          '15m', 'warning', {},
          {
            summary: 'Host is running out of memory.',
            description: 'Memory is filling up at {{ $labels.instance }}, has been above 90% for the last 15 minutes, is currently at {{ printf "%.2f" $value }}%.',
            runbook_url: runbook('NodeMemoryHighUtilization'),
          }
        ),
        alert.rule.new(
          'NodeDiskIOSaturation',
          'rate(node_disk_io_time_weighted_seconds_total{device!=""' + rsComma + '}[5m]) > 10',
          '30m', 'warning', {},
          {
            summary: 'Disk IO queue is high.',
            description: 'Disk IO queue (aqu-sq) is high on {{ $labels.device }} at {{ $labels.instance }}, has been above 10 for the last 30 minutes, is currently at {{ printf "%.2f" $value }}.\nThis symptom might indicate disk saturation.',
            runbook_url: runbook('NodeDiskIOSaturation'),
          }
        ),
        // --- Systemd ---
        alert.rule.new(
          'NodeSystemdServiceFailed',
          'node_systemd_unit_state{state="failed"' + rsComma + '} == 1',
          '5m', 'warning', {},
          {
            summary: 'Systemd service has entered failed state.',
            description: 'Systemd service {{ $labels.name }} has entered failed state at {{ $labels.instance }}',
            runbook_url: runbook('NodeSystemdServiceFailed'),
          }
        ),
        alert.rule.new(
          'NodeSystemdServiceCrashlooping',
          'increase(node_systemd_service_restart_total' + rsBrace + '[5m]) > 2',
          '15m', 'warning', {},
          {
            summary: 'Systemd service keeps restaring, possibly crash looping.',
            description: 'Systemd service {{ $labels.name }} has being restarted too many times at {{ $labels.instance }} for the last 15 minutes. Please check if service is crash looping.',
            runbook_url: runbook('NodeSystemdServiceCrashlooping'),
          }
        ),
        // --- Bonding ---
        alert.rule.new(
          'NodeBondingDegraded',
          '(node_bonding_slaves' + rsBrace + ' - node_bonding_active' + rsBrace + ') != 0',
          '5m', 'warning', {},
          {
            summary: 'Bonding interface is degraded.',
            description: 'Bonding interface {{ $labels.master }} on {{ $labels.instance }} is in degraded state due to one or more slave failures.',
            runbook_url: runbook('NodeBondingDegraded'),
          }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('node.rules', [
        signals.cpuBusy.asRecordingRule('instance:node_cpu_utilisation:rate5m', cfg.ruleSelector),
        signals.loadPerCpu.asRecordingRule('instance:node_load1_per_cpu:ratio', cfg.ruleSelector),
        signals.memUsedRatio.asRecordingRule('instance:node_memory_utilisation:ratio', cfg.ruleSelector),
        signals.swapIoPages.asRecordingRule('instance:node_memory_swap_io_pages:rate5m', cfg.ruleSelector),
        signals.diskIo.asRecordingRule('instance_device:node_disk_io_time_seconds:rate5m', cfg.ruleSelector),
        signals.netRxExclLo.asRecordingRule('instance:node_network_receive_bytes_excluding_lo:rate5m', cfg.ruleSelector),
        signals.netTxExclLo.asRecordingRule('instance:node_network_transmit_bytes_excluding_lo:rate5m', cfg.ruleSelector),
      ]),
    ], [
      // optional exporter tabs — each renders only when its queries return data.
      {
        title: 'Proxmox',
        width: 8,
        height: 6,
        presence: { query: 'proxmox_node_up{node=~"$instance"}', label: 'node' },
        elements: {
          pveUp: signals.pveUp.asStat('PVE node up'),
          pveCpusAllocated: signals.pveCpusAllocated.asStat('vCPUs allocated'),
          pveMemAllocated: signals.pveMemAllocated.asStat('Memory allocated'),
        },
      },
      {
        title: 'Docker',
        width: 12,
        height: 7,
        presence: { query: 'container_last_seen{instance=~"$instance"}', label: 'instance' },
        elements: {
          dockerContainers: signals.dockerContainers.asStat('Containers'),
          dockerCpu: signals.dockerCpu.asTimeSeries('Container CPU'),
          dockerMem: signals.dockerMem.asTimeSeries('Container memory'),
        },
      },
      {
        title: 'Batocera',
        width: 12,
        height: 7,
        // gate on the presence of any batocera_*-prefixed series for this node
        // (a custom batocera exporter), not just the node_os_info OS marker.
        presence: { query: '{__name__=~"batocera_.+", instance=~"$instance"}', label: 'instance' },
        elements: {
          batoceraOs: signals.batoceraOs.asTable('Batocera OS'),
          batoceraTemp: signals.batoceraTemp.asTimeSeries('Temperature'),
        },
      },
      {
        title: 'ZFS',
        width: 12,
        height: 7,
        presence: { query: 'node_zfs_arc_size{instance=~"$instance"}', label: 'instance' },
        elements: {
          zfsArcSize: signals.zfsArcSize.asTimeSeries('ARC size'),
          zfsArcCMax: signals.zfsArcCMax.asTimeSeries('ARC target max'),
          zfsArcHitRatio: signals.zfsArcHitRatio.asTimeSeries('ARC hit ratio'),
          zfsArcHits: signals.zfsArcHits.asTimeSeries('ARC hits'),
          zfsArcMisses: signals.zfsArcMisses.asTimeSeries('ARC misses'),
        },
      },
      {
        title: 'NFS',
        width: 12,
        height: 7,
        presence: { query: 'node_nfs_rpcs_total{instance=~"$instance"}', label: 'instance' },
        elements: {
          nfsRpcs: signals.nfsRpcs.asTimeSeries('NFS RPCs'),
          nfsRetransmissions: signals.nfsRetransmissions.asTimeSeries('NFS RPC retransmissions'),
        },
      },
      {
        title: 'Battery',
        width: 12,
        height: 7,
        presence: { query: 'node_power_supply_capacity{instance=~"$instance"}', label: 'instance' },
        elements: {
          batteryCapacity: signals.batteryCapacity.asStat('Battery capacity'),
          batteryOnline: signals.batteryOnline.asStat('AC online'),
          batteryPower: signals.batteryPower.asTimeSeries('Power draw'),
          batteryVoltage: signals.batteryVoltage.asTimeSeries('Battery voltage'),
        },
      },
      {
        title: 'Services',
        width: 12,
        height: 7,
        presence: { query: 'node_systemd_unit_state{instance=~"$instance"}', label: 'instance' },
        elements: {
          servicesActive: signals.servicesActive.asStat('Active services'),
          servicesFailed: signals.servicesFailed.asTable('Failed services'),
        },
      },
      {
        title: 'Logs',
        width: 24,
        height: 10,
        elements: {
          journal: panel.logs.new('Journal') + panel.logs.withTargets([signals.nodeLogs.asTarget()]),
        },
      },
    ]),
}
