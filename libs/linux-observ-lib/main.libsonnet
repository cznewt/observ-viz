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

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-linux',
      dashboardTitle: 'Linux node',
      dashboardTags: ['linux', 'node'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'node_uname_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      // runbook base; runbook_url = runbookBase + lower(name) -> the official
      // prometheus-operator runbooks (one page per alert).
      runbookBase: 'https://runbooks.prometheus-operator.dev/runbooks/node/',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local runbook(name) = cfg.runbookBase + std.asciiLower(name);

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      // --- CPU / Load ---
      cpuBusy: sig('CPU busy', '1 - avg without(cpu,mode)(rate(node_cpu_seconds_total{mode="idle",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      cpuUser: sig('CPU user', 'avg without(cpu)(rate(node_cpu_seconds_total{mode="user",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      cpuSystem: sig('CPU system', 'avg without(cpu)(rate(node_cpu_seconds_total{mode="system",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      cpuIowait: sig('CPU iowait', 'avg without(cpu)(rate(node_cpu_seconds_total{mode="iowait",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      cpuSteal: sig('CPU steal', 'avg without(cpu)(rate(node_cpu_seconds_total{mode="steal",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
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
      fsUsed: sig('Filesystem used', '1 - node_filesystem_avail_bytes{fstype!="",%(queriesSelector)s} / node_filesystem_size_bytes{fstype!="",%(queriesSelector)s}', 'percentunit'),
      fsAvail: sig('Filesystem available', 'node_filesystem_avail_bytes{fstype!="",%(queriesSelector)s}', 'bytes'),
      fsSize: sig('Filesystem size', 'node_filesystem_size_bytes{fstype!="",%(queriesSelector)s}', 'bytes'),
      inodesUsed: sig('Inodes used', '1 - node_filesystem_files_free{fstype!="",%(queriesSelector)s} / node_filesystem_files{fstype!="",%(queriesSelector)s}', 'percentunit'),

      // --- Disk IO ---
      diskReadBps: sig('Disk read', 'rate(node_disk_read_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
      diskWriteBps: sig('Disk write', 'rate(node_disk_written_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
      diskReadIops: sig('Disk read IOPS', 'rate(node_disk_reads_completed_total{%(queriesSelector)s}[$__rate_interval])', 'iops'),
      diskWriteIops: sig('Disk write IOPS', 'rate(node_disk_writes_completed_total{%(queriesSelector)s}[$__rate_interval])', 'iops'),
      diskIoLatency: sig('Disk IO latency', 'rate(node_disk_io_time_weighted_seconds_total{%(queriesSelector)s}[$__rate_interval])', 's'),
      diskIo: sig('Disk IO time', 'rate(node_disk_io_time_seconds_total{device!="",%(queriesSelector)s}[$__rate_interval])', 'percentunit'),

      // --- Network ---
      netRx: sig('Network received', 'rate(node_network_receive_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
      netTx: sig('Network transmitted', 'rate(node_network_transmit_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
      netRxErrs: sig('Network receive errors', 'rate(node_network_receive_errs_total{%(queriesSelector)s}[$__rate_interval])', 'pps'),
      netTxErrs: sig('Network transmit errors', 'rate(node_network_transmit_errs_total{%(queriesSelector)s}[$__rate_interval])', 'pps'),
      netRxDrop: sig('Network receive drops', 'rate(node_network_receive_drop_total{%(queriesSelector)s}[$__rate_interval])', 'pps'),
      netTxDrop: sig('Network transmit drops', 'rate(node_network_transmit_drop_total{%(queriesSelector)s}[$__rate_interval])', 'pps'),
      netRxExclLo: sig('Network received (excl lo)', 'sum without (device) (rate(node_network_receive_bytes_total{device!="lo",%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      netTxExclLo: sig('Network transmitted (excl lo)', 'sum without (device) (rate(node_network_transmit_bytes_total{device!="lo",%(queriesSelector)s}[$__rate_interval]))', 'Bps'),

      // --- System ---
      uptime: sig('Uptime', 'time() - node_boot_time_seconds{%(queriesSelector)s}', 's'),
      contextSwitches: sig('Context switches', 'rate(node_context_switches_total{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      fdUsed: sig('File descriptors used', 'node_filefd_allocated{%(queriesSelector)s}', 'short'),
      fdMax: sig('File descriptors max', 'node_filefd_maximum{%(queriesSelector)s}', 'short'),
      conntrackUsed: sig('Conntrack used', 'node_nf_conntrack_entries{%(queriesSelector)s}', 'short'),
      conntrackMax: sig('Conntrack max', 'node_nf_conntrack_entries_limit{%(queriesSelector)s}', 'short'),

      // --- Temperature (hardware) ---
      tempCelsius: sig('Temperature', 'node_hwmon_temp_celsius{%(queriesSelector)s}', 'celsius'),
      thermalZone: sig('Thermal zone', 'node_thermal_zone_temp{%(queriesSelector)s}', 'celsius'),
    };

    pack.build(cfg, signals, [
      {
        title: 'CPU / Load',
        width: 12,
        height: 7,
        elements: {
          cpuBusy: signals.cpuBusy.asTimeSeries('CPU busy'),
          cpuUser: signals.cpuUser.asTimeSeries('CPU user'),
          cpuSystem: signals.cpuSystem.asTimeSeries('CPU system'),
          cpuIowait: signals.cpuIowait.asTimeSeries('CPU iowait'),
          cpuSteal: signals.cpuSteal.asTimeSeries('CPU steal'),
          load1: signals.load1.asTimeSeries('Load 1m'),
          load5: signals.load5.asTimeSeries('Load 5m'),
          load15: signals.load15.asTimeSeries('Load 15m'),
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
        },
      },
      {
        title: 'Temperature',
        width: 12,
        height: 7,
        elements: {
          tempCelsius: signals.tempCelsius.asTimeSeries('Hardware temperature'),
          thermalZone: signals.thermalZone.asTimeSeries('Thermal zone'),
        },
      },
      {
        title: 'System',
        width: 12,
        height: 7,
        elements: {
          uptime: signals.uptime.asStat('Uptime'),
          contextSwitches: signals.contextSwitches.asTimeSeries('Context switches'),
          fdUsed: signals.fdUsed.asTimeSeries('File descriptors used'),
          conntrackUsed: signals.conntrackUsed.asTimeSeries('Conntrack used'),
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
    ]),
}
