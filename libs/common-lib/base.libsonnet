// observ-viz base/cluster fleet boards (hand-written; ported from the base-mixin).
// A two-tier overview, emitted as native v2:
//   base.home.new()    Base / Home    — clusters + applications count tables (env-level)
//   base.cluster.new() Base / Cluster — workload + linux-servers tables (per cluster)
// Tables use instant table queries + seriesToColumns transforms (counts/stats joined
// into columns), with drill-through links (cluster -> Base/Cluster, node -> Linux node).
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local layout = import 'custom/layout.libsonnet';
local grid = import 'custom/util/grid.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alertPanels = import 'libs/common-lib/alert/panels.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { datasource: gv.datasource + cv.datasource, query: gv.query + cv.query };

local defaults = {
  clusterLabel: 'cluster',
  nodeLabel: 'instance',
  appLabel: 'app_part_of',  // workload grouping label (e.g. app_part_of / app / namespace)
  nodeMetric: 'node_uname_info',  // an info metric every node_exporter exports (node count + release)
  windowsNodeMetric: 'windows_os_info',  // windows_exporter OS info (node count + version)
  selector: '',  // optional base label filter, e.g. 'job=~".+"'
  datasource: '${datasource}',
  uidHome: 'base-home',
  uidCluster: 'base-cluster',
  uidClusterDetail: 'cluster-detail',
  nodeUid: 'compute-linux-overview',  // per-node board for Linux node drill-through
  windowsNodeUid: 'compute-windows-overview',  // per-node board for Windows node drill-through
  tags: ['base'],
};

// ---- helpers ----
local selBrace(c) = '{' + c.selector + '}';
local selComma(c) = if c.selector != '' then ', ' + c.selector else '';
local clComma(c) = c.selector + (if c.selector != '' then ', ' else '') + c.clusterLabel + '=~"$cluster"';
// require a non-empty cluster label (+ base selector) so rows without a cluster
// label are dropped: clBrace -> whole selector, clAnd -> trailing matcher.
local clBrace(c) = '{' + c.clusterLabel + '=~".+"' + selComma(c) + '}';
local clAnd(c) = ', ' + c.clusterLabel + '=~".+"' + selComma(c);

local tq(c, expr) =
  query.prometheus.new(c.datasource, expr)
  + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };

local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };

local dsVar =
  variable.datasource.new('datasource', 'prometheus') + variable.datasource.withLabel('Data source');
local clusterVar(c, multi=true) =
  variable.query.new('cluster')
  + variable.query.withLabel('Cluster')
  + variable.query.withLabelValues(c.clusterLabel, c.nodeMetric + selBrace(c))
  + (if multi then variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent else {});
// hidden all-nodes variable (Linux + Windows) — drives grid-item repeats.
local instanceVar(c) =
  variable.query.new('instance')
  + variable.query.withLabel('Node')
  + variable.query.withLabelValues(c.nodeLabel, '{__name__=~"' + c.nodeMetric + '|' + c.windowsNodeMetric + '", ' + clComma(c) + '}')
  + variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent
  + { spec+: { hide: 'hideVariable' } };

// rows-of-grids (or tabs) layout (same shape as pack.build). A group either
// wraps its elements uniformly (width/height) or brings explicit grid items
// (mixed sizes / per-item repeat).
local gridOf(g) =
  layout.grid.new() + layout.grid.withItems(
    if std.objectHas(g, 'items') then g.items
    else grid.wrapItems(std.objectFields(g.elements), g.width, g.height)
  );
local board(uid, title, tags, vars, groups, asTabs=false) =
  dashboard.new(title)
  + dashboard.withUid(uid)
  + dashboard.withTags(tags)
  + dashboard.withVariables(vars)
  + dashboard.withElements(std.foldl(function(acc, g) acc + g.elements, groups, {}))
  + dashboard.withLayout(
    if asTabs then
      layout.tabs.new() + layout.tabs.withTabs([layout.tabs.tab(g.title, gridOf(g)) for g in groups])
    else
      layout.rows.new() + layout.rows.withRows([layout.rows.row(g.title, gridOf(g)) for g in groups])
  );

