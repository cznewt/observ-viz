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

// temperature column styling shared by the CPUs/GPUs/Disks tables: sparkline
// over the dashboard range (0-100 scale, red when the latest value runs hot).
local tempSpark = [
  { id: 'unit', value: 'celsius' },
  { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false } },
  { id: 'min', value: 0 },
  { id: 'max', value: 100 },
  { id: 'color', value: { mode: 'thresholds' } },  // line takes the latest value's threshold color
  { id: 'thresholds', value: { mode: 'absolute', steps: [
    { color: 'green', value: null }, { color: 'orange', value: 60 }, { color: 'red', value: 80 },
  ] } },
];
// utilization sparkline styling (CPU/Mem/Load/Used %): threshold-colored like
// the old basic gauges — green, red from 80.
local pctSpark = [
  { id: 'unit', value: 'percent' },
  { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false } },
  { id: 'min', value: 0 },
  { id: 'max', value: 100 },
  { id: 'color', value: { mode: 'thresholds' } },
  { id: 'thresholds', value: { mode: 'absolute', steps: [
    { color: 'green', value: null }, { color: 'red', value: 80 },
  ] } },
];

local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };

local dsVar =
  variable.datasource.new('datasource', 'prometheus') + variable.datasource.withLabel('Data source');
local clusterVar(c, multi=true) =
  variable.query.new('cluster')
  + variable.query.withLabel('Cluster')
  + variable.query.withLabelValues(c.clusterLabel, c.nodeMetric + selBrace(c))
  + (if multi then variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent else {});
// multi-select node variable (Linux + Windows) — filters every clusterDetail
// panel and drives the storage-pie grid-item repeat.
local instanceVar(c) =
  variable.query.new('instance')
  + variable.query.withLabel('Node')
  + variable.query.withLabelValues(c.nodeLabel, '{__name__=~"' + c.nodeMetric + '|' + c.windowsNodeMetric + '", ' + clComma(c) + '}')
  + variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent;

