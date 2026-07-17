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
      dashboardTitle: 'Windows Server',
      dashboardTags: ['windows'],
      // fleet board: every Windows host in the selected cluster(s) at once.
      fleetUid: 'compute-windows-fleet',
      fleetTitle: 'Windows Fleet Overview',
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

    local signals = {
      // --- System ---
      uptime: sig('Uptime', 'time() - windows_system_boot_time_timestamp{%(queriesSelector)s}', 's'),

      // --- CPU ---
      cpuBusy: sig('CPU utilisation', '1 - avg without (core) (rate(windows_cpu_time_total{mode="idle",%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),

      // --- Memory (windows_exporter memory collector; `available` ~ Linux MemAvailable) ---
      memTotal: sig('Physical memory total', 'windows_memory_physical_total_bytes{%(queriesSelector)s}', 'bytes'),
      memAvailable: sig('Physical memory available', 'windows_memory_available_bytes{%(queriesSelector)s}', 'bytes'),
      memFree: sig('Physical memory free', 'windows_memory_physical_free_bytes{%(queriesSelector)s}', 'bytes'),
      memUsed: sig('Physical memory used', 'windows_memory_physical_total_bytes{%(queriesSelector)s} - windows_memory_available_bytes{%(queriesSelector)s}', 'bytes'),
      memUsedRatio: sig('Memory used ratio', '1 - windows_memory_available_bytes{%(queriesSelector)s} / windows_memory_physical_total_bytes{%(queriesSelector)s}', 'percentunit'),
      memCommitted: sig('Committed memory', 'windows_memory_committed_bytes{%(queriesSelector)s}', 'bytes'),

      // --- Disk ---
      diskFree: sig('Logical disk free', 'windows_logical_disk_free_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} / {{volume}}'),
      diskUsedRatio: sig('Logical disk used ratio', '1 - windows_logical_disk_free_bytes{%(queriesSelector)s} / windows_logical_disk_size_bytes{%(queriesSelector)s}', 'percentunit', '{{instance}} / {{volume}}'),

      // --- Network ---
      netRecv: sig('Network received', 'rate(windows_net_bytes_received_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{nic}}'),
      netSent: sig('Network sent', 'rate(windows_net_bytes_sent_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{nic}}'),

      // --- Applications (processes + Windows services) ---
      processes: sig('Processes', 'windows_system_processes{%(queriesSelector)s}', 'short'),
      servicesRunning: sig('Running services', 'count(windows_service_state{state="running",%(queriesSelector)s} == 1)', 'short', 'running'),
      serviceState: sig('Service states', 'windows_service_state{%(queriesSelector)s}', 'short', '{{name}} / {{state}}'),

      // --- Logs (Windows event log via Loki) ---
      winLogs: lsig('Windows event log', '{%(queriesSelector)s}'),
    };

    local main = pack.build(cfg, signals, [
      {
        title: 'System',
        width: 8,
        height: 6,
        elements: {
          uptime: signals.uptime.asStat('Uptime'),
          cpu: signals.cpuBusy.asStat('CPU utilisation'),
          memRatio: signals.memUsedRatio.asStat('Memory used ratio'),
        },
      },
      {
        title: 'CPU',
        width: 24,
        height: 7,
        elements: {
          cpuBusy: signals.cpuBusy.asTimeSeries('CPU utilisation'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memUsed: signals.memUsed.asTimeSeries('Physical memory used'),
          memAvailable: signals.memAvailable.asTimeSeries('Physical memory available'),
          memFree: signals.memFree.asTimeSeries('Physical memory free'),
          memTotal: signals.memTotal.asTimeSeries('Physical memory total'),
          memCommitted: signals.memCommitted.asTimeSeries('Committed memory'),
        },
      },
      {
        title: 'Disk',
        width: 12,
        height: 7,
        elements: {
          diskUsedRatio: signals.diskUsedRatio.asTable('Logical disk used ratio'),
          diskFree: signals.diskFree.asTimeSeries('Logical disk free'),
        },
      },
      {
        title: 'Network',
        width: 12,
        height: 7,
        elements: {
          netRecv: signals.netRecv.asTimeSeries('Network received'),
          netSent: signals.netSent.asTimeSeries('Network sent'),
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
      ]),
    ], [
      // recording rule group
      alert.rule.group('windows.rules', [
        alert.rule.record('instance:windows_cpu_utilisation:rate5m', '1 - avg without (core) (rate(windows_cpu_time_total{mode="idle"' + rsComma + '}[5m]))'),
        alert.rule.record('instance:windows_memory_utilisation:ratio', '1 - windows_memory_available_bytes' + rsBrace + ' / windows_memory_physical_total_bytes' + rsBrace),
        alert.rule.record('instance:windows_logical_disk_free_bytes:sum', 'sum without (volume) (windows_logical_disk_free_bytes' + rsBrace + ')'),
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