// count-by table: two count() queries (A=count, B=alerts) joined into columns.
local countTable(c, title, byLabel, countExpr, alertExpr, names) =
  panel.table.new(title)
  + panel.table.withTargets([tq(c, countExpr), tq(c, alertExpr)])
  + panel.table.withTransformations([
    // prometheus instant frames keep labels as metadata, not columns -> promote them
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: [byLabel, 'Value #A', 'Value #B'] } } },
    { id: 'seriesToColumns', options: { byField: byLabel } },
    { id: 'organize', options: {
      indexByName: { [byLabel]: 0, 'Value #A': 1, 'Value #B': 2 },
      renameByName: { [byLabel]: names[0], 'Value #A': names[1], 'Value #B': names[2] },
    } },
  ]);

// per-node Servers table: Linux (node_exporter) + Windows (windows_exporter) unioned,
// per-OS drill link via a hidden board column. Shared by cluster (default flavor:
// Cluster + Uptime columns) and clusterDetail (capacity flavor: CPUs / CPU Model /
// Memory-total columns instead; the cluster var is single-select there, so the
// Cluster column is hidden but kept for the drill link).
// CPU Model sources: node_cpu_info (needs the node_exporter cpu.info collector,
// off in our alloy unix module today) or OhmGraphite's hardware label on Windows.
local serversTable(c, capacity=false) =
  local nl = c.nodeLabel;
  local cl = c.clusterLabel;
  local s = clComma(c);
  local byNode = 'by (' + cl + ', ' + nl + ')';
  local qInfo =
    tq(c, '(sum by (' + cl + ', ' + nl + ', release, board) (label_replace(' + c.nodeMetric + '{' + s + '}, "board", "' + c.nodeUid + '", "", ""))) or '
        + '(sum by (' + cl + ', ' + nl + ', release, board) (label_replace(label_replace(' + c.windowsNodeMetric + '{' + s + '}, "release", "$1", "version", "(.+)"), "board", "' + c.windowsNodeUid + '", "", "")))');
  local qCpuPct =
    tq(c, '((1 - avg ' + byNode + ' (rate(node_cpu_seconds_total{mode="idle", ' + s + '}[5m]))) * 100) or '
        + '((1 - avg ' + byNode + ' (rate(windows_cpu_time_total{mode="idle", ' + s + '}[5m]))) * 100)');
  local qMemPct =
    tq(c, '((1 - avg ' + byNode + ' (node_memory_MemAvailable_bytes{' + s + '}) / avg ' + byNode + ' (node_memory_MemTotal_bytes{' + s + '})) * 100) or '
        + '((1 - avg ' + byNode + ' (windows_memory_available_bytes{' + s + '}) / avg ' + byNode + ' (windows_memory_physical_total_bytes{' + s + '})) * 100)');
  local qUptime =
    tq(c, '(max ' + byNode + ' (time() - node_boot_time_seconds{' + s + '})) or '
        + '(max ' + byNode + ' (time() - windows_system_boot_time_timestamp{' + s + '}))');
  local qOs =
    tq(c, '(sum by (' + cl + ', ' + nl + ', pretty_name) (node_os_info{' + s + '})) or '
        + '(sum by (' + cl + ', ' + nl + ', pretty_name) (label_replace(' + c.windowsNodeMetric + '{' + s + '}, "pretty_name", "$1", "product", "(.+)")))');
  local qCpus =
    tq(c, '(count ' + byNode + ' (node_cpu_seconds_total{mode="idle", ' + s + '})) or '
        + '(count ' + byNode + ' (windows_cpu_time_total{mode="idle", ' + s + '}))');
  local qModel =
    tq(c, '(sum by (' + cl + ', ' + nl + ', model_name) (node_cpu_info{' + s + '})) or '
        + '(sum by (' + cl + ', ' + nl + ', model_name) (label_replace(ohm_cpu_hertz{' + s + '}, "model_name", "$1", "hardware", "(.+)")))');
  local qMemTotal =
    tq(c, '(max ' + byNode + ' (node_memory_MemTotal_bytes{' + s + '})) or '
        + '(max ' + byNode + ' (windows_memory_physical_total_bytes{' + s + '}))');
  panel.table.new('Servers')
  // refIds by position — default: A info, B cpu%, C mem%, D uptime, E os;
  // capacity: A info, B cpu%, C mem%, D cpus, E model, F mem-total, G os.
  + panel.table.withTargets(
    [qInfo, qCpuPct, qMemPct]
    + (if capacity then [qCpus, qModel, qMemTotal] else [qUptime])
    + [qOs]
  )
  + panel.table.withTransformations([
    { id: 'labelsToFields' },
    // the cluster label is deliberately NOT included: no Cluster column (in any
    // join-suffixed variant) reaches the table — drill links carry the cluster
    // via the dashboard variable instead.
    { id: 'filterFieldsByName', options: { include: { names:
      [nl, 'pretty_name', 'release', 'board', 'Value #B', 'Value #C', 'Value #D']
      + (if capacity then ['model_name', 'Value #F'] else []) } } },
    { id: 'seriesToColumns', options: { byField: nl } },
    { id: 'organize', options:
      if capacity then {
        excludeByName: { 'Value #A': true, 'Value #E': true, 'Value #G': true },
        indexByName: { [nl]: 0, pretty_name: 1, release: 2, 'Value #B': 3, 'Value #D': 4, model_name: 5, 'Value #C': 6, 'Value #F': 7, board: 8 },
        renameByName: { [nl]: 'Node', pretty_name: 'OS', release: 'Release', 'Value #D': 'CPUs', model_name: 'CPU Model', 'Value #B': 'CPU %', 'Value #F': 'Memory', 'Value #C': 'Mem %', board: 'Board' },
      } else {
        excludeByName: { 'Value #A': true, 'Value #E': true },
        indexByName: { [nl]: 0, pretty_name: 1, release: 2, 'Value #B': 3, 'Value #C': 4, 'Value #D': 5, board: 6 },
        renameByName: { [nl]: 'Node', pretty_name: 'OS', release: 'Release', 'Value #B': 'CPU', 'Value #C': 'Memory', 'Value #D': 'Uptime', board: 'Board' },
      } },
  ])
  + panel.table.withOverrides(
    // drill link: cluster comes from the dashboard variable (single value on the
    // detail board; on the multi-cluster overview "All" still resolves the node
    // via the fleet-unique var-instance).
    [ov('Node', [{ id: 'links', value: [{ title: '${__value.raw}', url: '/d/${__data.fields["Board"]}?${cluster:queryparam}&var-instance=${__value.raw}' }] }])]
    + (if capacity then [
         ov('CPU %|Mem %', [{ id: 'unit', value: 'percent' }, { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } }, { id: 'min', value: 0 }, { id: 'max', value: 100 }]),
         ov('CPUs', [{ id: 'custom.width', value: 60 }]),
         ov('CPU Model', [{ id: 'custom.width', value: 320 }]),
         ov('Memory', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 110 }]),
       ] else [
         ov('Uptime', [{ id: 'unit', value: 'dtdurations' }]),
         ov('CPU|Memory', [{ id: 'unit', value: 'percent' }, { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } }, { id: 'min', value: 0 }, { id: 'max', value: 100 }]),
       ])
    + [ov('Board', [{ id: 'custom.hidden', value: true }])]
  );