// rows-of-grids (or tabs) layout (same shape as pack.build). A group either
// wraps its elements uniformly (width/height) or brings explicit grid items
// (mixed sizes / per-item repeat). With shortItems, the tab carries TWO
// conditionally-rendered header-less rows — the tall grid when the node
// variable is All, the compact one when a subset is selected (the closest
// Grafana gets to sizing panels by selection).
local condRow(op, items) = {
  kind: 'RowsLayoutRow',
  spec: {
    title: '',
    hideHeader: true,
    conditionalRendering: { kind: 'ConditionalRenderingGroup', spec: {
      visibility: 'show',
      condition: 'and',
      items: [{ kind: 'ConditionalRenderingVariable', spec: { variable: 'instance', operator: op, value: '$__all' } }],
    } },
    layout: layout.grid.new() + layout.grid.withItems(items),
  },
};
local gridOf(g) =
  if std.objectHas(g, 'shortItems') then
    layout.rows.new() + layout.rows.withRows([
      condRow('equals', g.items),
      condRow('notEquals', g.shortItems),
    ])
  else
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
  local s = clComma(c) + (if capacity then ', ' + nl + '=~"$instance"' else '');
  local byNode = 'by (' + cl + ', ' + nl + ')';
  // capacity flavor stretches static facts over the dashboard range so nodes
  // that went offline keep their row (live columns just go blank).
  local lot(sel) = if capacity then 'last_over_time(' + sel + '[$__range])' else sel;
  local qInfo =
    tq(c, '(sum by (' + cl + ', ' + nl + ', release, board) (label_replace(' + lot(c.nodeMetric + '{' + s + '}') + ', "board", "' + c.nodeUid + '", "", ""))) or '
        + '(sum by (' + cl + ', ' + nl + ', release, board) (label_replace(label_replace(' + lot(c.windowsNodeMetric + '{' + s + '}') + ', "release", "$1", "version", "(.+)"), "board", "' + c.windowsNodeUid + '", "", "")))');
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
    tq(c, '(sum by (' + cl + ', ' + nl + ', pretty_name) (' + lot('node_os_info{' + s + '}') + ')) or '
        + '(sum by (' + cl + ', ' + nl + ', pretty_name) (label_replace(' + lot(c.windowsNodeMetric + '{' + s + '}') + ', "pretty_name", "$1", "product", "(.+)")))');
  local qCpus =
    tq(c, '(count ' + byNode + ' (' + lot('node_cpu_seconds_total{mode="idle", ' + s + '}') + ')) or '
        + '(count ' + byNode + ' (' + lot('windows_cpu_time_total{mode="idle", ' + s + '}') + '))');
  // normalized run-queue pressure: Linux load1/cores; Windows has no loadavg,
  // so processor queue length/cores is the closest analog.
  local qLoadPerCpu =
    tq(c, '(max ' + byNode + ' (node_load1{' + s + '}) / count ' + byNode + ' (node_cpu_seconds_total{mode="idle", ' + s + '})) or '
        + '(max ' + byNode + ' (windows_system_processor_queue_length{' + s + '}) / count ' + byNode + ' (windows_cpu_time_total{mode="idle", ' + s + '}))');
  local qMemTotal =
    tq(c, '(max ' + byNode + ' (' + lot('node_memory_MemTotal_bytes{' + s + '}') + ')) or '
        + '(max ' + byNode + ' (' + lot('windows_memory_physical_total_bytes{' + s + '}') + '))');
  // physical vs virtual via DMI product_name (QEMU/KVM/VMware patterns);
  // windows_exporter has no DMI metric, so Windows rows stay blank.
  local qKind =
    tq(c, 'label_replace(label_replace(sum by (' + cl + ', ' + nl + ', product_name) (' + lot('node_dmi_info{' + s + '}') + '), "kind", "physical", "", ""), "kind", "virtual", "product_name", "Standard PC.*|KVM.*|.*[Vv]irtual.*|VMware.*|Bochs.*")');
  // range queries feeding the sparkline cells (timeSeriesTable turns each
  // series into a row with a Trend field, joined on the node column).
  local rq(expr) = query.prometheus.new(c.datasource, expr);
  local qTrendCpu =
    rq('((1 - avg by (' + nl + ') (rate(node_cpu_seconds_total{mode="idle", ' + s + '}[$__rate_interval]))) * 100) or '
       + '((1 - avg by (' + nl + ') (rate(windows_cpu_time_total{mode="idle", ' + s + '}[$__rate_interval]))) * 100)');
  local qTrendMem =
    rq('((1 - avg by (' + nl + ') (node_memory_MemAvailable_bytes{' + s + '}) / avg by (' + nl + ') (node_memory_MemTotal_bytes{' + s + '})) * 100) or '
       + '((1 - avg by (' + nl + ') (windows_memory_available_bytes{' + s + '}) / avg by (' + nl + ') (windows_memory_physical_total_bytes{' + s + '})) * 100)');
  panel.table.new('Servers')
  // refIds by position — default: A info, B cpu%, C mem%, D uptime, E os;
  // capacity: A info, B cpus, C mem-total, D load/cpu, E os, F kind,
  // G cpu-trend (range), H mem-trend (range).
  + panel.table.withTargets(
    if capacity
    then [qInfo, qCpus, qMemTotal, qLoadPerCpu, qOs, qKind, qTrendCpu, qTrendMem]
    else [qInfo, qCpuPct, qMemPct, qUptime, qOs]
  )
  + panel.table.withTransformations(
    (if capacity then [{ id: 'timeSeriesTable', options: {} }] else []) + [
    { id: 'labelsToFields' },
    // the cluster label is deliberately NOT included: no Cluster column (in any
    // join-suffixed variant) reaches the table — drill links carry the cluster
    // via the dashboard variable instead.
    { id: 'filterFieldsByName', options: { include: { names:
      [nl, 'pretty_name', 'release', 'board', 'Value #B', 'Value #C', 'Value #D']
      + (if capacity then ['kind', 'Trend #G', 'Trend #H'] else []) } } },
    { id: 'seriesToColumns', options: { byField: nl } },
    { id: 'organize', options:
      if capacity then {
        excludeByName: { 'Value #A': true, 'Value #E': true, 'Value #F': true },
        indexByName: { [nl]: 0, pretty_name: 1, release: 2, kind: 3, 'Trend #G': 4, 'Value #B': 5, 'Value #D': 6, 'Trend #H': 7, 'Value #C': 8, board: 9 },
        renameByName: { [nl]: 'Node', pretty_name: 'OS', release: 'Release', kind: 'Type', 'Value #B': 'CPUs', 'Value #D': 'Load/CPU', 'Trend #G': 'CPU %', 'Value #C': 'Memory', 'Trend #H': 'Mem %', board: 'Board' },
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
         ov('CPU %|Mem %', pctSpark),
         ov('CPUs', [{ id: 'custom.width', value: 60 }]),
         ov('Type', [{ id: 'custom.width', value: 80 }]),
         ov('Load/CPU', [{ id: 'decimals', value: 2 }, { id: 'custom.width', value: 90 }]),
         ov('Memory', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 110 }]),
       ] else [
         ov('Uptime', [{ id: 'unit', value: 'dtdurations' }]),
         ov('CPU|Memory', [{ id: 'unit', value: 'percent' }, { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } }, { id: 'min', value: 0 }, { id: 'max', value: 100 }]),
       ])
    + [ov('Board', [{ id: 'custom.hidden', value: true }])]
  );

