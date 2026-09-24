// observ-viz Linux node pack (hand-written).
// Comprehensive node_exporter host observability: CPU/load, memory, disk space,
// disk IO, network, and system signals, plus the upstream prometheus node-mixin
// alerting rules and node.rules recording rules. Emitted as native v2 elements.
// Usage:
//   g.libs.system.linux.new({ selector: 'job="node"' }).grafana.dashboard
//   g.libs.system.linux.new({...}).grafana.elements   // reuse in a board
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local alertPanels = import 'libs/common-lib/alert/panels.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local tabs = import 'libs/common-lib/tabs.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local dockerLib = import 'libs/docker-observ-lib/main.libsonnet';
local kubeletLib = import 'libs/kubernetes-observ-lib/kubelet.libsonnet';
local syncthingLib = import 'libs/syncthing-observ-lib/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'compute-linux-overview',
      // back-link to the fleet view, keeping the selected cluster (node filter
      // reset to All so the whole cluster shows).
      links: [
        { title: 'Cluster boards', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
        { title: 'Node boards', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Node-level boards', tags: ['node-level'] },
        {
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
        },
      ],
      dashboardTitle: 'Linux Server',
      dashboardTags: ['linux', 'node', 'node-level'],
      description: 'One Linux host from node_exporter: facts and health tiles, then CPU, memory, disk, network, temperature and pressure rows, plus exporter tabs that appear only where their metrics exist (Proxmox, Docker, kubelet, Batocera, ZFS, NFS, battery, services, updates, logs).',
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
    local sig(name, expr, unit, legend='{{instance}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    // proxmox VE signals use the proxmox node correlation selector.
    local psig(name, expr, unit, legend='{{node}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.proxmoxSelector).withLegendFormat(legend).withDescription(desc);
    // docker/container signals (cadvisor, by node) + loki journal signals.
    local dsig(name, expr, unit, legend='{{pod}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.dockerSelector).withLegendFormat(legend).withDescription(desc);
    local lsig(name, expr, desc='') =
      signal.new(name, 'loki', '${loki_datasource}', expr, 'short').filteringSelector(cfg.logsSelector).withDescription(desc);

    local signals = {
      // --- CPU / Load ---
      cpuBusy: sig('CPU busy', '1 - avg without(cpu,mode)(rate(node_cpu_seconds_total{mode="idle",%(queriesSelector)s}[$__rate_interval]))', 'percentunit', desc='Share of CPU time not idle, averaged over all cores.'),
      // one aggregate signal: usage per CPU mode (user/system/iowait/steal/...) — one series per mode, stacked.
      cpuMode: sig('CPU by mode', 'avg without(cpu)(rate(node_cpu_seconds_total{mode!="idle",%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '{{instance}} / {{mode}}', desc='CPU time by mode (user, system, iowait, steal, irq...), stacked. Growing iowait means the disks are the bottleneck, steal means the hypervisor is.'),
      load1: sig('Load 1m', 'node_load1{%(queriesSelector)s}', 'short', '{{instance}} 1m', desc='Run-queue length averaged over 1, 5 and 15 minutes. Compare with the core count: above it, processes wait for CPU.'),
      load5: sig('Load 5m', 'node_load5{%(queriesSelector)s}', 'short', '{{instance}} 5m', desc='Load average over 5 minutes.'),
      load15: sig('Load 15m', 'node_load15{%(queriesSelector)s}', 'short', '{{instance}} 15m', desc='Load average over 15 minutes.'),
      loadPerCpu: sig('Load per core', 'node_load1{%(queriesSelector)s} / count without (cpu, mode) (node_cpu_seconds_total{mode="idle",%(queriesSelector)s})', 'short', desc='1-minute load divided by the number of cores. Above 1 the host is saturated.'),
      // --- Memory ---
      memUsed: sig('Memory used', 'node_memory_MemTotal_bytes{%(queriesSelector)s} - node_memory_MemAvailable_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} used', desc='Memory in use (total minus available), with page cache, buffers and free memory alongside. Cache and buffers are reclaimable.'),
      memAvailable: sig('Memory available', 'node_memory_MemAvailable_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} available', desc='Memory the kernel estimates it can give to new work without swapping, including reclaimable cache.'),
      memFree: sig('Memory free', 'node_memory_MemFree_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} free', desc='Completely unused memory. Low is normal on Linux: the kernel uses it for cache.'),
      memCached: sig('Memory cached', 'node_memory_Cached_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} cached', desc='Page cache. Reclaimable, so not a leak.'),
      memBuffers: sig('Memory buffers', 'node_memory_Buffers_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} buffers', desc='Kernel buffers for block devices.'),
      memUsedRatio: sig('Memory used ratio', '1 - node_memory_MemAvailable_bytes{%(queriesSelector)s} / node_memory_MemTotal_bytes{%(queriesSelector)s}', 'percentunit', desc='Memory in use as a share of total, counting reclaimable cache as available.'),
      swapUsed: sig('Swap used', 'node_memory_SwapTotal_bytes{%(queriesSelector)s} - node_memory_SwapFree_bytes{%(queriesSelector)s}', 'bytes', desc='Swap space in use. Growing swap on a server usually means memory is over-committed.'),
      swapIoPages: sig('Swap IO pages', 'rate(node_vmstat_pgpgin{%(queriesSelector)s}[$__rate_interval]) + rate(node_vmstat_pgpgout{%(queriesSelector)s}[$__rate_interval])', 'short', desc='Pages paged in and out from block devices per second (all IO through the page cache, not just swap).'),
      // --- Disk space / Filesystem ---
      fsUsed: sig('Filesystem used', '1 - node_filesystem_avail_bytes{fstype!="",%(queriesSelector)s} / node_filesystem_size_bytes{fstype!="",%(queriesSelector)s}', 'percentunit', '{{instance}} / {{mountpoint}}', desc='Used share of each mounted filesystem.'),
      fsAvail: sig('Filesystem available', 'node_filesystem_avail_bytes{fstype!="",%(queriesSelector)s}', 'bytes', '{{instance}} / {{mountpoint}}', desc='Free bytes on each filesystem, as available to non-root users.'),
      fsSize: sig('Filesystem size', 'node_filesystem_size_bytes{fstype!="",%(queriesSelector)s}', 'bytes', '{{instance}} / {{mountpoint}}', desc='Size of each filesystem.'),
      inodesUsed: sig('Inodes used', '1 - node_filesystem_files_free{fstype!="",%(queriesSelector)s} / node_filesystem_files{fstype!="",%(queriesSelector)s}', 'percentunit', '{{instance}} / {{mountpoint}}', desc='Used share of inodes per filesystem. A full inode table stops file creation with space still free.'),
      // --- Disk IO ---
      diskReadBps: sig('Disk read', 'rate(node_disk_read_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}} read', desc='Bytes read and written per second per block device.'),
      diskWriteBps: sig('Disk write', 'rate(node_disk_written_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}} write', desc='Bytes written per second per block device.'),
      diskReadIops: sig('Disk read IOPS', 'rate(node_disk_reads_completed_total{%(queriesSelector)s}[$__rate_interval])', 'iops', '{{instance}} / {{device}} read', desc='Read and write operations completed per second per block device.'),
      diskWriteIops: sig('Disk write IOPS', 'rate(node_disk_writes_completed_total{%(queriesSelector)s}[$__rate_interval])', 'iops', '{{instance}} / {{device}} write', desc='Write operations completed per second per block device.'),
      diskIoLatency: sig('Disk IO latency', 'rate(node_disk_io_time_weighted_seconds_total{%(queriesSelector)s}[$__rate_interval])', 's', '{{instance}} / {{device}}', desc='Weighted time spent doing IO per second: queue depth times service time. Rises before throughput drops.'),
      diskIo: sig('Disk IO time', 'rate(node_disk_io_time_seconds_total{device!="",%(queriesSelector)s}[$__rate_interval])', 'percentunit', '{{instance}} / {{device}}', desc='Share of time each device was busy with IO. Near 1 the device is saturated.'),
      // --- Network ---
      netRx: sig('Network received', 'rate(node_network_receive_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}} rx', desc='Bytes received and transmitted per second per interface.'),
      netTx: sig('Network transmitted', 'rate(node_network_transmit_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}} tx', desc='Bytes transmitted per second per interface.'),
      netRxErrs: sig('Network receive errors', 'rate(node_network_receive_errs_total{%(queriesSelector)s}[$__rate_interval])', 'pps', '{{instance}} / {{device}} rx errors', desc='Receive and transmit errors per second per interface. Any sustained value points at a cable, driver or duplex problem.'),
      netTxErrs: sig('Network transmit errors', 'rate(node_network_transmit_errs_total{%(queriesSelector)s}[$__rate_interval])', 'pps', '{{instance}} / {{device}} tx errors', desc='Transmit errors per second per interface.'),
      netRxDrop: sig('Network receive drops', 'rate(node_network_receive_drop_total{%(queriesSelector)s}[$__rate_interval])', 'pps', '{{instance}} / {{device}} rx drops', desc='Packets dropped per second on receive and transmit. Receive drops usually mean the host cannot keep up with the NIC.'),
      netTxDrop: sig('Network transmit drops', 'rate(node_network_transmit_drop_total{%(queriesSelector)s}[$__rate_interval])', 'pps', '{{instance}} / {{device}} tx drops', desc='Packets dropped per second on transmit.'),
      netRxExclLo: sig('Network received (excl lo)', 'sum without (device) (rate(node_network_receive_bytes_total{device!="lo",%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} rx', desc='Total bytes received and transmitted per second, loopback excluded.'),
      netTxExclLo: sig('Network transmitted (excl lo)', 'sum without (device) (rate(node_network_transmit_bytes_total{device!="lo",%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} tx', desc='Total bytes transmitted per second, loopback excluded.'),
      // --- System ---
      uptime: sig('Uptime', 'time() - node_boot_time_seconds{%(queriesSelector)s}', 's', desc='Time since the last boot.'),
      contextSwitches: sig('Context switches', 'rate(node_context_switches_total{%(queriesSelector)s}[$__rate_interval])', 'ops', desc='Context switches per second. A jump with flat load means threads fighting over locks or IO.'),
      fdUsed: sig('File descriptors used', 'node_filefd_allocated{%(queriesSelector)s}', 'short', '{{instance}} used', desc='File descriptors allocated system-wide against the kernel maximum (dashed).'),
      fdMax: sig('File descriptors max', 'node_filefd_maximum{%(queriesSelector)s}', 'short', '{{instance}} max', desc='Kernel-wide file descriptor limit.'),
      conntrackUsed: sig('Conntrack used', 'node_nf_conntrack_entries{%(queriesSelector)s}', 'short', '{{instance}} used', desc='Connection-tracking entries in use against the table limit (dashed). At the limit new connections are dropped.'),
      conntrackMax: sig('Conntrack max', 'node_nf_conntrack_entries_limit{%(queriesSelector)s}', 'short', '{{instance}} max', desc='Connection-tracking table size.'),
      // --- Temperature / power (hwmon, thermal_zone, rapl) ---
      tempCelsius: sig('Temperature', 'node_hwmon_temp_celsius{%(queriesSelector)s}', 'celsius', '{{instance}} / {{chip}} {{sensor}}', desc='Hardware monitor temperatures by chip and sensor.'),
      thermalZone: sig('Thermal zone', 'node_thermal_zone_temp{%(queriesSelector)s}', 'celsius', '{{instance}} / {{type}}', desc='Thermal zone temperatures reported by the kernel (ACPI, SoC).'),
      raplPower: sig('CPU package power', 'sum without (index, path) (rate(node_rapl_package_joules_total{%(queriesSelector)s}[$__rate_interval]))', 'watt', desc='CPU package power draw from RAPL counters.'),
      // --- CPU frequency / scheduler (cpufreq, schedstat) ---
      cpuFreq: sig('CPU frequency', 'avg without (cpu) (node_cpu_scaling_frequency_hertz{%(queriesSelector)s})', 'hertz', desc='Average current CPU frequency across cores. Pinned low under load means power capping or thermal throttling.'),
      schedWait: sig('Scheduler wait time', 'sum without (cpu) (rate(node_schedstat_waiting_seconds_total{%(queriesSelector)s}[$__rate_interval]))', 's', desc='Time runnable tasks spent waiting for a CPU per second, summed over cores.'),
      // --- Paging / faults (vmstat) ---
      pgFaults: sig('Page faults', 'rate(node_vmstat_pgfault{%(queriesSelector)s}[$__rate_interval])', 'short', '{{instance}} minor', desc='Minor and major page faults per second. Major faults read from disk and hurt.'),
      pgMajFaults: sig('Major page faults', 'rate(node_vmstat_pgmajfault{%(queriesSelector)s}[$__rate_interval])', 'short', '{{instance}} major', desc='Major page faults per second.'),
      swapIn: sig('Swap in', 'rate(node_vmstat_pswpin{%(queriesSelector)s}[$__rate_interval])', 'short', '{{instance}} in', desc='Pages swapped in and out per second. Any sustained swapping means memory pressure.'),
      swapOut: sig('Swap out', 'rate(node_vmstat_pswpout{%(queriesSelector)s}[$__rate_interval])', 'short', '{{instance}} out', desc='Pages swapped out per second.'),
      // --- Processes / entropy (stat, entropy) ---
      procsRunning: sig('Processes running', 'node_procs_running{%(queriesSelector)s}', 'short', desc='Processes currently runnable.'),
      procsBlocked: sig('Processes blocked (uninterruptible)', 'node_procs_blocked{%(queriesSelector)s}', 'short', desc='Processes in uninterruptible sleep, almost always waiting for disk IO.'),
      entropy: sig('Entropy available', 'node_entropy_available_bits{%(queriesSelector)s}', 'short', desc='Entropy available to the kernel random pool.'),
      // --- TCP / sockets / softnet (netstat, sockstat, softnet, udp_queues) ---
      tcpEstablished: sig('TCP established', 'node_netstat_Tcp_CurrEstab{%(queriesSelector)s}', 'short', desc='TCP connections in the ESTABLISHED state.'),
      tcpActiveOpens: sig('TCP active opens', 'rate(node_netstat_Tcp_ActiveOpens{%(queriesSelector)s}[$__rate_interval])', 'short', desc='Outgoing TCP connections opened per second.'),
      tcpRetrans: sig('TCP SYN retransmits', 'rate(node_netstat_TcpExt_TCPSynRetrans{%(queriesSelector)s}[$__rate_interval])', 'short', desc='SYN retransmits per second: connection attempts that got no answer.'),
      tcpInErrs: sig('TCP in errors', 'rate(node_netstat_Tcp_InErrs{%(queriesSelector)s}[$__rate_interval])', 'short', desc='TCP segments received in error per second (bad checksum, malformed).'),
      socketsTcp: sig('TCP sockets in use', 'node_sockstat_TCP_inuse{%(queriesSelector)s}', 'short', desc='TCP sockets in use.'),
      socketsMem: sig('TCP socket memory', 'node_sockstat_TCP_mem_bytes{%(queriesSelector)s}', 'bytes', desc='Memory used by TCP socket buffers.'),
      softnetDropped: sig('Softnet dropped', 'sum without (cpu) (rate(node_softnet_dropped_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{instance}} dropped', desc='Packets dropped and softirq budget exhaustions (squeezed) per second in the network receive path.'),
      softnetSqueezed: sig('Softnet times squeezed', 'sum without (cpu) (rate(node_softnet_times_squeezed_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{instance}} squeezed', desc='Times the softirq receive budget ran out per second.'),
      udpQueues: sig('UDP queue', 'node_udp_queues{%(queriesSelector)s}', 'bytes', '{{instance}} / {{queue}}', desc='Bytes queued in UDP receive and transmit queues.'),
      // --- Pressure stall information (collector: pressure / PSI) ---
      psiCpu: sig('CPU pressure', 'rate(node_pressure_cpu_waiting_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit', desc='Share of time some tasks waited for a CPU (pressure stall information).'),
      psiMem: sig('Memory pressure (some)', 'rate(node_pressure_memory_waiting_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit', '{{instance}} some', desc='Share of time some tasks (some) and all tasks (full) stalled on memory.'),
      psiMemFull: sig('Memory pressure (full)', 'rate(node_pressure_memory_stalled_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit', '{{instance}} full', desc='Share of time every task was stalled on memory.'),
      psiIo: sig('IO pressure (some)', 'rate(node_pressure_io_waiting_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit', '{{instance}} some', desc='Share of time some tasks (some) and all tasks (full) stalled on IO.'),
      psiIoFull: sig('IO pressure (full)', 'rate(node_pressure_io_stalled_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'percentunit', '{{instance}} full', desc='Share of time every task was stalled on IO.'),
      // --- Proxmox VE (optional tab; renders only on PVE hosts via showIfData) ---
      pveUp: psig('PVE node up', 'proxmox_node_up{%(queriesSelector)s}', 'short', desc='Proxmox VE reports the node online.'),
      pveCpusAllocated: psig('vCPUs allocated', 'proxmox_node_cpus_allocated{%(queriesSelector)s}', 'short', desc='vCPUs allocated to guests on this Proxmox node.'),
      pveMemAllocated: psig('Memory allocated', 'proxmox_node_memory_allocated_bytes{%(queriesSelector)s}', 'bytes', desc='Memory allocated to guests on this Proxmox node.'),
      // --- Docker / containers (optional tab; cadvisor, by node) ---
      dockerContainers: dsig('Containers', 'count(container_last_seen{%(queriesSelector)s})', 'short', 'containers', desc='Containers cAdvisor sees on this host.'),
      dockerCpu: dsig('Container CPU', 'sum by (pod) (rate(container_cpu_usage_seconds_total{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='CPU cores used per container on this host.'),
      dockerMem: dsig('Container memory', 'sum by (pod) (container_memory_usage_bytes{%(queriesSelector)s})', 'bytes', desc='Memory used per container on this host.'),
      // --- Services (optional tab; node_exporter systemd collector) ---
      servicesActive: sig('Active services', 'sum(node_systemd_unit_state{state="active",%(queriesSelector)s})', 'short', 'active', desc='systemd units in the active state.'),
      servicesFailed: sig('Failed services', 'node_systemd_unit_state{state="failed",%(queriesSelector)s} == 1', 'short', '{{name}}', desc='systemd units in the failed state.'),
      // --- Batocera (optional tab; gated on presence of batocera_* metrics) ---
      batoceraOs: signal.new('Batocera', 'prometheus', cfg.datasource, 'node_os_info{id=~"batocera", instance=~"$instance"}', 'short').withLegendFormat('{{instance}} {{pretty_name}}').withDescription('Batocera release running on this host.'),
      batoceraTemp: signal.new('Batocera temperature', 'prometheus', cfg.datasource, 'node_hwmon_temp_celsius{instance=~"$instance"} and on (instance) node_os_info{id=~"batocera"}', 'celsius').withLegendFormat('{{instance}} / {{chip}}').withDescription('Hardware temperatures on Batocera hosts.'),

      // --- ZFS ARC (optional tab; zfs collector, gated on presence) ---
      zfsArcSize: sig('ZFS ARC size', 'node_zfs_arc_size{%(queriesSelector)s}', 'bytes', desc='Current size of the ZFS ARC read cache.'),
      zfsArcCMax: sig('ZFS ARC target max', 'node_zfs_arc_c_max{%(queriesSelector)s}', 'bytes', desc='Configured maximum size of the ARC.'),
      zfsArcHitRatio: sig('ZFS ARC hit ratio', 'rate(node_zfs_arc_hits{%(queriesSelector)s}[$__rate_interval]) / clamp_min(rate(node_zfs_arc_hits{%(queriesSelector)s}[$__rate_interval]) + rate(node_zfs_arc_misses{%(queriesSelector)s}[$__rate_interval]), 1)', 'percentunit', desc='Share of ARC lookups served from cache.'),
      zfsArcHits: sig('ZFS ARC hits', 'rate(node_zfs_arc_hits{%(queriesSelector)s}[$__rate_interval])', 'short', desc='ARC cache hits per second.'),
      zfsArcMisses: sig('ZFS ARC misses', 'rate(node_zfs_arc_misses{%(queriesSelector)s}[$__rate_interval])', 'short', desc='ARC cache misses per second (reads that went to disk).'),
      // --- NFS client (optional tab; nfs collector, gated on presence) ---
      nfsRpcs: sig('NFS RPCs', 'rate(node_nfs_rpcs_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='NFS client RPC calls per second.'),
      nfsRetransmissions: sig('NFS RPC retransmissions', 'rate(node_nfs_rpc_retransmissions_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='NFS RPC retransmissions per second. Above zero the NFS server or the network is lagging.'),
      // --- Battery / power supply (optional tab; powersupplyclass collector, gated) ---
      batteryCapacity: sig('Battery capacity', 'node_power_supply_capacity{%(queriesSelector)s}', 'percent', '{{instance}} / {{power_supply}}', desc='Battery charge in percent.'),
      batteryOnline: sig('AC online', 'node_power_supply_online{%(queriesSelector)s}', 'short', '{{instance}} / {{power_supply}}', desc='AC adapter connected (1) or on battery (0).'),
      batteryPower: sig('Power draw', 'node_power_supply_power_watt{%(queriesSelector)s}', 'watt', '{{instance}} / {{power_supply}}', desc='Power drawn from or delivered to the battery.'),
      batteryVoltage: sig('Battery voltage', 'node_power_supply_voltage_volt{%(queriesSelector)s}', 'volt', '{{instance}} / {{power_supply}}', desc='Battery voltage.'),
      // --- Updates / expiry (optional tab) ---
      // apt_* + x509_* + batocerapkg_* come from the salt alloy formula's
      // textfile collectors (node-textfile-metrics.timer); pacman_updates_pending
      // is batocera's own (misc-alloy). All are "silent breakage" signals: an
      // expired repo key or cert fails apt/kubelet long before anyone notices.
      updatesPending: sig('Updates pending', 'sum without (origin, arch) (apt_upgrades_pending{%(queriesSelector)s}) or pacman_updates_pending{%(queriesSelector)s}', 'short', desc='Packages with pending upgrades (apt on Debian-likes, pacman on Batocera).'),
      updatesByOrigin: sig('Updates by origin', 'apt_upgrades_pending{%(queriesSelector)s}', 'short', '{{origin}}', desc='Pending upgrades by repository origin.'),
      updatesSecurity: sig('Security updates', 'apt_security_upgrades_pending{%(queriesSelector)s}', 'short', desc='Pending upgrades from security repositories.'),
      updatesAutoremove: sig('Autoremovable', 'apt_autoremove_pending{%(queriesSelector)s}', 'short', desc='Packages that apt would autoremove.'),
      rebootRequired: sig('Reboot required', 'node_reboot_required{%(queriesSelector)s}', 'short', desc='The package manager flagged that a reboot is needed (new kernel or libc).'),
      packageListAge: sig('Package list age', 'time() - apt_package_cache_timestamp_seconds{%(queriesSelector)s}', 's', desc='Time since the package lists were last refreshed.'),
      gamePackages: sig('Game packages installed', 'batocerapkg_packages_installed{%(queriesSelector)s}', 'short', desc='Batocera game packages installed.'),
      gameUpdatesPending: sig('Game updates pending', 'batocerapkg_updates_pending{%(queriesSelector)s} or pacman_updates_pending{%(queriesSelector)s}', 'short', desc='Batocera game packages with pending updates.'),
      keyringExpiry: sig('Repo key expires in', 'apt_keyring_expiry_timestamp_seconds{%(queriesSelector)s} - time()', 's', '{{keyring}}', desc='Time until each apt repository signing key expires. Expired keys silently break updates.'),
      certExpiry: sig('Certificate expires in', 'x509_cert_expiry_timestamp_seconds{%(queriesSelector)s} - time()', 's', '{{subject}}', desc='Time until each monitored certificate expires.'),
      // --- Logs (optional tab; loki journal for the node) ---
      nodeLogs: lsig('Journal', '{%(queriesSelector)s}', desc='systemd journal of this host, from Loki.'),
    };

    local query = import 'custom/query.libsonnet';
    local iq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    // label-value stat tile (shows a label like pretty_name instead of the value)
    local labelStat(title, expr, field, desc='') =
      panel.stat.new(title)
      + (if desc != '' then panel.withDescription(desc) else {})
      + panel.stat.withTargets([iq(expr)])
      + panel.stat.withOptions({ reduceOptions: { values: true, fields: '/^' + field + '$/' }, colorMode: 'none' });
    local numStat(title, expr, unit, desc='') =
      panel.stat.new(title)
      + (if desc != '' then panel.withDescription(desc) else {})
      + panel.stat.withTargets([iq(expr)])
      + panel.stat.withOptions({ reduceOptions: { values: false, calcs: ['lastNotNull'] }, colorMode: 'value' })
      + panel.stat.withUnit(unit);
    local inst = 'instance=~"$instance"';
    local dashed(regex) = panel.withOverrides([{
      matcher: { id: 'byRegexp', options: regex },
      properties: [
        { id: 'custom.lineStyle', value: { fill: 'dash', dash: [10, 10] } },
        { id: 'custom.fillOpacity', value: 0 },
      ],
    }]);
    local main = pack.build(cfg, signals, [
      // generic system facts, mirroring the cluster-detail tables.
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          ovDevice: labelStat('Device', 'sum by (device) (label_join((label_replace(node_dmi_info{' + inst + ', product_version!~"Default string|System Version|System Product Name|To Be Filled.*|"}, "dev", "$1", "product_version", "(.+)")) or (label_replace(node_dmi_info{' + inst + ', product_version=~"Default string|System Version|System Product Name|To Be Filled.*|"}, "dev", "$1", "product_name", "(.+)")), "device", " ", "system_vendor", "dev"))', 'device', desc='Vendor and model from DMI, or the product name when the version is a placeholder.'),
          ovOs: labelStat('OS', 'node_os_info{' + inst + '}', 'pretty_name', desc='Operating system from /etc/os-release.'),
          ovKernel: labelStat('Kernel', 'node_uname_info{' + inst + '}', 'release', desc='Running kernel release.'),
          ovModel: labelStat('CPU Model', 'sum by (model_name) (node_cpu_info{model_name!="", ' + inst + '})', 'model_name', desc='CPU model.'),
          ovArch: labelStat('Arch', 'node_uname_info{' + inst + '}', 'machine', desc='Machine architecture.'),
          ovType: labelStat('Type', 'label_replace(label_replace(sum by (product_name) (node_dmi_info{' + inst + '}), "kind", "physical", "", ""), "kind", "virtual", "product_name", "Standard PC.*|KVM.*|.*[Vv]irtual.*|VMware.*|Bochs.*")', 'kind', desc='Physical machine or a virtual machine (guessed from the DMI product name).'),
          ovCores: numStat('Cores', 'count(node_cpu_seconds_total{mode="idle", ' + inst + '})', 'short', desc='Logical CPU cores.'),
          ovMem: numStat('Memory', 'max(node_memory_MemTotal_bytes{' + inst + '})', 'bytes', desc='Installed memory.'),
          ovUptime: numStat('Uptime', 'max(time() - node_boot_time_seconds{' + inst + '})', 'dtdurations', desc='Time since the last boot.'),
          ovLoad: numStat('Load 1m', 'max(node_load1{' + inst + '})', 'short', desc='1-minute load average.'),
          ovTemp: numStat('CPU Temp', 'max(node_hwmon_temp_celsius{chip=~".*coretemp.*|.*k10temp.*|.*zenpower.*|.*cpu_thermal.*|pci0000:00_0000:00:18_3", ' + inst + '})', 'celsius', desc='CPU package temperature from the platform sensor (coretemp, k10temp, zenpower, cpu_thermal).')
                  + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 60 }, { color: 'red', value: 80 }]),
        },
      },
      // health tiles: the stats that used to sit inside the chart rows.
      {
        title: 'Health',
        width: 4,
        height: 4,
        elements: {
          hlUptime: signals.uptime.asStat('Uptime') + panel.stat.withUnit('dtdurations'),
          hlCpuBusy: signals.cpuBusy.asStat('CPU busy')
                     + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.7 }, { color: 'red', value: 0.9 }]),
          hlMemUsed: signals.memUsedRatio.asStat('Memory used')
                     + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.8 }, { color: 'red', value: 0.95 }]),
          hlProcsRunning: signals.procsRunning.asStat('Processes running'),
          hlProcsBlocked: signals.procsBlocked.asStat('Processes blocked')
                          + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 1 }, { color: 'red', value: 5 }]),
          hlLoadPerCpu: signals.loadPerCpu.asStat('Load per core')
                        + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.7 }, { color: 'red', value: 1 }]),
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
          load: signals.load1.asTimeSeries('Load average 1m / 5m / 15m')
                + panel.withTargetsMixin([signals.load5.asTarget(), signals.load15.asTarget()]),
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
          memBreakdown: signals.memUsed.asTimeSeries('Memory: used / cached / buffers / free')
                        + panel.withTargetsMixin([signals.memCached.asTarget(), signals.memBuffers.asTarget(), signals.memFree.asTarget()])
                        + { spec+: { vizConfig+: { spec+: { fieldConfig+: { defaults+: { custom+: { stacking: { mode: 'normal', group: 'A' } } } } } } } },
          memAvailable: signals.memAvailable.asTimeSeries('Memory available'),
          swapUsed: signals.swapUsed.asTimeSeries('Swap used'),
          pgFaults: signals.pgFaults.asTimeSeries('Page faults minor / major')
                    + panel.withTargetsMixin([signals.pgMajFaults.asTarget()]),
          swapIo: signals.swapIn.asTimeSeries('Swap in / out')
                  + panel.withTargetsMixin([signals.swapOut.asTarget()]),
          swapIoPages: signals.swapIoPages.asTimeSeries('Paging IO'),
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
          diskBps: signals.diskReadBps.asTimeSeries('Disk read / write')
                   + panel.withTargetsMixin([signals.diskWriteBps.asTarget()]),
          diskIops: signals.diskReadIops.asTimeSeries('Disk IOPS read / write')
                    + panel.withTargetsMixin([signals.diskWriteIops.asTarget()]),
          diskIoLatency: signals.diskIoLatency.asTimeSeries('Disk IO latency'),
          diskIo: signals.diskIo.asTimeSeries('Disk IO utilization'),
        },
      },
      {
        title: 'Network',
        width: 12,
        height: 7,
        elements: {
          netTraffic: signals.netRx.asTimeSeries('Network rx / tx')
                      + panel.withTargetsMixin([signals.netTx.asTarget()]),
          netExclLo: signals.netRxExclLo.asTimeSeries('Network total rx / tx (excl. lo)')
                     + panel.withTargetsMixin([signals.netTxExclLo.asTarget()]),
          netErrs: signals.netRxErrs.asTimeSeries('Network errors')
                   + panel.withTargetsMixin([signals.netTxErrs.asTarget()]),
          netDrops: signals.netRxDrop.asTimeSeries('Network drops')
                    + panel.withTargetsMixin([signals.netTxDrop.asTarget()]),
          tcpEstablished: signals.tcpEstablished.asTimeSeries('TCP established'),
          tcpActiveOpens: signals.tcpActiveOpens.asTimeSeries('TCP active opens'),
          tcpRetrans: signals.tcpRetrans.asTimeSeries('TCP SYN retransmits'),
          tcpInErrs: signals.tcpInErrs.asTimeSeries('TCP in errors'),
          socketsTcp: signals.socketsTcp.asTimeSeries('TCP sockets in use'),
          socketsMem: signals.socketsMem.asTimeSeries('TCP socket memory'),
          softnet: signals.softnetDropped.asTimeSeries('Softnet dropped / squeezed')
                   + panel.withTargetsMixin([signals.softnetSqueezed.asTarget()]),
          udpQueues: signals.udpQueues.asTimeSeries('UDP queue'),
        },
      },
      {
        title: 'System',
        width: 12,
        height: 7,
        elements: {
          contextSwitches: signals.contextSwitches.asTimeSeries('Context switches'),
          fds: signals.fdUsed.asTimeSeries('File descriptors used / max')
               + panel.withTargetsMixin([signals.fdMax.asTarget()])
               + dashed('/ max$/'),
          conntrack: signals.conntrackUsed.asTimeSeries('Conntrack used / max')
                     + panel.withTargetsMixin([signals.conntrackMax.asTarget()])
                     + dashed('/ max$/'),
          entropy: signals.entropy.asTimeSeries('Entropy available'),
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
          psiMem: signals.psiMem.asTimeSeries('Memory pressure some / full')
                  + panel.withTargetsMixin([signals.psiMemFull.asTarget()]),
          psiIo: signals.psiIo.asTimeSeries('IO pressure some / full')
                 + panel.withTargetsMixin([signals.psiIoFull.asTarget()]),
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
          '1h',
          'warning',
          {},
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
          '1h',
          'critical',
          {},
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
          '30m',
          'warning',
          {},
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
          '30m',
          'critical',
          {},
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
          '1h',
          'warning',
          {},
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
          '1h',
          'critical',
          {},
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
          '1h',
          'warning',
          {},
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
          '1h',
          'critical',
          {},
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
          '1h',
          'warning',
          {},
          {
            summary: 'Network interface is reporting many receive errors.',
            description: '{{ $labels.instance }} interface {{ $labels.device }} has encountered {{ printf "%.0f" $value }} receive errors in the last two minutes.',
            runbook_url: runbook('NodeNetworkReceiveErrs'),
          }
        ),
        alert.rule.new(
          'NodeNetworkTransmitErrs',
          'rate(node_network_transmit_errs_total' + rsBrace + '[2m]) / rate(node_network_transmit_packets_total' + rsBrace + '[2m]) > 0.01',
          '1h',
          'warning',
          {},
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
          '0m',
          'warning',
          {},
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
          '0m',
          'warning',
          {},
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
          '10m',
          'warning',
          {},
          {
            summary: 'Clock skew detected.',
            description: 'Clock at {{ $labels.instance }} is out of sync by more than 0.05s. Ensure NTP is configured correctly on this host.',
            runbook_url: runbook('NodeClockSkewDetected'),
          }
        ),
        alert.rule.new(
          'NodeClockNotSynchronising',
          'min_over_time(node_timex_sync_status' + rsBrace + '[5m]) == 0\nand\nnode_timex_maxerror_seconds' + rsBrace + ' >= 16',
          '10m',
          'warning',
          {},
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
          '15m',
          'critical',
          {},
          {
            summary: 'RAID Array is degraded.',
            description: "RAID array '{{ $labels.device }}' at {{ $labels.instance }} is in degraded state due to one or more disks failures. Number of spare drives is insufficient to fix issue automatically.",
            runbook_url: runbook('NodeRAIDDegraded'),
          }
        ),
        alert.rule.new(
          'NodeRAIDDiskFailure',
          'node_md_disks{state="failed",device!=""' + rsComma + '} > 0',
          '0m',
          'warning',
          {},
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
          '15m',
          'warning',
          {},
          {
            summary: 'Kernel is predicted to exhaust file descriptors limit soon.',
            description: 'File descriptors limit at {{ $labels.instance }} is currently at {{ printf "%.2f" $value }}%.',
            runbook_url: runbook('NodeFileDescriptorLimit'),
          }
        ),
        alert.rule.new(
          'NodeFileDescriptorLimit',
          '(\n  node_filefd_allocated' + rsBrace + ' * 100 / node_filefd_maximum' + rsBrace + ' > 90\n)',
          '15m',
          'critical',
          {},
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
          '15m',
          'info',
          {},
          {
            summary: 'High CPU usage.',
            description: 'CPU usage at {{ $labels.instance }} has been above 90% for the last 15 minutes, is currently at {{ printf "%.2f" $value }}%.',
            runbook_url: runbook('NodeCPUHighUsage'),
          }
        ),
        alert.rule.new(
          'NodeSystemSaturation',
          'node_load1' + rsBrace + '\n/ count without (cpu, mode) (node_cpu_seconds_total{mode="idle"' + rsComma + '}) > 2',
          '15m',
          'warning',
          {},
          {
            summary: 'System saturated, load per core is very high.',
            description: 'System load per core at {{ $labels.instance }} has been above 2 for the last 15 minutes, is currently at {{ printf "%.2f" $value }}.\nThis might indicate this instance resources saturation and can cause it becoming unresponsive.',
            runbook_url: runbook('NodeSystemSaturation'),
          }
        ),
        alert.rule.new(
          'NodeMemoryMajorPagesFaults',
          'rate(node_vmstat_pgmajfault' + rsBrace + '[5m]) > 500',
          '15m',
          'warning',
          {},
          {
            summary: 'Memory major page faults are occurring at very high rate.',
            description: 'Memory major pages are occurring at very high rate at {{ $labels.instance }}, 500 major page faults per second for the last 15 minutes, is currently at {{ printf "%.2f" $value }}.\nPlease check that there is enough memory available at this instance.',
            runbook_url: runbook('NodeMemoryMajorPagesFaults'),
          }
        ),
        alert.rule.new(
          'NodeMemoryHighUtilization',
          '100 - (node_memory_MemAvailable_bytes' + rsBrace + ' / node_memory_MemTotal_bytes' + rsBrace + ' * 100) > 90',
          '15m',
          'warning',
          {},
          {
            summary: 'Host is running out of memory.',
            description: 'Memory is filling up at {{ $labels.instance }}, has been above 90% for the last 15 minutes, is currently at {{ printf "%.2f" $value }}%.',
            runbook_url: runbook('NodeMemoryHighUtilization'),
          }
        ),
        alert.rule.new(
          'NodeDiskIOSaturation',
          'rate(node_disk_io_time_weighted_seconds_total{device!=""' + rsComma + '}[5m]) > 10',
          '30m',
          'warning',
          {},
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
          '5m',
          'warning',
          {},
          {
            summary: 'Systemd service has entered failed state.',
            description: 'Systemd service {{ $labels.name }} has entered failed state at {{ $labels.instance }}',
            runbook_url: runbook('NodeSystemdServiceFailed'),
          }
        ),
        alert.rule.new(
          'NodeSystemdServiceCrashlooping',
          'increase(node_systemd_service_restart_total' + rsBrace + '[5m]) > 2',
          '15m',
          'warning',
          {},
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
          '5m',
          'warning',
          {},
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
        // panels come from the docker observ-lib (its full element set, scoped
        // to this node) rather than a handwritten subset.
        elements:
          local dl = dockerLib.new({ datasource: cfg.datasource, selector: 'instance=~"$instance"', docTabs: false }).grafana.elements;
          { ['docker_' + k]: dl[k] for k in std.objectFields(dl) if std.substr(k, 0, 4) != 'doc_' },
      },
      {
        title: 'Kubelet',
        width: 12,
        height: 7,
        presence: { query: 'kubelet_running_pods{instance=~"$instance"}', label: 'instance' },
        // panels from the kubernetes lib's kubelet module — shown only on
        // nodes actually running a kubelet.
        elements: kubeletLib.elements(cfg.datasource, 'instance=~"$instance"'),
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
        title: 'Share',
        width: 12,
        height: 7,
        presence: { query: 'syncthing_connections_active{instance=~"$instance"}', label: 'instance' },
        // panels from the syncthing observ-lib, scoped to this node — the pack's
        // own $job var means syncthing there, which is not this board's $job
        elements:
          local st = syncthingLib.new({ datasource: cfg.datasource, selector: 'instance=~"$instance"', docTabs: false }).grafana.elements;
          { ['st_' + k]: st[k] for k in std.objectFields(st) if std.substr(k, 0, 4) != 'doc_' },
      },
      {
        title: 'Services',
        width: 12,
        height: 7,
        presence: { query: 'node_systemd_unit_state{instance=~"$instance"}', label: 'instance' },
        elements: {
          // curated units (collector-side allowlist: salt/alloy/ssh/docker/
          // kubelet/gdm/...) — one row per unit, colored by state.
          svcTimeline:
            panel.base('state-timeline', 'Service state')
            + panel.withTargets([
              query.prometheus.new(cfg.datasource, 'max by (name) ((node_systemd_unit_state{state="active", instance=~"$instance"} == 1) * 1 or (node_systemd_unit_state{state="activating", instance=~"$instance"} == 1) * 2 or (node_systemd_unit_state{state="deactivating", instance=~"$instance"} == 1) * 2 or (node_systemd_unit_state{state="inactive", instance=~"$instance"} == 1) * 3 or (node_systemd_unit_state{state="failed", instance=~"$instance"} == 1) * 4)')
              + query.prometheus.withLegendFormat('{{name}}'),
            ])
            + panel.withOptions({ legend: { showLegend: true, displayMode: 'list', placement: 'bottom' }, rowHeight: 0.85 })
            + panel.withFieldConfigDefaults({ custom: { fillOpacity: 72, lineWidth: 0 } })
            + panel.withMappings([{ type: 'value', options: {
              '1': { text: 'active', color: 'green', index: 0 },
              '2': { text: 'transitioning', color: 'yellow', index: 1 },
              '3': { text: 'inactive', color: 'text', index: 2 },
              '4': { text: 'failed', color: 'red', index: 3 },
            } }]),
          servicesActive: signals.servicesActive.asStat('Active services'),
          servicesFailed: signals.servicesFailed.asTable('Failed services'),
        },
      },
      {
        title: 'Updates',
        width: 12,
        height: 7,
        // any node carrying the textfile collectors (deb) or batocera's pacman
        // exporter. `or` so one probe covers both fleets.
        presence: { query: 'apt_upgrades_pending{instance=~"$instance"} or pacman_updates_pending{instance=~"$instance"} or apt_keyring_expiry_timestamp_seconds{instance=~"$instance"}', label: 'instance' },
        elements: {
          updPending: signals.updatesPending.asStat('Updates pending')
                      + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'yellow', value: 1 }, { color: 'orange', value: 25 }]),
          updSecurity: signals.updatesSecurity.asStat('Security updates')
                       + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]),
          updReboot: numStat('Reboot required', 'max(node_reboot_required{' + inst + '})', 'short')
                     + panel.stat.withMappings([{ type: 'value', options: {
                       '0': { text: 'no', color: 'green', index: 0 },
                       '1': { text: 'REBOOT', color: 'red', index: 1 },
                     } }]),
          updListAge: signals.packageListAge.asStat('Package list age')
                      + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'yellow', value: 172800 }, { color: 'orange', value: 604800 }]),
          updAutoremove: signals.updatesAutoremove.asStat('Autoremovable'),
          updGamePending: signals.gameUpdatesPending.asStat('Game updates pending'),
          // trend, so a growing backlog (or a stuck unattended-upgrades) is visible
          updTrend: signals.updatesByOrigin.asTimeSeries('Pending updates by origin'),
          // expiry tables: seconds remaining, red once inside the danger window
          updKeyring: signals.keyringExpiry.asTable('Repo signing keys')
                      + panel.table.withUnit('s')
                      + panel.table.withThresholds([{ color: 'red', value: null }, { color: 'orange', value: 2592000 }, { color: 'green', value: 7776000 }]),
          updCerts: signals.certExpiry.asTable('Certificates')
                    + panel.table.withUnit('s')
                    + panel.table.withThresholds([{ color: 'red', value: null }, { color: 'orange', value: 1814400 }, { color: 'green', value: 5184000 }]),
        },
      },
      {
        title: 'Logs',
        width: 24,
        height: 10,
        elements: {
          journal: panel.logs.new('Journal') + panel.withDescription(signals.nodeLogs._description) + panel.logs.withTargets([signals.nodeLogs.asTarget()]),
        },
      },
      {
        title: 'Alerts',
        width: 24,
        height: 10,
        alwaysShow: true,
        elements: {
          nodeAlertList: alertPanels.list('Alerts', instanceFilter='{instance=~"$instance"}', groupMode='custom', groupBy=['alertname'])
                         + panel.withDescription('Alert instances for this host as Grafana sees them, grouped by rule.'),
          // the list only knows Grafana-managed rules; this reads the ALERTS
          // series, which is what a Mimir or Prometheus ruler writes
          nodeAlertFiring: alertPanels.firingTable('Firing alerts', cfg.datasource, 'instance=~"$instance"'),
          nodeAlertTimeline: alertPanels.timeline('Alert state', cfg.datasource, 'instance=~"$instance"')
                             + panel.withDescription('Every alert rule touching this host over time: pending, then firing coloured by severity.'),
        },
      },
    ]);

    // ── Linux Computers (fleet board): every host at once — one row per node,
    //    drilling into the per-host board above. node_exporter mirror of the
    //    windows-observ-lib fleet board.
    local fleetCfg = cfg {
      uid: 'linux-computers',
      dashboardTitle: 'Linux Computers',
      dashboardTags: ['linux', 'fleet', 'overview', 'cluster-level'],
      // fleet-wide: cluster is multi-select (defaults to All) and there is no
      // $instance — a row's Instance cell drills into the per-host board instead.
      selector: 'job=~"$job", cluster=~"$cluster"',
      varLabels: ['cluster'],
      varMulti: true,
      primaryTabTitle: 'Fleet',
      lokiDatasource: false,  // no logs on this board -> no Loki variable
      docTabs: false,  // Signals/Runbooks already ship on the per-host board
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster boards', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
    };
    local fs = fleetCfg.selector;
    local byNode = 'by (cluster, instance)';
    // pseudo-filesystems must not drive the fleet's max() disk column
    local realFs = ', fstype!~"tmpfs|ramfs|overlay|squashfs|iso9660"';

    local fsig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', fleetCfg.datasource, expr, unit).filteringSelector(fs).withLegendFormat(legend);
    // instant table query (labels -> columns, one Value per target), as in common-lib/base.
    local ftq(expr) =
      query.prometheus.new(fleetCfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local fov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };

    local fleetSignals = {
      fCpu: fsig('CPU utilisation', '1 - avg ' + byNode + ' (rate(node_cpu_seconds_total{mode="idle", %(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      fMem: fsig('Memory utilisation', '1 - avg ' + byNode + ' (node_memory_MemAvailable_bytes{%(queriesSelector)s}) / avg ' + byNode + ' (node_memory_MemTotal_bytes{%(queriesSelector)s})', 'percentunit'),
      fNetSent: fsig('Network sent', 'max ' + byNode + ' (rate(node_network_transmit_bytes_total{%(queriesSelector)s, device!~"lo|veth.*"}[$__rate_interval]))', 'Bps', '{{instance}} / sent'),
      fNetRecv: fsig('Network received', 'max ' + byNode + ' (rate(node_network_receive_bytes_total{%(queriesSelector)s, device!~"lo|veth.*"}[$__rate_interval]))', 'Bps', '{{instance}} / received'),
      fDiskRead: fsig('Disk read', 'max ' + byNode + ' (rate(node_disk_read_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} / read'),
      fDiskWrite: fsig('Disk write', 'max ' + byNode + ' (rate(node_disk_written_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} / write'),
      fDiskReadIops: fsig('Disk read IOPS', 'max ' + byNode + ' (rate(node_disk_reads_completed_total{%(queriesSelector)s}[$__rate_interval]))', 'iops', '{{instance}} / read'),
      fDiskWriteIops: fsig('Disk write IOPS', 'max ' + byNode + ' (rate(node_disk_writes_completed_total{%(queriesSelector)s}[$__rate_interval]))', 'iops', '{{instance}} / write'),
    };

    // one row per host, joined from instant queries. A carries no value — it is
    // here for its nodename (hostname) / pretty_name (OS) labels only.
    local fleetTable =
      panel.table.new('Servers')
      + panel.table.withTargets([
        ftq('node_uname_info{' + fs + '} * on (cluster, instance) group_left(pretty_name) node_os_info{' + fs + '}'),
        ftq('max ' + byNode + ' (time() - node_boot_time_seconds{' + fs + '})'),
        ftq('count ' + byNode + ' (node_cpu_seconds_total{mode="idle", ' + fs + '})'),
        ftq('(1 - avg ' + byNode + ' (rate(node_cpu_seconds_total{mode="idle", ' + fs + '}[$__rate_interval]))) * 100'),
        ftq('max ' + byNode + ' (node_memory_MemTotal_bytes{' + fs + '})'),
        ftq('(1 - avg ' + byNode + ' (node_memory_MemAvailable_bytes{' + fs + '}) / avg ' + byNode + ' (node_memory_MemTotal_bytes{' + fs + '})) * 100'),
        ftq('max ' + byNode + ' ((1 - node_filesystem_avail_bytes{' + fs + realFs + '} / node_filesystem_size_bytes{' + fs + realFs + '}) * 100)'),
        ftq('max ' + byNode + ' (node_procs_running{' + fs + '})'),
        ftq('max ' + byNode + ' (node_load1{' + fs + '})'),
        // J/K are RANGE queries on purpose: timeSeriesTable turns each series
        // into a "Trend #<refId>" frame column that renders as a sparkline, so
        // a growing patch backlog is visible per host without leaving the board.
        // `or pacman_updates_pending` folds the batocera fleet into one column.
        query.prometheus.new(fleetCfg.datasource, 'sum ' + byNode + ' (apt_upgrades_pending{' + fs + '}) or max ' + byNode + ' (pacman_updates_pending{' + fs + '})'),
        query.prometheus.new(fleetCfg.datasource, 'max ' + byNode + ' (apt_security_upgrades_pending{' + fs + '})'),
      ])
      + panel.table.withTransformations([
        { id: 'timeSeriesTable', options: {} },
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: [
          'cluster',
          'instance',
          'nodename',
          'pretty_name',
          'Value #B',
          'Value #C',
          'Value #D',
          'Value #E',
          'Value #F',
          'Value #G',
          'Value #H',
          'Value #I',
          'Trend #J',
          'Trend #K',
        ] } } },
        { id: 'seriesToColumns', options: { byField: 'instance' } },
        { id: 'organize', options: {
          // the join repeats the cluster column once per extra target.
          excludeByName: { 'Value #A': true } + { ['cluster ' + i]: true for i in std.range(2, 9) },
          indexByName: {
            cluster: 0,
            instance: 1,
            nodename: 2,
            pretty_name: 3,
            'Value #B': 4,
            'Value #C': 5,
            'Value #D': 6,
            'Value #E': 7,
            'Value #F': 8,
            'Value #G': 9,
            'Value #H': 10,
            'Value #I': 11,
            'Trend #J': 12,
            'Trend #K': 13,
          },
          renameByName: {
            cluster: 'Cluster',
            instance: 'Instance',
            nodename: 'Hostname',
            pretty_name: 'OS',
            'Value #B': 'Uptime',
            'Value #C': 'Cores',
            'Value #D': 'CPU %',
            'Value #E': 'Memory',
            'Value #F': 'Mem %',
            'Value #G': 'Disk %',
            'Value #H': 'Processes',
            'Value #I': 'Load 1m',
            'Trend #J': 'Updates',
            'Trend #K': 'Security',
          },
        } },
      ])
      + panel.table.withOverrides([
        // drill straight to the per-host board, carrying cluster + datasource.
        fov('^Instance$', [{ id: 'links', value: [{
          title: 'Drill into ${__value.raw}',
          url: '/d/' + cfg.uid + '?var-cluster=${__data.fields["Cluster"]}&var-instance=${__value.raw}&${datasource:queryparam}',
        }] }]),
        fov('^Uptime$', [{ id: 'unit', value: 'dtdurations' }]),
        fov('^Memory$', [{ id: 'unit', value: 'bytes' }]),
        fov('^Load 1m$', [{ id: 'decimals', value: 2 }]),
        fov('CPU %|Mem %|Disk %', [
          { id: 'unit', value: 'percent' },
          { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } },
          { id: 'min', value: 0 },
          { id: 'max', value: 100 },
        ]),
        // pending-patch backlog per host, as a sparkline + its current value
        fov('^Updates$', [
          { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16, gradientMode: 'scheme' } },
          { id: 'custom.width', value: 130 },
          { id: 'color', value: { mode: 'fixed', fixedColor: 'blue' } },
          { id: 'min', value: 0 },
        ]),
        fov('^Security$', [
          { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16, gradientMode: 'scheme' } },
          { id: 'custom.width', value: 130 },
          { id: 'color', value: { mode: 'fixed', fixedColor: 'red' } },
          { id: 'min', value: 0 },
        ]),
      ]);

    local fts(title, targets, unit) =
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
          fleetNet: fts('Network by host (busiest NIC)', [fleetSignals.fNetSent.asTarget(), fleetSignals.fNetRecv.asTarget()], 'Bps'),
          fleetDiskBytes: fts('Disk read/write by host', [fleetSignals.fDiskRead.asTarget(), fleetSignals.fDiskWrite.asTarget()], 'Bps'),
          fleetDiskIops: fts('Disk IO by host', [fleetSignals.fDiskReadIops.asTarget(), fleetSignals.fDiskWriteIops.asTarget()], 'iops'),
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