// per-filesystem Partitions table (clusterDetail Storage tab): Linux
// node_filesystem (fstype!="") + Windows logical disks (volume relabeled to
// device+mountpoint) unioned. Rows are (node, device, mount) tuples, so the
// used%/capacity queries join on a synthetic key label (node|device|mount)
// instead of a single natural column; the key is hidden after the join.
// Sorted worst-used first.
local partitionsTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c);
  local joinKey = '"key", "|", "' + nl + '", "device", "mountpoint"';
  local winRelabel(expr) = 'label_replace(label_replace(' + expr + ', "device", "$1", "volume", "(.+)"), "mountpoint", "$1", "volume", "(.+)")';
  local fsSel = 'fstype!="", mountpoint!~"/(boot|media).*", ' + s;  // skip EFI/boot + removable mounts
  local winSel = 'volume!~"HarddiskVolume.*", ' + s;  // skip letterless recovery/EFI partitions
  panel.table.new('Partitions')
  + panel.table.withTargets([
    tq(c, '(label_join((1 - node_filesystem_avail_bytes{' + fsSel + '} / node_filesystem_size_bytes{' + fsSel + '}) * 100, ' + joinKey + ')) or '
        + '(label_join(' + winRelabel('(1 - windows_logical_disk_free_bytes{' + winSel + '} / windows_logical_disk_size_bytes{' + winSel + '}) * 100') + ', ' + joinKey + '))'),
    tq(c, '(sum by (key) (label_join(node_filesystem_size_bytes{' + fsSel + '}, ' + joinKey + '))) or '
        + '(sum by (key) (label_join(' + winRelabel('windows_logical_disk_size_bytes{' + winSel + '}') + ', ' + joinKey + ')))'),
  ])
  + panel.table.withTransformations([
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: ['key', 'device', 'mountpoint', nl, 'Value #A', 'Value #B'] } } },
    { id: 'seriesToColumns', options: { byField: 'key' } },
    { id: 'organize', options: {
      excludeByName: { key: true },
      indexByName: { device: 0, mountpoint: 1, 'Value #A': 2, 'Value #B': 3, [nl]: 4 },
      renameByName: { device: 'Name', mountpoint: 'Mount', 'Value #A': 'Used %', 'Value #B': 'Capacity', [nl]: 'Node' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Used %', desc: true }] } },
  ])
  + panel.table.withOverrides([
    ov('Used %', [{ id: 'unit', value: 'percent' }, { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } }, { id: 'min', value: 0 }, { id: 'max', value: 100 }]),
    ov('Capacity', [{ id: 'unit', value: 'bytes' }]),
  ]);