// per-filesystem Partitions table (clusterDetail Storage tab): Linux
// node_filesystem (fstype!="") + Windows logical disks (volume relabeled to
// device+mountpoint) unioned; rows join on a synthetic node|device|mount key.
// Capacity is range-stretched so recently-offline nodes keep their rows;
// Used % renders as a sparkline over the dashboard range.
local partitionsTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c) + ', ' + nl + '=~"$instance"';
  local joinKey = '"key", "|", "' + nl + '", "device", "mountpoint"';
  local winRelabel(expr) = 'label_replace(label_replace(' + expr + ', "device", "$1", "volume", "(.+)"), "mountpoint", "$1", "volume", "(.+)")';
  local fsSel = 'fstype!="", mountpoint!~"/(boot|media).*", ' + s;  // skip EFI/boot + removable mounts
  local winSel = 'volume!~"HarddiskVolume.*", ' + s;  // skip letterless recovery/EFI partitions
  panel.table.new('Partitions')
  + panel.table.withTargets([
    tq(c, '(label_join(last_over_time(node_filesystem_size_bytes{' + fsSel + '}[$__range]), ' + joinKey + ')) or '
        + '(label_join(' + winRelabel('last_over_time(windows_logical_disk_size_bytes{' + winSel + '}[$__range])') + ', ' + joinKey + '))'),
    query.prometheus.new(c.datasource,
      'max by (key) ((label_join((1 - node_filesystem_avail_bytes{' + fsSel + '} / node_filesystem_size_bytes{' + fsSel + '}) * 100, ' + joinKey + ')) or '
      + '(label_join(' + winRelabel('(1 - windows_logical_disk_free_bytes{' + winSel + '} / windows_logical_disk_size_bytes{' + winSel + '}) * 100') + ', ' + joinKey + ')))'),
  ])
  + panel.table.withTransformations([
    { id: 'timeSeriesTable', options: {} },
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: ['key', 'device', 'mountpoint', nl, 'Value #A', 'Trend #B'] } } },
    { id: 'seriesToColumns', options: { byField: 'key' } },
    { id: 'organize', options: {
      excludeByName: { key: true },
      indexByName: { device: 0, mountpoint: 1, 'Trend #B': 2, 'Value #A': 3, [nl]: 4 },
      renameByName: { device: 'Name', mountpoint: 'Mount', 'Trend #B': 'Used %', 'Value #A': 'Capacity', [nl]: 'Node' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('Used %', pctSpark),
    ov('Capacity', [{ id: 'unit', value: 'bytes' }]),
  ]);

// per-GPU table (clusterDetail Compute tab): OhmGraphite ohm_gpu<vendor>_*
// series (Windows boxes with the hardware_sensors pillar; hardware label = GPU
// model; families gpunvidia/gpuati/gpuintel). Rows anchor on the load family
// range-stretched (offline nodes keep rows); sensor names differ per vendor,
// hence the regex unions collapsed with max by join key. Load %/Mem % render
// as sparklines; Temp keeps the thresholded gauge; Freq/Power blank where the
// silicon exposes no sensor.
local gpusTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c) + ', ' + nl + '=~"$instance"';
  local joinKey = '"key", "|", "' + nl + '", "hardware", "hw_instance"';
  local g(suffix, sensorRe) = '{__name__=~"ohm_gpu.*_' + suffix + '", sensor=~"' + sensorRe + '", ' + s + '}';
  local keyed(suffix, sensorRe) = 'max by (key) (label_join(' + g(suffix, sensorRe) + ', ' + joinKey + '))';
  panel.table.new('GPUs')
  + panel.table.withTargets([
    tq(c, 'label_join(count by (' + c.clusterLabel + ', ' + nl + ', hardware, hw_instance) (last_over_time({__name__=~"ohm_gpu.*_load_percent", ' + s + '}[$__range])), ' + joinKey + ')'),
    query.prometheus.new(c.datasource, keyed('celsius', 'GPU Core')),
    tq(c, 'max by (key) (label_join(last_over_time(' + g('bytes', 'GPU Memory Total|D3D Shared Memory Total') + '[$__range]), ' + joinKey + '))'),
    tq(c, keyed('watts', 'GPU Package|GPU Power')),
    tq(c, keyed('hertz', 'GPU Core')),
    query.prometheus.new(c.datasource, keyed('load_percent', 'GPU Core|D3D 3D')),
    query.prometheus.new(c.datasource, '100 * ' + keyed('bytes', 'GPU Memory Used|D3D Shared Memory Used') + ' / ' + keyed('bytes', 'GPU Memory Total|D3D Shared Memory Total')),
  ])
  + panel.table.withTransformations([
    { id: 'timeSeriesTable', options: {} },
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: ['key', nl, 'hardware', 'Trend #B', 'Value #C', 'Value #D', 'Value #E', 'Trend #F', 'Trend #G'] } } },
    { id: 'seriesToColumns', options: { byField: 'key' } },
    { id: 'organize', options: {
      excludeByName: { key: true, 'Value #A': true },
      indexByName: { [nl]: 0, hardware: 1, 'Trend #F': 2, 'Value #C': 3, 'Trend #G': 4, 'Value #E': 5, 'Value #D': 6, 'Trend #B': 7 },
      renameByName: { [nl]: 'Node', hardware: 'GPU', 'Trend #F': 'Load %', 'Value #C': 'Memory', 'Trend #G': 'Mem %', 'Value #E': 'Freq', 'Value #D': 'Power', 'Trend #B': 'Temp' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('GPU', [{ id: 'custom.width', value: 320 }]),
    ov('Load %|Mem %', pctSpark),
    ov('Memory', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 110 }]),
    ov('Freq', [{ id: 'unit', value: 'hertz' }, { id: 'custom.width', value: 90 }]),
    ov('Power', [{ id: 'unit', value: 'watt' }, { id: 'custom.width', value: 80 }]),
    ov('Temp', tempSpark),
  ]);