// per-GPU table (clusterDetail Compute tab): OhmGraphite ohm_gpu<vendor>_*
// series (Windows boxes with the hardware_sensors pillar; hardware label = GPU
// model; families gpunvidia/gpuati/gpuintel). Rows anchor on the load family
// (the one every vendor exports); temp/power stay blank where the silicon has
// no such sensor (iGPUs). Sensor names differ per vendor, hence the regex
// unions collapsed with max by key. Joined on a synthetic node|gpu|slot key.
local gpusTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c);
  local joinKey = '"key", "|", "' + nl + '", "hardware", "hw_instance"';
  local g(suffix, sensorRe) = '{__name__=~"ohm_gpu.*_' + suffix + '", sensor=~"' + sensorRe + '", ' + s + '}';
  local keyed(suffix, sensorRe) = 'max by (key) (label_join(' + g(suffix, sensorRe) + ', ' + joinKey + '))';
  panel.table.new('GPUs')
  + panel.table.withTargets([
    tq(c, 'label_join(count by (' + c.clusterLabel + ', ' + nl + ', hardware, hw_instance) ({__name__=~"ohm_gpu.*_load_percent", ' + s + '}), ' + joinKey + ')'),
    tq(c, keyed('celsius', 'GPU Core')),
    tq(c, keyed('load_percent', 'GPU Core|D3D 3D')),
    tq(c, '100 * ' + keyed('bytes', 'GPU Memory Used|D3D Shared Memory Used') + ' / ' + keyed('bytes', 'GPU Memory Total|D3D Shared Memory Total')),
    tq(c, keyed('bytes', 'GPU Memory Total|D3D Shared Memory Total')),
    tq(c, keyed('watts', 'GPU Package|GPU Power')),
  ])
  + panel.table.withTransformations([
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: ['key', nl, 'hardware', 'Value #B', 'Value #C', 'Value #D', 'Value #E', 'Value #F'] } } },
    { id: 'seriesToColumns', options: { byField: 'key' } },
    { id: 'organize', options: {
      excludeByName: { key: true, 'Value #A': true },
      indexByName: { [nl]: 0, hardware: 1, 'Value #B': 2, 'Value #C': 3, 'Value #E': 4, 'Value #D': 5, 'Value #F': 6 },
      renameByName: { [nl]: 'Node', hardware: 'GPU', 'Value #B': 'Temp', 'Value #C': 'Load %', 'Value #E': 'Memory', 'Value #D': 'Mem %', 'Value #F': 'Power' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('GPU', [{ id: 'custom.width', value: 320 }]),
    ov('Temp', [{ id: 'unit', value: 'celsius' }, { id: 'custom.width', value: 70 }]),
    ov('Load %|Mem %', [{ id: 'unit', value: 'percent' }, { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } }, { id: 'min', value: 0 }, { id: 'max', value: 100 }]),
    ov('Memory', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 110 }]),
    ov('Power', [{ id: 'unit', value: 'watt' }, { id: 'custom.width', value: 80 }]),
  ]);

// physical Disks table (clusterDetail Storage tab): drive name + temperature.
// Linux: node_hwmon nvme/drivetemp chips (composite sensor temp1; chip id as
// the name — node_exporter has no model label). Windows: OhmGraphite
// ohm_hdd_celsius (hardware label = disk model, composite sensor). One union
// query, no join. Hottest first.
local diskTempsTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c);
  panel.table.new('Disks')
  + panel.table.withTargets([
    tq(c, '(label_replace(label_replace(max by (' + nl + ', chip) (node_hwmon_temp_celsius{chip=~"nvme.*|drivetemp.*", sensor="temp1", ' + s + '}), "disk", "$1", "chip", "(.+)"), "disk", "$1", "chip", "nvme_(.+)")) or '
        + '(label_replace(max by (' + nl + ', hardware) (ohm_hdd_celsius{sensor="Temperature", ' + s + '}), "disk", "$1", "hardware", "(.+)"))'),
  ])
  + panel.table.withTransformations([
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: [nl, 'disk', 'Value', 'Value #A'] } } },
    { id: 'organize', options: {
      indexByName: { [nl]: 0, disk: 1, Value: 2, 'Value #A': 2 },
      renameByName: { [nl]: 'Node', disk: 'Disk', Value: 'Temp', 'Value #A': 'Temp' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Temp', desc: true }] } },
  ])
  + panel.table.withOverrides([
    ov('Temp', [{ id: 'unit', value: 'celsius' }]),
  ]);

// per-NIC table (clusterDetail Network tab): Linux node_network (device!="lo")
// + Windows adapters (nic label relabeled to device) unioned; In/Out are 5m
// byte rates joined on a synthetic node|device key. Busiest inbound first.
local nicsTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c);
  local joinKey = '"key", "|", "' + nl + '", "device"';
  local lx(m) = 'sum by (' + nl + ', device) (rate(' + m + '{device!="lo", ' + s + '}[5m]))';
  local wx(m) = 'label_replace(sum by (' + nl + ', nic) (rate(' + m + '{' + s + '}[5m])), "device", "$1", "nic", "(.+)")';
  panel.table.new('Network Interfaces')
  + panel.table.withTargets([
    tq(c, '(label_join(' + lx('node_network_receive_bytes_total') + ', ' + joinKey + ')) or (label_join(' + wx('windows_net_bytes_received_total') + ', ' + joinKey + '))'),
    tq(c, 'sum by (key) ((label_join(' + lx('node_network_transmit_bytes_total') + ', ' + joinKey + ')) or (label_join(' + wx('windows_net_bytes_sent_total') + ', ' + joinKey + ')))'),
  ])
  + panel.table.withTransformations([
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: ['key', nl, 'device', 'Value #A', 'Value #B'] } } },
    { id: 'seriesToColumns', options: { byField: 'key' } },
    { id: 'organize', options: {
      excludeByName: { key: true },
      indexByName: { [nl]: 0, device: 1, 'Value #A': 2, 'Value #B': 3 },
      renameByName: { [nl]: 'Node', device: 'NIC', 'Value #A': 'In', 'Value #B': 'Out' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'In', desc: true }] } },
  ])
  + panel.table.withOverrides([
    ov('In|Out', [{ id: 'unit', value: 'Bps' }]),
  ]);