// per-node CPUs table (clusterDetail Compute tab): CPU % sparkline, count,
// model, arch, current frequency and package temperature. Static facts are
// range-stretched so offline nodes keep their rows. Temp sources: Linux hwmon
// cpu chips (coretemp; AMD SMN k10temp shows as chip pci0000:00_0000:00:18_3;
// zenpower/cpu_thermal), Windows OhmGraphite. Freq: node cpufreq scaling or
// ohm cpu clocks. VMs (kube nodes) expose neither and stay blank there.
local cpusTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c) + ', ' + nl + '=~"$instance"';
  local cpuChips = '.*coretemp.*|.*k10temp.*|.*zenpower.*|.*cpu_thermal.*|pci0000:00_0000:00:18_3';
  panel.table.new('CPUs')
  + panel.table.withTargets([
    tq(c, '(count by (' + nl + ') (last_over_time(node_cpu_seconds_total{mode="idle", ' + s + '}[$__range]))) or '
        + '(count by (' + nl + ') (last_over_time(windows_cpu_time_total{mode="idle", ' + s + '}[$__range])))'),
    tq(c, '(sum by (' + nl + ', model_name) (last_over_time(node_cpu_info{' + s + '}[$__range]))) or '
        + '(sum by (' + nl + ', model_name) (label_replace(last_over_time(ohm_cpu_hertz{' + s + '}[$__range]), "model_name", "$1", "hardware", "(.+)")))'),
    query.prometheus.new(c.datasource,
      '(max by (' + nl + ') (node_hwmon_temp_celsius{chip=~"' + cpuChips + '", ' + s + '})) or '
      + '(max by (' + nl + ') (ohm_cpu_celsius{' + s + '}))'),
    tq(c, 'sum by (' + nl + ', machine) (last_over_time(node_uname_info{' + s + '}[$__range]))'),
    tq(c, '(max by (' + nl + ') (node_cpu_scaling_frequency_hertz{' + s + '})) or '
        + '(max by (' + nl + ') (ohm_cpu_hertz{' + s + '}))'),
    query.prometheus.new(c.datasource,
      '((1 - avg by (' + nl + ') (rate(node_cpu_seconds_total{mode="idle", ' + s + '}[$__rate_interval]))) * 100) or '
      + '((1 - avg by (' + nl + ') (rate(windows_cpu_time_total{mode="idle", ' + s + '}[$__rate_interval]))) * 100)'),
  ])
  + panel.table.withTransformations([
    { id: 'timeSeriesTable', options: {} },
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: [nl, 'model_name', 'machine', 'Value #A', 'Trend #C', 'Value #E', 'Trend #F'] } } },
    { id: 'seriesToColumns', options: { byField: nl } },
    { id: 'organize', options: {
      excludeByName: { 'Value #B': true, 'Value #D': true },
      indexByName: { [nl]: 0, 'Trend #F': 1, 'Value #A': 2, model_name: 3, machine: 4, 'Value #E': 5, 'Trend #C': 6 },
      renameByName: { [nl]: 'Node', 'Trend #F': 'CPU %', 'Value #A': 'CPUs', model_name: 'CPU Model', machine: 'Arch', 'Value #E': 'Freq', 'Trend #C': 'Temp' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('CPUs', [{ id: 'custom.width', value: 60 }]),
    ov('CPU Model', [{ id: 'custom.width', value: 380 }]),
    ov('Arch', [{ id: 'custom.width', value: 90 }]),
    ov('Freq', [{ id: 'unit', value: 'hertz' }, { id: 'custom.width', value: 90 }]),
    ov('CPU %', pctSpark),
    ov('Temp', tempSpark),
  ]);

// physical Disks table (clusterDetail Storage tab): drive name + temperature.
// Linux: node_hwmon nvme/drivetemp chips (composite sensor temp1; chip id as
// the name — node_exporter has no model label). Windows: OhmGraphite
// ohm_hdd_celsius (hardware label = disk model, composite sensor). One union
// query, no join. Hottest first.
local diskTempsTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c) + ', ' + nl + '=~"$instance"';
  panel.table.new('Disks')
  + panel.table.withTargets([
    query.prometheus.new(c.datasource,
      '(label_replace(label_replace(max by (' + nl + ', chip) (node_hwmon_temp_celsius{chip=~"nvme.*|drivetemp.*", sensor="temp1", ' + s + '}), "disk", "$1", "chip", "(.+)"), "disk", "$1", "chip", "nvme_(.+)")) or '
      + '(label_replace(max by (' + nl + ', hardware) (ohm_hdd_celsius{sensor="Temperature", ' + s + '}), "disk", "$1", "hardware", "(.+)"))'),
  ])
  + panel.table.withTransformations([
    { id: 'timeSeriesTable', options: {} },
    { id: 'filterFieldsByName', options: { include: { names: [nl, 'disk', 'Trend #A'] } } },
    { id: 'organize', options: {
      indexByName: { [nl]: 0, disk: 1, 'Trend #A': 2 },
      renameByName: { [nl]: 'Node', disk: 'Disk', 'Trend #A': 'Temp' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('Temp', tempSpark),
  ]);

// per-NIC table (clusterDetail Network tab): Linux node_network (device!="lo",
// no veth) + Windows adapters (nic label relabeled to device) unioned; In/Out
// render as rate sparklines over the dashboard range, joined on a synthetic
// node|device key.
local nicsTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c) + ', ' + nl + '=~"$instance"';
  local joinKey = '"key", "|", "' + nl + '", "device"';
  local lx(m, w) = 'sum by (' + nl + ', device) (rate(' + m + '{device!~"lo|veth.*", ' + s + '}[' + w + ']))';
  local wx(m, w) = 'label_replace(sum by (' + nl + ', nic) (rate(' + m + '{' + s + '}[' + w + '])), "device", "$1", "nic", "(.+)")';
  panel.table.new('Network Interfaces')
  + panel.table.withTargets([
    tq(c, '(label_join(' + lx('node_network_receive_bytes_total', '5m') + ', ' + joinKey + ')) or (label_join(' + wx('windows_net_bytes_received_total', '5m') + ', ' + joinKey + '))'),
    query.prometheus.new(c.datasource, 'max by (key) ((label_join(' + lx('node_network_receive_bytes_total', '$__rate_interval') + ', ' + joinKey + ')) or (label_join(' + wx('windows_net_bytes_received_total', '$__rate_interval') + ', ' + joinKey + ')))'),
    query.prometheus.new(c.datasource, 'max by (key) ((label_join(' + lx('node_network_transmit_bytes_total', '$__rate_interval') + ', ' + joinKey + ')) or (label_join(' + wx('windows_net_bytes_sent_total', '$__rate_interval') + ', ' + joinKey + ')))'),
  ])
  + panel.table.withTransformations([
    { id: 'timeSeriesTable', options: {} },
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: ['key', nl, 'device', 'Trend #B', 'Trend #C'] } } },
    { id: 'seriesToColumns', options: { byField: 'key' } },
    { id: 'organize', options: {
      excludeByName: { key: true, 'Value #A': true },
      indexByName: { [nl]: 0, device: 1, 'Trend #B': 2, 'Trend #C': 3 },
      renameByName: { [nl]: 'Node', device: 'NIC', 'Trend #B': 'In', 'Trend #C': 'Out' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('In|Out', [{ id: 'unit', value: 'Bps' }, { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false } }]),
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
        signal.new(name, 'prometheus', c.datasource, expr, unit).filteringSelector(s + ', ' + nl + '=~"$instance"').withLegendFormat('{{' + nl + '}}');
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
        { title: 'Compute', elements: { servers: serversTable(c, capacity=true), cpus: cpusTable(c), gpus: gpusTable(c) }, items: [
          grid.item('servers', 0, 0, 24, 12),
          grid.item('cpus', 0, 12, 24, 8),
          grid.item('gpus', 0, 20, 24, 7),
        ], shortItems: [
          grid.item('servers', 0, 0, 24, 7),
          grid.item('cpus', 0, 7, 24, 5),
          grid.item('gpus', 0, 12, 24, 5),
        ] },
        { title: 'Network', elements: { nics: nicsTable(c), netRx: netRx, netTx: netTx }, items: [
          grid.item('nics', 0, 0, 24, 10),
          grid.item('netRx', 0, 10, 12, 8),
          grid.item('netTx', 12, 10, 12, 8),
        ], shortItems: [
          grid.item('nics', 0, 0, 24, 6),
          grid.item('netRx', 0, 6, 12, 8),
          grid.item('netTx', 12, 6, 12, 8),
        ] },
        // explicit items: tall partitions table, physical disk temps, then
        // per-node Used/Free pies (repeated over the hidden $instance
        // variable, 6 per row).
        { title: 'Storage', elements: { partitions: partitionsTable(c), disks: diskTempsTable(c), storagePie: storagePie(c) }, items: [
          grid.item('partitions', 0, 0, 24, 14),
          grid.item('disks', 0, 14, 24, 7),
          grid.item('storagePie', 0, 21, 4, 5) + { spec+: { repeat: { mode: 'variable', value: 'instance', direction: 'h', maxPerRow: 6 } } },
        ], shortItems: [
          grid.item('partitions', 0, 0, 24, 8),
          grid.item('disks', 0, 8, 24, 5),
          grid.item('storagePie', 0, 13, 4, 5) + { spec+: { repeat: { mode: 'variable', value: 'instance', direction: 'h', maxPerRow: 6 } } },
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