// per-node Used/Free storage pie (clusterDetail Storage tab): the grid item
// repeats over the hidden $instance variable, one clone per node. Same
// /boot|/media exclusion as the Disks table so the numbers line up.
local storagePie(c) =
  local nl = c.nodeLabel;
  local si = 'fstype!="", mountpoint!~"/(boot|media).*", ' + clComma(c) + ', ' + nl + '=~"$instance"';
  local wi = clComma(c) + ', ' + nl + '=~"$instance"';
  local pq(expr, legend) =
    query.prometheus.new(c.datasource, expr)
    + query.prometheus.withLegendFormat(legend)
    + { spec+: { query+: { spec+: { instant: true, range: false } } } };
  panel.pieChart.new('Storage $instance')
  + panel.pieChart.withTargets([
    pq('(sum(node_filesystem_size_bytes{' + si + '}) - sum(node_filesystem_avail_bytes{' + si + '})) or '
       + '(sum(windows_logical_disk_size_bytes{' + wi + '}) - sum(windows_logical_disk_free_bytes{' + wi + '}))', 'Used'),
    pq('(sum(node_filesystem_avail_bytes{' + si + '})) or (sum(windows_logical_disk_free_bytes{' + wi + '}))', 'Free'),
  ])
  + panel.pieChart.withUnit('bytes')
  + panel.pieChart.withOptions({
    reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
    pieType: 'pie',
    displayLabels: ['percent'],
    legend: { showLegend: true, displayMode: 'list', placement: 'bottom' },
    tooltip: { mode: 'single' },
  })
  + panel.pieChart.withOverrides([
    ov('Used', [{ id: 'color', value: { mode: 'fixed', fixedColor: 'red' } }]),
    ov('Free', [{ id: 'color', value: { mode: 'fixed', fixedColor: 'green' } }]),
  ]);

{
  config:: defaults,

  home:: {
    new(config={}):
      local c = defaults + config;
      // Clusters table: nodes + total CPUs + cluster CPU% gauge + total memory +
      // cluster Mem% gauge + firing alerts, joined per cluster (count node_cpu idle
      // series = cores; sum MemTotal = RAM bytes; CPU%/Mem% aggregated like the
      // per-node Servers table, but averaged/summed across the whole cluster).
      local clusters =
        panel.table.new('Clusters')
        + panel.table.withTargets([
          tq(c, 'count((' + c.nodeMetric + clBrace(c) + ') or (' + c.windowsNodeMetric + clBrace(c) + ')) by (' + c.clusterLabel + ')'),
          tq(c, 'count(ALERTS{alertstate="firing"' + clAnd(c) + '}) by (' + c.clusterLabel + ')'),
          tq(c, 'count((node_cpu_seconds_total{mode="idle"' + clAnd(c) + '}) or (windows_cpu_time_total{mode="idle"' + clAnd(c) + '})) by (' + c.clusterLabel + ')'),
          tq(c, 'sum((node_memory_MemTotal_bytes' + clBrace(c) + ') or (windows_memory_physical_total_bytes' + clBrace(c) + ')) by (' + c.clusterLabel + ')'),
          tq(c, '(1 - avg by (' + c.clusterLabel + ') ((rate(node_cpu_seconds_total{mode="idle"' + clAnd(c) + '}[5m])) or (rate(windows_cpu_time_total{mode="idle"' + clAnd(c) + '}[5m])))) * 100'),
          tq(c, '(1 - sum by (' + c.clusterLabel + ') ((node_memory_MemAvailable_bytes' + clBrace(c) + ') or (windows_memory_available_bytes' + clBrace(c) + ')) / sum by (' + c.clusterLabel + ') ((node_memory_MemTotal_bytes' + clBrace(c) + ') or (windows_memory_physical_total_bytes' + clBrace(c) + '))) * 100'),
        ])
        + panel.table.withTransformations([
          { id: 'labelsToFields' },
          { id: 'filterFieldsByName', options: { include: { names: [c.clusterLabel, 'Value #A', 'Value #B', 'Value #C', 'Value #D', 'Value #E', 'Value #F'] } } },
          { id: 'seriesToColumns', options: { byField: c.clusterLabel } },
          { id: 'organize', options: {
            indexByName: { [c.clusterLabel]: 0, 'Value #A': 1, 'Value #C': 2, 'Value #E': 3, 'Value #D': 4, 'Value #F': 5, 'Value #B': 6 },
            renameByName: { [c.clusterLabel]: 'Cluster', 'Value #A': 'Nodes', 'Value #B': 'Alerts', 'Value #C': 'CPUs', 'Value #D': 'Memory', 'Value #E': 'CPU %', 'Value #F': 'Mem %' },
          } },
        ])
        + panel.table.withOverrides([
          ov('Cluster', [{ id: 'links', value: [{ title: '${__value.raw}', url: '/d/' + c.uidCluster + '?var-cluster=${__value.raw}' }] }]),
          ov('Memory', [{ id: 'unit', value: 'bytes' }]),
          ov('CPU %|Mem %', [{ id: 'unit', value: 'percent' }, { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } }, { id: 'min', value: 0 }, { id: 'max', value: 100 }]),
        ]);
      // env-wide firing/pending alert instances (its own tab).
      local alerts = alertPanels.list('Alerts', groupMode='custom', groupBy=[c.clusterLabel]);
      local apps =
        countTable(
          c, 'Applications', c.appLabel,
          'count(up{' + c.appLabel + '=~".+"' + selComma(c) + '}) by (' + c.appLabel + ')',
          'count(ALERTS{alertstate="firing", ' + c.appLabel + '=~".+"' + selComma(c) + '}) by (' + c.appLabel + ')',
          ['App', 'Workloads', 'Alerts']
        );
      // tables split into their own tabs (Clusters first), Clusters full height.
      local dash = board(c.uidHome, 'Home Dashboard', c.tags + ['env-level'], [dsVar], [
        { title: 'Clusters', width: 24, height: 24, elements: { clusters: clusters } },
        { title: 'Alerts', width: 24, height: 24, elements: { alerts: alerts } },
        { title: 'Applications', width: 24, height: 12, elements: { apps: apps } },
      ], asTabs=true);
      {
        config: c,
        // expose a dashboards map (uid-keyed) so render-lib can render base boards.
        grafana: { dashboard: dash, dashboards: { [c.uidHome + '.json']: dash } },
      },
  },

  cluster:: {
    new(config={}):
      local c = defaults + config;
      local nl = c.nodeLabel;
      local cl = c.clusterLabel;
      local s = clComma(c);  // base selector + cluster=~"$cluster"
      local byNode = 'by (' + cl + ', ' + nl + ')';
      local workload =
        countTable(
          c, 'Workload', c.appLabel,
          'count(up{' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          'count(ALERTS{alertstate="firing", ' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          ['App', 'Pods', 'Alerts']
        );
      local servers = serversTable(c);
      local dash = board(c.uidCluster, 'Clusters Overview', c.tags + ['cluster-level'], [dsVar, clusterVar(c)], [
        { title: 'Servers', width: 24, height: 12, elements: { servers: servers } },
        { title: 'Workload', width: 24, height: 8, elements: { workload: workload } },
      ], asTabs=true);
      {
        config: c,
        grafana: { dashboard: dash, dashboards: { [c.uidCluster + '.json']: dash } },
      },
  },

  // per-cluster detail: a tabbed copy of the overview split into Compute / Network /
  // Storage / Applications (Linux + Windows unioned, cluster-scoped).
  clusterDetail:: {
    new(config={}):
      local c = defaults + config;
      local cl = c.clusterLabel;
      local nl = c.nodeLabel;
      local s = clComma(c);
      local byNode = 'by (' + cl + ', ' + nl + ')';
      local tsig(name, expr, unit) =
        signal.new(name, 'prometheus', c.datasource, expr, unit).filteringSelector(s).withLegendFormat('{{' + nl + '}}');
      local workload =
        countTable(
          c, 'Workload', c.appLabel,
          'count(up{' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          'count(ALERTS{alertstate="firing", ' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          ['App', 'Pods', 'Alerts']
        );
      local netRx = tsig('Network received', '(sum ' + byNode + ' (rate(node_network_receive_bytes_total{device!="lo", %(queriesSelector)s}[$__rate_interval]))) or (sum ' + byNode + ' (rate(windows_net_bytes_received_total{%(queriesSelector)s}[$__rate_interval])))', 'Bps').asTimeSeries('Network received');
      local netTx = tsig('Network transmitted', '(sum ' + byNode + ' (rate(node_network_transmit_bytes_total{device!="lo", %(queriesSelector)s}[$__rate_interval]))) or (sum ' + byNode + ' (rate(windows_net_bytes_sent_total{%(queriesSelector)s}[$__rate_interval])))', 'Bps').asTimeSeries('Network transmitted');
      local dash = board(c.uidClusterDetail, 'Cluster Detail', c.tags + ['cluster-level'], [dsVar, clusterVar(c, false), instanceVar(c)], [
        { title: 'Compute', elements: { servers: serversTable(c, capacity=true), gpus: gpusTable(c) }, items: [
          grid.item('servers', 0, 0, 24, 12),
          grid.item('gpus', 0, 12, 24, 7),
        ] },
        { title: 'Network', elements: { nics: nicsTable(c), netRx: netRx, netTx: netTx }, items: [
          grid.item('nics', 0, 0, 24, 10),
          grid.item('netRx', 0, 10, 12, 8),
          grid.item('netTx', 12, 10, 12, 8),
        ] },
        // explicit items: tall partitions table, physical disk temps, then
        // per-node Used/Free pies (repeated over the hidden $instance
        // variable, 6 per row).
        { title: 'Storage', elements: { partitions: partitionsTable(c), disks: diskTempsTable(c), storagePie: storagePie(c) }, items: [
          grid.item('partitions', 0, 0, 24, 14),
          grid.item('disks', 0, 14, 24, 7),
          grid.item('storagePie', 0, 21, 4, 5) + { spec+: { repeat: { mode: 'variable', value: 'instance', direction: 'h', maxPerRow: 6 } } },
        ] },
        { title: 'Applications', width: 24, height: 8, elements: { workload: workload } },
      ], asTabs=true);
      {
        config: c,
        grafana: { dashboard: dash, dashboards: { [c.uidClusterDetail + '.json']: dash } },
      },
  },

  // alerting-pipeline watchdog (always firing) — ported from the base-mixin.
  watchdogAlert:: {
    alert: 'Watchdog',
    expr: 'vector(1)',
    labels: { severity: 'info' },
    annotations: {
      summary: 'This is an alert meant to ensure that the entire alerting pipeline is functional.',
      description: 'This alert is always firing, therefore it should always be firing in Alertmanager and always fire against a receiver.',
    },
  },
}
