// observ-viz base/cluster fleet boards (hand-written; ported from the base-mixin).
// A two-tier overview, emitted as native v2:
//   base.home.new()    Home dashboard — clusters + applications count tables (env-level)
//   base.cluster.new() Base clusters  — workload + linux-servers tables (per cluster)
// Tables use instant table queries + seriesToColumns transforms (counts/stats joined
// into columns), with drill-through links (cluster -> Base/Cluster, node -> Linux node).
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local layout = import 'custom/layout.libsonnet';
local grid = import 'custom/util/grid.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alertPanels = import 'libs/common-lib/alert/panels.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';

// Hierarchy traversal (dashboard-level dropdowns by level tag): cluster-level
// boards link up to the env-level boards and across to their sibling
// cluster-level boards (includeVars carries $cluster over).
local clusterTraversalLinks = [
  { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
  { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
];
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
  // baseline filter in every query — site policy from config/config.libsonnet
  // (baseSelector), overridable per instantiation like every other default.
  selector: (import 'config/config.libsonnet').baseSelector,
  datasource: '${datasource}',
  uidHome: 'base-home',
  uidCluster: 'base-cluster',
  uidClusterDetail: 'cluster-detail',
  // board titles — the base layer of a site, named after its level
  titleHome: 'Home dashboard',
  titleCluster: 'Base clusters',
  titleClusterDetail: 'Base cluster',
  // Grafana folder the base boards name themselves (null leaves the folder to
  // the consumer, e.g. a monitor-tools config's grafanaDashboardFolder)
  folder: { uid: 'platform', title: 'Platform' },
  // the Home dashboard sits at the Grafana root (null = no folder)
  homeFolder: null,
  // how many alert rows the state timeline may draw, and therefore how tall
  // its tab is: one row per series, so the two travel together
  alertLimit: 100,
  nodeUid: 'compute-linux-overview',  // per-node board for Linux node drill-through
  windowsNodeUid: 'compute-windows-overview',  // per-node board for Windows node drill-through
  tags: ['base'],
  // clusterDetail Applications tab: the board an app (app.kubernetes.io/part-of,
  // else its workload) links to, and the board an app's component links to
  // (key 'app/component'). Apps without an entry render as plain text. Every
  // link carries var-cluster + var-namespace of its row.
  appBoards: {
    valheim: 'observ-viz-valheim',
    syncthing: 'observ-viz-syncthing',
    grafana: 'observ-viz-svc-grafana',
    mimir: 'observ-viz-svc-mimir',
    loki: 'observ-viz-svc-loki',
    tempo: 'observ-viz-svc-tempo',
    pyroscope: 'observ-viz-svc-pyroscope',
    prometheus: 'observ-viz-svc-prometheus',
    unifi: 'network-unifi-control',
    argocd: 'observ-viz-argocd',
    'ingress-nginx': 'observ-viz-nginx',
    postgres: 'observ-viz-postgres',
    redis: 'observ-viz-redis',
  },
  componentBoards: {},
  // the Kubernetes pod board: an Applications row's Pods (and Component) cell
  // opens it filtered to the row's namespace and its workload's pods
  podBoardUid: 'observ-viz-kube-pod',
};

// ---- helpers ----
// the folder a base board carries in its own metadata (config.folder)
local folderOf(c) =
  if std.objectHas(c, 'folder') && c.folder != null
  then dashboard.withFolder(c.folder.uid, if std.objectHas(c.folder, 'title') then c.folder.title else c.folder.uid)
  else {};
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
  { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16, gradientMode: 'scheme', thresholdsStyle: { mode: 'dashed' } } },
  { id: 'min', value: 0 },
  { id: 'max', value: 100 },
  { id: 'color', value: { mode: 'thresholds' } },  // scheme gradient paints the line by threshold color
  { id: 'thresholds', value: { mode: 'absolute', steps: [
    { color: 'green', value: null },
    { color: 'orange', value: 60 },
    { color: 'red', value: 80 },
  ] } },
];
// utilization sparkline styling (CPU/Mem/Load/Used %): threshold-colored like
// the old basic gauges — green, red from 80.
local pctSpark = [
  { id: 'unit', value: 'percent' },
  { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16, gradientMode: 'scheme', thresholdsStyle: { mode: 'dashed' } } },
  { id: 'min', value: 0 },
  { id: 'max', value: 100 },
  { id: 'color', value: { mode: 'thresholds' } },
  { id: 'thresholds', value: { mode: 'absolute', steps: [
    { color: 'green', value: null },
    { color: 'red', value: 80 },
  ] } },
];

// frequency sparkline (CPUs table): plain single-color trend, hertz.
local freqSpark = [
  { id: 'unit', value: 'hertz' },
  { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16, gradientMode: 'scheme' } },
  { id: 'color', value: { mode: 'fixed', fixedColor: 'blue' } },
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
// hidden node-count variable: resolves to the number of nodes in the current
// cluster+node selection (query_result + regex extract) — drives the
// selection-sized layout buckets.
local nodeCountVar(c) =
  variable.query.new('nodecount')
  // count_values folds the node count into label "n", so the proven
  // label_values plumbing reads it directly — no query_result, no regex.
  // label_values() can only read labels off real series (computed exprs like
  // count_values() don't work there, and $__range doesn't interpolate in
  // variable queries) — so the base-node-count recording rule materializes the
  // per-cluster 6h node count as label "n" and this just reads it. Note: the
  // rule is per-cluster, so manual node narrowing doesn't shrink the count.
  + variable.query.withLabelValues('n', 'base:cluster_nodes:n{' + clComma(c) + '}')
  + variable.query.withLabel('Nodes')
  + { spec+: { hide: 'hideVariable', refresh: 'onTimeRangeChanged' } };

// rows-of-grids (or tabs) layout (same shape as pack.build). A group either
// wraps its elements uniformly (width/height) or brings explicit grid items
// (mixed sizes / per-item repeat). With shortItems, the tab carries TWO
// conditionally-rendered header-less rows — the tall grid when the node
// variable is All, the compact one when a subset is selected (the closest
// Grafana gets to sizing panels by selection).
local condVar(varName, op, value) = { kind: 'ConditionalRenderingVariable', spec: { variable: varName, operator: op, value: value } };
local condRow(conds, items, cond='and') = {
  kind: 'RowsLayoutRow',
  spec: {
    title: '',
    hideHeader: true,
    conditionalRendering: { kind: 'ConditionalRenderingGroup', spec: {
      visibility: 'show',
      condition: cond,
      items: conds,
    } },
    layout: layout.grid.new() + layout.grid.withItems(items),
  },
};
// node-count buckets for node-scoped tabs, driven by the hidden $nodecount
// variable (reacts to cluster switches AND node narrowing). The last bucket
// is a catch-all (10+ nodes or a broken count) so some variant always renders.
local countIs(re) = condVar('nodecount', 'matches', re);
local sizeBuckets(mk) = [
  condRow([countIs('^1$')], mk.n1),
  condRow([countIs('^[23]$')], mk.n23),
  condRow([countIs('^[456]$')], mk.n46),
  condRow([countIs('^[789]$')], mk.n79),
  condRow([condVar('nodecount', 'notMatches', '^[1-9]$')], mk.rest),
];
local gridOf(g) =
  if std.objectHas(g, 'layout') then g.layout
  else if std.objectHas(g, 'buckets') then
    layout.rows.new() + layout.rows.withRows(
      sizeBuckets(g.buckets)
      + (if std.objectHas(g, 'extraRows') then g.extraRows else [])
    )
  else if std.objectHas(g, 'shortItems') then
    layout.rows.new() + layout.rows.withRows([
      condRow([condVar('nodecount', 'notMatches', '^[1-4]$')], g.items),
      condRow([condVar('nodecount', 'matches', '^[1-4]$')], g.shortItems),
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
  // so processor queue length/cores is the closest analog. Range query — the
  // column renders as a sparkline (orange >1, red >5).
  local qLoadPerCpu =
    query.prometheus.new(c.datasource,
                         '(max ' + byNode + ' (node_load1{' + s + '}) / count ' + byNode + ' (node_cpu_seconds_total{mode="idle", ' + s + '})) or '
                         + '(max ' + byNode + ' (windows_system_processor_queue_length{' + s + '}) / count ' + byNode + ' (windows_cpu_time_total{mode="idle", ' + s + '}))');
  local qMemTotal =
    tq(c, '(max ' + byNode + ' (' + lot('node_memory_MemTotal_bytes{' + s + '}') + ')) or '
          + '(max ' + byNode + ' (' + lot('windows_memory_physical_total_bytes{' + s + '}') + '))');
  // physical vs virtual via DMI product_name (QEMU/KVM/VMware patterns).
  // Windows has no DMI metric — infer physical from a real CPU temp sensor
  // (OhmGraphite/LibreHardwareMonitor exposes none inside VMs); boxes without
  // sensors stay blank rather than guessing.
  local qKind =
    tq(c, '(label_replace(label_replace(sum by (' + cl + ', ' + nl + ', product_name) (' + lot('node_dmi_info{' + s + '}') + '), "kind", "physical", "", ""), "kind", "virtual", "product_name", "Standard PC.*|KVM.*|.*[Vv]irtual.*|VMware.*|Bochs.*")) or '
          + '(label_replace(group by (' + cl + ', ' + nl + ') (' + lot('ohm_cpu_celsius{' + s + '}') + ' and on(' + cl + ', ' + nl + ') ' + lot('windows_os_info{' + s + '}') + '), "kind", "physical", "", ""))');
  // vendor + product from DMI ("LENOVO Legion 5 Pro 16ACH6H"); firmware
  // garbage values fall back from product_version to product_name. Windows
  // has no DMI metric — blank there.
  local dmiGarbage = 'Default string|System Version|System Product Name|To Be Filled.*|';
  local qDevice =
    tq(c, '(sum by (' + cl + ', ' + nl + ', device) (label_join((label_replace(' + lot('node_dmi_info{' + s + ', product_version!~"' + dmiGarbage + '"}') + ', "dev", "$1", "product_version", "(.+)")) or (label_replace(' + lot('node_dmi_info{' + s + ', product_version=~"' + dmiGarbage + '"}') + ', "dev", "$1", "product_name", "(.+)")), "device", " ", "system_vendor", "dev"))) or '
          + '(sum by (' + cl + ', ' + nl + ', device) (label_join(' + lot('windows_device_info{' + s + '}') + ', "device", " ", "vendor", "product")))');
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
    then [qInfo, qCpus, qMemTotal, qUptime, qOs, qKind, qTrendCpu, qTrendMem, qLoadPerCpu, qDevice]
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
        + (if capacity then ['kind', 'device', 'Trend #G', 'Trend #H', 'Trend #I'] else [cl]) } } },
      { id: 'seriesToColumns', options: { byField: nl } },
      { id: 'organize', options:
        if capacity then {
          excludeByName: { 'Value #A': true, 'Value #E': true, 'Value #F': true, 'Value #J': true },
          indexByName: { [nl]: 0, pretty_name: 1, release: 2, kind: 3, device: 4, 'Trend #G': 5, 'Value #B': 6, 'Trend #H': 7, 'Value #C': 8, 'Trend #I': 9, 'Value #D': 10, board: 11 },
          renameByName: { [nl]: 'Node', pretty_name: 'OS', release: 'Release', kind: 'Type', device: 'Device', 'Value #B': 'CPUs', 'Value #D': 'Uptime', 'Trend #G': 'CPU %', 'Value #C': 'Memory', 'Trend #H': 'Mem %', 'Trend #I': 'Load/CPU', board: 'Board' },
        } else {
          excludeByName: { 'Value #A': true, 'Value #E': true, [cl + ' 2']: true, [cl + ' 3']: true, [cl + ' 4']: true, [cl + ' 5']: true },
          // every field needs an explicit index — unindexed ones (the excluded
          // join-suffixed cluster copies) otherwise take the low slots and push
          // the real Cluster column out of first place
          indexByName: { [cl]: 0, [nl]: 1, pretty_name: 2, release: 3, 'Value #B': 4, 'Value #C': 5, 'Value #D': 6, board: 7, 'Value #A': 8, 'Value #E': 9, [cl + ' 2']: 10, [cl + ' 3']: 11, [cl + ' 4']: 12, [cl + ' 5']: 13 },
          renameByName: { [cl]: 'Cluster', [nl]: 'Node', pretty_name: 'OS', release: 'Release', 'Value #B': 'CPU', 'Value #C': 'Memory', 'Value #D': 'Uptime', board: 'Board' },
        } },
    ]
  )
  + panel.table.withOverrides(
    // drill link: cluster comes from the dashboard variable (single value on the
    // detail board; on the multi-cluster overview "All" still resolves the node
    // via the fleet-unique var-instance).
    // capacity flavor has no Cluster column (single-select board) -> the
    // dashboard variable is the cluster; the overview carries the row's own
    // cluster instead, since its $cluster is multi/All.
    [ov('Node', [{ id: 'links', value: [{
      title: '${__value.raw}',
      url: '/d/${__data.fields["Board"]}?var-instance=${__value.raw}&' +
           (if capacity then '${cluster:queryparam}' else 'var-cluster=${__data.fields["Cluster"]}'),
    }] }])]
    + (if capacity then [
         ov('CPU %|Mem %', pctSpark),
         ov('CPUs', [{ id: 'custom.width', value: 60 }]),
         ov('Type', [{ id: 'custom.width', value: 80 }]),
         ov('Load/CPU', [
           { id: 'decimals', value: 2 },
           { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16, gradientMode: 'scheme', thresholdsStyle: { mode: 'dashed' } } },
           { id: 'min', value: 0 },
           { id: 'color', value: { mode: 'thresholds' } },
           { id: 'thresholds', value: { mode: 'absolute', steps: [
             { color: 'green', value: null },
             { color: 'orange', value: 1 },
             { color: 'red', value: 5 },
           ] } },
         ]),
         ov('Uptime', [{ id: 'unit', value: 'dtdurations' }, { id: 'custom.width', value: 110 }]),
         ov('Memory', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 110 }]),
       ] else [
         // single link: multiple links turn the cell into a popup menu instead
         // of a plain clickable value
         ov('Cluster', [
           { id: 'links', value: [{ title: 'Cluster detail', url: '/d/' + c.uidClusterDetail + '?var-cluster=${__value.raw}&var-instance=$__all' }] },
           { id: 'custom.width', value: 150 },
         ]),
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
  local fsSel = 'fstype!="", mountpoint!~"/(boot|media|run).*", ' + s;  // skip EFI/boot + removable mounts
  local winSel = 'volume!~"HarddiskVolume.*", ' + s;  // skip letterless recovery/EFI partitions
  // parent disk from the device label where derivable (sdX1 -> sdX,
  // nvmeXnYpZ -> nvmeXnY, mmcblkXpY -> mmcblkX); LVM/zfs/Windows volumes keep
  // the device itself — labels carry no disk topology for those.
  local diskify(expr) =
    'label_replace(label_replace(label_replace(label_replace(' + expr
    + ', "disk", "$1", "device", "(.+)")'
    + ', "disk", "$1", "device", "/dev/([shv]d[a-z]+)[0-9]+")'
    + ', "disk", "$1", "device", "/dev/(nvme[0-9]+n[0-9]+)p[0-9]+")'
    + ', "disk", "$1", "device", "/dev/(mmcblk[0-9]+)p[0-9]+")';
  panel.table.new('Partitions')
  + panel.table.withTargets([
    tq(c, '(' + diskify('label_join(last_over_time(node_filesystem_size_bytes{' + fsSel + '}[$__range]), ' + joinKey + ')') + ') or '
          + '(' + diskify('label_join(' + winRelabel('last_over_time(windows_logical_disk_size_bytes{' + winSel + '}[$__range])') + ', ' + joinKey + ')') + ')'),
    query.prometheus.new(c.datasource,
                         'max by (key) ((label_join((1 - node_filesystem_avail_bytes{' + fsSel + '} / node_filesystem_size_bytes{' + fsSel + '}) * 100, ' + joinKey + ')) or '
                         + '(label_join(' + winRelabel('(1 - windows_logical_disk_free_bytes{' + winSel + '} / windows_logical_disk_size_bytes{' + winSel + '}) * 100') + ', ' + joinKey + ')))'),
  ])
  + panel.table.withTransformations([
    { id: 'timeSeriesTable', options: {} },
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: ['key', 'disk', 'mountpoint', nl, 'Value #A', 'Trend #B'] } } },
    { id: 'seriesToColumns', options: { byField: 'key' } },
    { id: 'organize', options: {
      excludeByName: { key: true },
      indexByName: { [nl]: 0, mountpoint: 1, disk: 2, 'Trend #B': 3, 'Value #A': 4 },
      renameByName: { [nl]: 'Node', mountpoint: 'Mount', disk: 'Disk', 'Trend #B': 'Used %', 'Value #A': 'Capacity' },
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
    tq(c, 'label_join(count by (' + c.clusterLabel + ', ' + nl + ', hardware, hw_instance) (last_over_time({__name__=~"ohm_gpu.*_(load_percent|hertz)", ' + s + '}[$__range])), ' + joinKey + ')'),
    query.prometheus.new(c.datasource, keyed('celsius', 'GPU Core')),
    tq(c, 'max by (key) (label_join(last_over_time(' + g('bytes', 'GPU Memory Total|D3D Shared Memory Total') + '[$__range]), ' + joinKey + '))'),
    tq(c, keyed('watts', 'GPU Package|GPU Power')),
    query.prometheus.new(c.datasource, keyed('hertz', 'GPU Core')),
    query.prometheus.new(c.datasource, keyed('load_percent', 'GPU Core|D3D 3D')),
    query.prometheus.new(c.datasource, '100 * ' + keyed('bytes', 'GPU Memory Used|D3D Shared Memory Used') + ' / ' + keyed('bytes', 'GPU Memory Total|D3D Shared Memory Total')),
  ])
  + panel.table.withTransformations([
    { id: 'timeSeriesTable', options: {} },
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: ['key', nl, 'hardware', 'Trend #B', 'Value #C', 'Value #D', 'Trend #E', 'Trend #F', 'Trend #G'] } } },
    { id: 'seriesToColumns', options: { byField: 'key' } },
    { id: 'organize', options: {
      excludeByName: { key: true, 'Value #A': true },
      indexByName: { [nl]: 0, hardware: 1, 'Trend #F': 2, 'Trend #G': 3, 'Value #C': 4, 'Trend #E': 5, 'Value #D': 6, 'Trend #B': 7 },
      renameByName: { [nl]: 'Node', hardware: 'GPU Model', 'Trend #F': 'Load %', 'Value #C': 'Memory', 'Trend #G': 'Mem %', 'Trend #E': 'Freq', 'Value #D': 'Power', 'Trend #B': 'Temp' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('GPU Model', [{ id: 'custom.width', value: 320 }]),
    ov('Load %|Mem %', pctSpark),
    ov('Memory', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 110 }]),
    ov('Freq', freqSpark),
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
    tq(c, '(sum by (' + nl + ', model_name) (last_over_time(node_cpu_info{model_name!="", ' + s + '}[$__range]))) or '
          + '(sum by (' + nl + ', model_name) (label_replace(last_over_time(ohm_cpu_hertz{' + s + '}[$__range]), "model_name", "$1", "hardware", "(.+)")))'),
    query.prometheus.new(c.datasource,
                         '(max by (' + nl + ') (node_hwmon_temp_celsius{chip=~"' + cpuChips + '", ' + s + '})) or '
                         + '(max by (' + nl + ') (ohm_cpu_celsius{' + s + '}))'),
    // windows_exporter has no arch label; the fleet's Windows boxes are all
    // x86_64, so stamp it.
    tq(c, '(sum by (' + nl + ', machine) (last_over_time(node_uname_info{' + s + '}[$__range]))) or '
          + '(sum by (' + nl + ', machine) (label_replace(last_over_time(windows_os_info{' + s + '}[$__range]), "machine", "x86_64", "", "")))'),
    query.prometheus.new(c.datasource,
                         '(max by (' + nl + ') (node_cpu_scaling_frequency_hertz{' + s + '})) or '
                         + '(max by (' + nl + ') (ohm_cpu_hertz{' + s + '}))'),
    query.prometheus.new(c.datasource,
                         '((1 - avg by (' + nl + ') (rate(node_cpu_seconds_total{mode="idle", ' + s + '}[$__rate_interval]))) * 100) or '
                         + '((1 - avg by (' + nl + ') (rate(windows_cpu_time_total{mode="idle", ' + s + '}[$__rate_interval]))) * 100)'),
    // G: active cpufreq scaling governor (linux only; windows rows stay blank)
    tq(c, 'count by (' + nl + ', governor) (last_over_time(node_cpu_scaling_governor{' + s + '}[$__range]) == 1)'),
  ])
  + panel.table.withTransformations([
    { id: 'timeSeriesTable', options: {} },
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: [nl, 'model_name', 'machine', 'governor', 'Value #A', 'Trend #C', 'Trend #E', 'Trend #F'] } } },
    { id: 'seriesToColumns', options: { byField: nl } },
    { id: 'organize', options: {
      excludeByName: { 'Value #B': true, 'Value #D': true, 'Value #G': true },
      indexByName: { [nl]: 0, model_name: 1, 'Trend #F': 2, 'Value #A': 3, machine: 4, governor: 5, 'Trend #E': 6, 'Trend #C': 7 },
      renameByName: { [nl]: 'Node', 'Trend #F': 'CPU %', 'Value #A': 'CPUs', model_name: 'CPU Model', machine: 'Arch', governor: 'Governor', 'Trend #E': 'Freq', 'Trend #C': 'Temp' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('CPUs', [{ id: 'custom.width', value: 60 }]),
    ov('CPU Model', [{ id: 'custom.width', value: 380 }]),
    ov('Arch', [{ id: 'custom.width', value: 90 }]),
    ov('Governor', [{ id: 'custom.width', value: 110 }]),
    ov('Freq', freqSpark),
    ov('CPU %', pctSpark),
    ov('Temp', tempSpark),
  ]);

// Batteries table (clusterDetail Compute tab): physical nodes with a real
// battery — Linux powersupplyclass (BAT*/battery; HID peripheral batteries
// excluded) unioned with Windows OhmGraphite battery sensors. Charge as a
// gauge, Health = full-charge vs design capacity (energy Wh, charge Ah or
// 100-degradation — whichever the node exposes), capacity/cycles/draw/AC.
// Diskless clusters simply render an empty table.
local batteriesTable(c) =
  local nl = c.nodeLabel;
  local s = clComma(c) + ', ' + nl + '=~"$instance"';
  local bat = 'power_supply=~"BAT.*|battery"';
  local lotr(m, sel) = 'max by (' + nl + ') (last_over_time(' + m + '{' + sel + ', ' + s + '}[$__range]))';
  panel.table.new('Batteries')
  + panel.table.withTargets([
    // A: charge percent
    tq(c, '(' + lotr('node_power_supply_capacity', bat) + ') or (' + lotr('ohm_battery_level_percent', 'sensor="Charge Level"') + ')'),
    // B: health % (full vs design)
    tq(c, '(100 * (' + lotr('node_power_supply_energy_full', bat) + ') / (' + lotr('node_power_supply_energy_full_design', bat) + ')) or '
          + '(100 * (' + lotr('node_power_supply_charge_full', bat) + ') / (' + lotr('node_power_supply_charge_full_design', bat) + ')) or '
          + '(100 - (' + lotr('ohm_battery_level_percent', 'sensor="Degradation Level"') + '))'),
    // C: full-charge capacity (Wh; Ah-only linux batteries stay blank)
    tq(c, '(' + lotr('node_power_supply_energy_full', bat) + ') or (' + lotr('ohm_battery_watt_hours', 'sensor="Fully-Charged Capacity"') + ')'),
    // D: design capacity (Wh)
    tq(c, '(' + lotr('node_power_supply_energy_full_design', bat) + ') or (' + lotr('ohm_battery_watt_hours', 'sensor="Designed Capacity"') + ')'),
    // E: charge cycles (linux only)
    tq(c, lotr('node_power_supply_cyclecount', bat)),
    // F: draw/charge rate sparkline
    query.prometheus.new(c.datasource,
                         '(max by (' + nl + ') (node_power_supply_power_watt{' + bat + ', ' + s + '})) or '
                         + '(max by (' + nl + ') (ohm_battery_watts{sensor="Charge/Discharge Rate", ' + s + '}))'),
    // G: on AC (linux only)
    tq(c, 'max by (' + nl + ') (last_over_time(node_power_supply_online{power_supply=~"AC.*|ADP.*", ' + s + '}[$__range]))'),
  ])
  + panel.table.withTransformations([
    { id: 'timeSeriesTable', options: {} },
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: [nl, 'Value #A', 'Value #B', 'Value #C', 'Value #D', 'Value #E', 'Trend #F', 'Value #G'] } } },
    { id: 'seriesToColumns', options: { byField: nl } },
    { id: 'organize', options: {
      indexByName: { [nl]: 0, 'Value #A': 1, 'Value #B': 2, 'Value #C': 3, 'Value #D': 4, 'Value #E': 5, 'Trend #F': 6, 'Value #G': 7 },
      renameByName: { [nl]: 'Node', 'Value #A': 'Charge', 'Value #B': 'Health', 'Value #C': 'Capacity', 'Value #D': 'Design', 'Value #E': 'Cycles', 'Trend #F': 'Power', 'Value #G': 'AC' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('Charge', [
      { id: 'unit', value: 'percent' },
      { id: 'custom.width', value: 180 },
      { id: 'min', value: 0 },
      { id: 'max', value: 100 },
      { id: 'decimals', value: 0 },
      { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } },
      { id: 'thresholds', value: { mode: 'absolute', steps: [
        { color: 'red', value: null },
        { color: 'yellow', value: 20 },
        { color: 'green', value: 50 },
      ] } },
    ]),
    ov('Health', [
      { id: 'unit', value: 'percent' },
      { id: 'custom.width', value: 90 },
      { id: 'decimals', value: 0 },
      { id: 'custom.cellOptions', value: { type: 'color-text' } },
      { id: 'thresholds', value: { mode: 'absolute', steps: [
        { color: 'red', value: null },
        { color: 'yellow', value: 70 },
        { color: 'green', value: 85 },
      ] } },
    ]),
    ov('Capacity', [{ id: 'unit', value: 'watth' }, { id: 'custom.width', value: 100 }, { id: 'decimals', value: 1 }]),
    ov('Design', [{ id: 'unit', value: 'watth' }, { id: 'custom.width', value: 100 }, { id: 'decimals', value: 1 }]),
    ov('Cycles', [{ id: 'custom.width', value: 80 }]),
    ov('Power', [
      { id: 'unit', value: 'watt' },
      { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16, gradientMode: 'scheme' } },
      { id: 'color', value: { mode: 'fixed', fixedColor: 'purple' } },
    ]),
    ov('AC', [
      { id: 'custom.width', value: 90 },
      { id: 'mappings', value: [{ type: 'value', options: {
        '1': { text: 'AC', color: 'green' },
        '0': { text: 'battery', color: 'orange' },
      } }] },
      { id: 'custom.cellOptions', value: { type: 'color-text' } },
    ]),
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
    ov('In|Out', [{ id: 'unit', value: 'Bps' }, { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16 } }]),
  ]);

// per-node Used/Free storage pie (clusterDetail Storage tab): the grid item
// repeats over the hidden $instance variable, one clone per node. Same
// /boot|/media exclusion as the Disks table so the numbers line up.
local storagePie(c) =
  local nl = c.nodeLabel;
  local si = 'fstype!="", mountpoint!~"/(boot|media|run).*", ' + clComma(c) + ', ' + nl + '=~"$instance"';
  local wi = 'volume!~"HarddiskVolume.*", ' + clComma(c) + ', ' + nl + '=~"$instance"';
  // last_over_time over the dashboard range: offline nodes keep their last
  // known pie, matching the tables' row retention.
  local lo(sel) = 'last_over_time(' + sel + '[$__range])';
  local pq(expr, legend) =
    query.prometheus.new(c.datasource, expr)
    + query.prometheus.withLegendFormat(legend)
    + { spec+: { query+: { spec+: { instant: true, range: false } } } };
  panel.pieChart.new('Storage $instance')
  + panel.pieChart.withTargets([
    pq('(sum(' + lo('node_filesystem_size_bytes{' + si + '}') + ') - sum(' + lo('node_filesystem_avail_bytes{' + si + '}') + ')) or '
       + '(sum(' + lo('windows_logical_disk_size_bytes{' + wi + '}') + ') - sum(' + lo('windows_logical_disk_free_bytes{' + wi + '}') + '))', 'Used'),
    pq('(sum(' + lo('node_filesystem_avail_bytes{' + si + '}') + ')) or (sum(' + lo('windows_logical_disk_free_bytes{' + wi + '}') + '))', 'Free'),
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

// namespace variable (clusterDetail Applications tab): the namespaces that run
// pods in $cluster - kube-state-metrics where it is scraped, cAdvisor otherwise.
// The tab repeats one row per selected namespace.
local namespaceVar(c) =
  variable.query.new('namespace')
  + variable.query.withLabel('Namespace')
  + variable.query.withLabelValues('namespace', '{__name__=~"kube_pod_info|container_memory_working_set_bytes", namespace!="", ' + clComma(c) + '}')
  + variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent;

// Applications table (one per repeated namespace row): one line per app x
// component with pods, container readiness, restarts over the range, CPU,
// memory and firing alerts.
//   app       = app.kubernetes.io/part-of, else the pod's workload
//   component = app.kubernetes.io/component, else app.kubernetes.io/name, else the workload
//   workload  = the owner (ReplicaSet -> its Deployment, CronJob Job -> the
//               CronJob), else the pod name less its generated suffixes
// Every query rebuilds that pod -> app/component map from kube_pod_info (or
// cAdvisor), kube_pod_labels and kube_pod_owner, each join falling back
// (`or on (namespace, pod)`) so a pod missing a label or owner still gets a row.
// Links: the identity query stamps app_url / comp_url labels from
// c.appBoards / c.componentBoards (label_replace per entry, then the full
// /d/<uid>?var-cluster=..&var-namespace=.. path); unmapped rows carry none,
// and Grafana drops a data link whose URL renders empty, so only mapped cells
// link. The two url columns stay in the frame (the link reads them) but are
// hidden.
local appsTable(c) =
  local s = clComma(c) + ', namespace=~"$namespace"';
  local cadv = 'job=~".*cadvisor", container!="", ';
  // pod-name / owner / labels, joined by (namespace, pod)
  local labelSet = 'label_app_kubernetes_io_part_of, label_app_kubernetes_io_component, label_app_kubernetes_io_name';
  local pods = '(group by (namespace, pod) (kube_pod_info{' + s + '}) or group by (namespace, pod) (container_memory_working_set_bytes{' + cadv + 'pod!="", ' + s + '}))';
  local podLabels = 'topk by (namespace, pod) (1, group by (namespace, pod, ' + labelSet + ') (kube_pod_labels{' + s + '}))';
  local podOwner = 'topk by (namespace, pod) (1, group by (namespace, pod, owner_kind, owner_name) (kube_pod_owner{owner_kind!="Node", owner_name!="<none>", ' + s + '}))';
  local withLabels = '((' + pods + ' * on (namespace, pod) group_left (' + labelSet + ') ' + podLabels + ') or on (namespace, pod) ' + pods + ')';
  local withOwner = '((' + withLabels + ' * on (namespace, pod) group_left (owner_kind, owner_name) ' + podOwner + ') or on (namespace, pod) ' + withLabels + ')';
  local rl(expr, dst, repl, src, re) = 'label_replace(' + expr + ', "' + dst + '", "' + repl + '", "' + src + '", "' + re + '")';
  // pod name minus the generated suffixes (k8s' vowel-free alphabet): the
  // workload when there is no owner to read (no kube-state-metrics)
  local sfx = '[b-df-hj-np-tv-z2-9]';
  local podWorkload = rl(withOwner, 'workload', '$1$2$3$4', 'pod', '(.+)-' + sfx + '{6,10}-' + sfx + '{5}|(.+)-' + sfx + '{5}|(.+)-[0-9]+|(.+)');
  local workload = rl('label_join(' + podWorkload + ', "owner", ":", "owner_kind", "owner_name")',
                      'workload', '$1$2$3', 'owner', 'ReplicaSet:(.+)-[a-z0-9]+|Job:(.+)-[0-9]{8,}|[A-Za-z]+:(.+)');
  local app = rl(rl(workload, 'app', '$1', 'workload', '(.+)'), 'app', '$1', 'label_app_kubernetes_io_part_of', '(.+)');
  local component = rl(rl(rl(app, 'component', '$1', 'workload', '(.+)'), 'component', '$1', 'label_app_kubernetes_io_name', '(.+)'),
                       'component', '$1', 'label_app_kubernetes_io_component', '(.+)');
  // one series per pod: namespace, pod, workload, app, component + the row key
  local ident = 'label_join(group by (namespace, pod, workload, app, component) (' + component + '), "app_row", "|", "namespace", "app", "component")';
  local byPod = 'topk by (namespace, pod) (1, group by (namespace, pod, app_row) (' + ident + '))';
  local byWorkload = 'topk by (namespace, workload) (1, group by (namespace, workload, app_row) (' + ident + '))';
  local onPod(expr) = '(' + expr + ' * on (namespace, pod) group_left (app_row) ' + byPod + ')';
  // regex-escape a map key for label_replace (fully anchored match)
  local reEsc(k) = std.join('', [if std.length(std.findSubstr(ch, '.+*?()[]{}|^$')) > 0 then '\\\\' + ch else ch for ch in std.stringChars(k)]);
  local stamp(expr, dst, src, boards) =
    std.foldl(function(e, k) rl(e, dst, boards[k], src, reEsc(k)), std.objectFields(boards), expr);
  // "<uid>|<namespace>" -> "/d/<uid>?var-cluster=..&var-namespace=<namespace>"; unmapped ("|ns") -> dropped
  local toUrl(expr, lbl) =
    rl(rl('label_join(' + expr + ', "' + lbl + '", "|", "' + lbl + '", "namespace")',
          lbl, '/d/$1?var-cluster=${cluster}&var-namespace=$2', lbl, '([^|]+)[|](.+)'),
       lbl, '', lbl, '[|].*');
  local linked =
    toUrl(stamp('label_join(' + toUrl(stamp(ident, 'app_url', 'app', c.appBoards), 'app_url') + ', "app_component", "/", "app", "component")',
                'comp_url', 'app_component', c.componentBoards), 'comp_url');
  // pods_url: the pod board filtered to the row's namespace and, where the
  // row is one workload, that workload's pods (var-pod=<workload>(-.*)?, a
  // regex the pod board reads unescaped); a row spanning several workloads
  // gets the whole namespace
  local wlByRow = 'group by (app_row, namespace, workload) (' + ident + ')';
  local oneWl = '(' + wlByRow + ' and on (app_row) (count by (app_row) (' + wlByRow + ') == 1))';
  local podsRe = rl(oneWl, 'pods_re', '$1(-.*)?', 'workload', '(.+)')
                 + ' or on (app_row) ' + rl('topk by (app_row) (1, ' + wlByRow + ')', 'pods_re', '.*', 'workload', '.*');
  local podsUrl = 'group by (app_row, pods_url) (' + rl('label_join(' + podsRe + ', "pods_url", "|", "namespace", "pods_re")',
                                                        'pods_url', '/d/' + c.podBoardUid + '?var-cluster=${cluster}&var-namespace=$1&var-pod=$2', 'pods_url', '([^|]+)[|](.+)') + ')';
  local qPods = tq(c, 'count by (app_row, app, component, app_url, comp_url, pods_url) (' + linked + ' * on (app_row) group_left (pods_url) ' + podsUrl + ')');
  local qReady = tq(c, 'sum by (app_row) ' + onPod('kube_pod_container_status_ready{' + s + '}')
                       + ' / count by (app_row) ' + onPod('kube_pod_container_status_ready{' + s + '}'));
  local qRestarts = tq(c, 'sum by (app_row) ' + onPod('increase(kube_pod_container_status_restarts_total{' + s + '}[$__range])'));
  local qCpu = tq(c, 'sum by (app_row) ' + onPod('rate(container_cpu_usage_seconds_total{' + cadv + s + '}[5m])'));
  local qMem = tq(c, 'sum by (app_row) ' + onPod('container_memory_working_set_bytes{' + cadv + s + '}'));
  // pod-scoped alerts join on the pod; workload-scoped ones (kube-mixin's
  // deployment / statefulset / daemonset label) on the workload
  local alertWorkload = rl(rl(rl('ALERTS{alertstate="firing", pod="", ' + s + '}', 'workload', '$1', 'deployment', '(.+)'),
                              'workload', '$1', 'statefulset', '(.+)'), 'workload', '$1', 'daemonset', '(.+)');
  local qAlerts = tq(c, 'count by (app_row) (' + onPod('ALERTS{alertstate="firing", pod!="", ' + s + '}')
                        + ' or (' + alertWorkload + ' * on (namespace, workload) group_left (app_row) ' + byWorkload + '))');
  local vals = ['Value #A', 'Value #B', 'Value #C', 'Value #D', 'Value #E', 'Value #F'];
  local lnk(title, field) = { title: title, url: '${__data.fields.' + field + ':raw}' };
  local link(title, field) = [{ id: 'links', value: [lnk(title, field)] }];
  local colorText(steps) = [
    { id: 'custom.cellOptions', value: { type: 'color-text' } },
    { id: 'color', value: { mode: 'thresholds' } },
    { id: 'thresholds', value: { mode: 'absolute', steps: steps } },
  ];
  panel.table.new('Applications')
  + panel.table.withDescription('One line per app (app.kubernetes.io/part-of, else the workload) and component (app.kubernetes.io/component, else app.kubernetes.io/name, else the workload). Ready = ready containers / containers; Restarts over the dashboard range; CPU in cores. App / Component link to their board where one is configured (appBoards / componentBoards); Pods (and Component) open the Kubernetes pod board on the row\'s pods.')
  // refIds by position: A pods (+ app/component/url labels), B ready, C restarts, D cpu, E memory, F alerts
  + panel.table.withTargets([qPods, qReady, qRestarts, qCpu, qMem, qAlerts])
  + panel.table.withTransformations([
    { id: 'labelsToFields' },
    { id: 'filterFieldsByName', options: { include: { names: ['app_row', 'app', 'component', 'app_url', 'comp_url', 'pods_url'] + vals } } },
    { id: 'seriesToColumns', options: { byField: 'app_row' } },
    { id: 'organize', options: {
      excludeByName: { app_row: true },
      indexByName: { app_row: 0, app: 1, component: 2, 'Value #A': 3, 'Value #B': 4, 'Value #C': 5, 'Value #D': 6, 'Value #E': 7, 'Value #F': 8, app_url: 9, comp_url: 10, pods_url: 11 },
      renameByName: { app: 'App', component: 'Component', 'Value #A': 'Pods', 'Value #B': 'Ready', 'Value #C': 'Restarts', 'Value #D': 'CPU', 'Value #E': 'Memory', 'Value #F': 'Alerts' },
    } },
    { id: 'sortBy', options: { sort: [{ field: 'App', desc: false }] } },
  ])
  + panel.table.withOverrides([
    ov('^App$', link('Open ${__data.fields.App} board', 'app_url')),
    ov('^Component$', [{ id: 'links', value: [lnk('Open ${__data.fields.Component} board', 'comp_url'), lnk('Pods of ${__data.fields.Component}', 'pods_url')] }]),
    ov('^(app_url|comp_url|pods_url)$', [{ id: 'custom.hidden', value: true }]),
    ov('^Pods$', [{ id: 'decimals', value: 0 }, { id: 'custom.width', value: 70 }] + link('Pods of ${__data.fields.Component}', 'pods_url')),
    ov('^Ready$', [{ id: 'unit', value: 'percentunit' }, { id: 'decimals', value: 0 }, { id: 'custom.width', value: 80 }]
                  + colorText([{ color: 'red', value: null }, { color: 'orange', value: 0.5 }, { color: 'green', value: 1 }])),
    ov('^Restarts$', [{ id: 'decimals', value: 0 }, { id: 'custom.width', value: 90 }]
                     + colorText([{ color: 'green', value: null }, { color: 'orange', value: 1 }, { color: 'red', value: 5 }])),
    ov('^CPU$', [{ id: 'unit', value: 'short' }, { id: 'decimals', value: 3 }, { id: 'custom.width', value: 90 }]),
    ov('^Memory$', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 100 }]),
    ov('^Alerts$', [{ id: 'decimals', value: 0 }, { id: 'custom.width', value: 80 }, { id: 'noValue', value: '0' }]
                   + colorText([{ color: 'green', value: null }, { color: 'orange', value: 1 }, { color: 'red', value: 5 }])),
  ]);

{
  config:: defaults,

  home:: {
    new(config={}):
      local c = defaults + config;
      local cl = c.clusterLabel;
      local nl = c.nodeLabel;
      local s = clComma(c);  // cluster=~"$cluster" — row-scoped inside the repeat
      local s2 = clComma(c) + ', ' + nl + '=~"$instance"';  // node-scoped (Nodes tab rows)
      local cpuChips = '.*coretemp.*|.*k10temp.*|.*zenpower.*|.*cpu_thermal.*|pci0000:00_0000:00:18_3';

      // summary stat for one (repeated) cluster row
      local stat(title, expr, unit='short', decimals=0) =
        panel.stat.new(title)
        + panel.stat.withTargets([query.prometheus.new(c.datasource, expr)])
        + panel.stat.withUnit(unit)
        + panel.stat.withDecimals(decimals);
      // data link on a stat (v2 path: vizConfig.spec.fieldConfig)
      local dlink(url) = { spec+: { vizConfig+: { spec+: { fieldConfig+: { defaults+: { links: [{ title: 'Open', url: url }] } } } } } };
      // cluster rows drill into the row's cluster; node rows into the node
      local clusterLink = dlink('/d/' + c.uidClusterDetail + '?var-cluster=${cluster}');
      local nodeLink = dlink('/d/' + c.uidClusterDetail + '?var-cluster=${__field.labels.' + cl + '}&var-instance=${__field.labels.' + nl + '}');
      local pctStat(title, expr) =
        stat(title, expr, 'percent')
        + panel.stat.withThresholds([
          { color: 'green', value: null },
          { color: 'yellow', value: 70 },
          { color: 'red', value: 90 },
        ]);


      // explicit drill line at the top of each repeated cluster row (the stat
      // data links only surface when you click the value itself): just four
      // compact link buttons on a transparent, title-less panel - the row
      // title already names the cluster - to the cluster detail board, its
      // Applications and Alerts tabs (dtab = the tab title's slug), and the
      // nodes board. Grafana's text sanitizer keeps inline styles on <a>; no
      // flexbox, which it may strip.
      // every button carries the current time range and datasource, as Grafana's
      // own dashboard links do (otherwise the target opens on its defaults)
      local carry = '&${__url_time_range}&${datasource:queryparam}';
      local detail = '/d/' + c.uidClusterDetail + '?var-cluster=$cluster&var-instance=$__all' + carry;
      local button(label, url) =
        '<a href="' + url + '" style="display:inline-block; margin-right:8px; padding:10px 22px; '
        + 'border:1px solid rgba(128,128,140,0.45); border-radius:4px; background:rgba(128,128,140,0.12); '
        + 'font-size:16px; font-weight:500; line-height:22px; text-decoration:none">' + label + '</a>';
      local clusterDrill =
        panel.text.new('')
        + panel.text.withTransparent(true)
        + panel.text.withOptions({ mode: 'markdown', content: std.join(' ', [
          button('Details', detail),
          button('Workload', detail + '&dtab=applications'),
          button('Nodes', '/d/' + c.uidCluster + '?var-cluster=$cluster' + carry),
          button('Alerts', detail + '&dtab=alerts'),
        ]) });
      // capacity stats are plain values: no threshold colour on value or sparkline
      local plain(p) =
        p
        + panel.stat.withOptions({ colorMode: 'none' })
        + panel.stat.withFieldConfigDefaults({ color: { mode: 'fixed', fixedColor: 'text' } });
      local elements = {
        clusterDrill: clusterDrill,
        // cluster summary band
        nodes: plain(stat('Nodes', 'count((' + c.nodeMetric + '{' + s + '}) or (' + c.windowsNodeMetric + '{' + s + '}))')) + clusterLink,
        cpus: plain(stat('CPUs', 'count((node_cpu_seconds_total{mode="idle", ' + s + '}) or (windows_cpu_time_total{mode="idle", ' + s + '}))')) + clusterLink,
        cpuPct: pctStat('CPU %', '(1 - avg((rate(node_cpu_seconds_total{mode="idle", ' + s + '}[$__rate_interval])) or (rate(windows_cpu_time_total{mode="idle", ' + s + '}[$__rate_interval])))) * 100') + clusterLink,
        mem: plain(stat('Memory', 'sum((node_memory_MemTotal_bytes{' + s + '}) or (windows_memory_physical_total_bytes{' + s + '}))', 'bytes')) + clusterLink,
        memPct: pctStat('Mem %', '(1 - sum((node_memory_MemAvailable_bytes{' + s + '}) or (windows_memory_available_bytes{' + s + '})) / sum((node_memory_MemTotal_bytes{' + s + '}) or (windows_memory_physical_total_bytes{' + s + '}))) * 100') + clusterLink,
        alertsStat: stat('Alerts', 'count(ALERTS{alertstate="firing", ' + s + '}) or vector(0)')
                    + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 1 }, { color: 'red', value: 5 }]) + clusterLink,
        // per-node stats (Nodes tab, row-repeated over $instance)
        nCpu: pctStat('CPU %', '(100 * (1 - avg by (' + cl + ', ' + nl + ') (rate(node_cpu_seconds_total{mode="idle", ' + s2 + '}[$__rate_interval])))) or (100 * (1 - avg by (' + cl + ', ' + nl + ') (rate(windows_cpu_time_total{mode="idle", ' + s2 + '}[$__rate_interval]))))') + nodeLink,
        nMem: pctStat('Mem %', '(100 * (1 - node_memory_MemAvailable_bytes{' + s2 + '} / node_memory_MemTotal_bytes{' + s2 + '})) or (100 * (1 - windows_memory_available_bytes{' + s2 + '} / windows_memory_physical_total_bytes{' + s2 + '}))') + nodeLink,
        nDisk: pctStat('Root disk %', '(100 - 100 * min by (' + cl + ', ' + nl + ') (node_filesystem_avail_bytes{mountpoint="/", ' + s2 + '} / node_filesystem_size_bytes{mountpoint="/", ' + s2 + '})) or (100 - 100 * min by (' + cl + ', ' + nl + ') (windows_logical_disk_free_bytes{volume="C:", ' + s2 + '} / windows_logical_disk_size_bytes{volume="C:", ' + s2 + '}))') + nodeLink,
        nTemp: stat('CPU temp', '(max by (' + cl + ', ' + nl + ') (node_hwmon_temp_celsius{chip=~"' + cpuChips + '", ' + s2 + '})) or (max by (' + cl + ', ' + nl + ') (ohm_cpu_celsius{' + s2 + '}))', 'celsius')
               + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'yellow', value: 70 }, { color: 'red', value: 85 }]) + nodeLink,
        nUptime: stat('Uptime', '(max by (' + cl + ', ' + nl + ') (time() - node_boot_time_seconds{' + s2 + '})) or (max by (' + cl + ', ' + nl + ') (time() - windows_system_boot_time_timestamp{' + s2 + '}))', 's')
                 + panel.stat.withDecimals(1) + nodeLink,
        nAlerts: stat('Alerts', 'count by (' + cl + ', ' + nl + ') (ALERTS{alertstate="firing", ' + s2 + '}) or vector(0)')
                 + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 1 }, { color: 'red', value: 5 }]),
        // env-wide tabs
        alerts: alertPanels.list('Alerts', groupMode='custom', groupBy=[cl]),
        // the list shows Grafana-managed rules; the table reads the ALERTS
        // series, which is what a Mimir / Prometheus ruler produces
        alertsFiring: alertPanels.firingTable('Firing alerts', c.datasource, cl + '=~"$cluster"' + selComma(c)),
        apps: countTable(
          c,
          'Applications',
          c.appLabel,
          'count(up{' + c.appLabel + '=~".+"' + selComma(c) + '}) by (' + c.appLabel + ')',
          'count(ALERTS{alertstate="firing", ' + c.appLabel + '=~".+"' + selComma(c) + '}) by (' + c.appLabel + ')',
          ['App', 'Workloads', 'Alerts']
        ),
      };

      // one row per selected cluster (repeat over the multi cluster var):
      // summary stats on top, per-node bar gauges underneath.
      // the button line: the smallest grid height that fits it (h=1 leaves ~12 px
      // inside the panel padding and clips the buttons)
      local drillH = 2;
      local clusterRow =
        layout.rows.row('$cluster', layout.grid.new() + layout.grid.withItems([
          grid.item('clusterDrill', 0, 0, 24, drillH),
          grid.item('nodes', 0, drillH, 4, 4),
          grid.item('cpus', 4, drillH, 4, 4),
          grid.item('cpuPct', 8, drillH, 4, 4),
          grid.item('mem', 12, drillH, 4, 4),
          grid.item('memPct', 16, drillH, 4, 4),
          grid.item('alertsStat', 20, drillH, 4, 4),
        ]))
        + { spec+: { repeat: { mode: 'variable', value: 'cluster' } } };
      // one row per selected node — variables evaluate globally, so a true
      // nested repeat (nodes inside each cluster row) is not possible; the
      // Nodes tab is the second repeat axis instead.
      local nodeRow =
        layout.rows.row('$instance', layout.grid.new() + layout.grid.withItems([
          grid.item('nCpu', 0, 0, 4, 4),
          grid.item('nMem', 4, 0, 4, 4),
          grid.item('nDisk', 8, 0, 4, 4),
          grid.item('nTemp', 12, 0, 4, 4),
          grid.item('nUptime', 16, 0, 4, 4),
          grid.item('nAlerts', 20, 0, 4, 4),
        ]))
        + { spec+: { repeat: { mode: 'variable', value: 'instance' } } };

      local dash =
        dashboard.new(c.titleHome)
        + dashboard.withUid(c.uidHome)
        + dashboard.withTags(c.tags + ['env-level'])
        + dashboard.withVariables([dsVar, clusterVar(c, true), instanceVar(c)])
        + dashboard.withElements(elements)
        + dashboard.withLayout(
          layout.tabs.new() + layout.tabs.withTabs([
            layout.tabs.tab('Clusters', layout.rows.new() + layout.rows.withRows([clusterRow])),
            layout.tabs.tab('Nodes', layout.rows.new() + layout.rows.withRows([nodeRow])),
            layout.tabs.tab('Alerts', layout.grid.new() + layout.grid.withItems([
              grid.item('alerts', 0, 0, 24, 12),
              grid.item('alertsFiring', 0, 12, 24, 12),
            ])),
            layout.tabs.tab('Applications', layout.grid.new() + layout.grid.withItems([grid.item('apps', 0, 0, 24, 12)])),
          ])
        )
        + dashboard.withLinks([
          { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        ]);
      {
        config: c,
        // expose a dashboards map (uid-keyed) so render-lib can render base boards.
        local fdash = dash + folderOf(c { folder: c.homeFolder }),
        grafana: { dashboard: fdash, dashboards: { [c.uidHome + '.json']: fdash } },
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
          c,
          'Workload',
          c.appLabel,
          'count(up{' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          'count(ALERTS{alertstate="firing", ' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          ['App', 'Pods', 'Alerts']
        );
      local servers = serversTable(c);
      local dash = board(c.uidCluster, c.titleCluster, c.tags + ['env-level'], [dsVar, clusterVar(c)], [
                     { title: 'Servers', width: 24, height: 12, elements: { servers: servers } },
                     { title: 'Workload', width: 24, height: 8, elements: { workload: workload } },
                   ], asTabs=true)
                   + dashboard.withLinks([
                     { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
                   ]);
      {
        config: c,
        local fdash = dash + folderOf(c),
        grafana: { dashboard: fdash, dashboards: { [c.uidCluster + '.json']: fdash } },
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
          c,
          'Workload',
          c.appLabel,
          'count(up{' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          'count(ALERTS{alertstate="firing", ' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          ['App', 'Pods', 'Alerts']
        );
      local netRx = tsig('Network received', '(sum ' + byNode + ' (rate(node_network_receive_bytes_total{device!="lo", %(queriesSelector)s}[$__rate_interval]))) or (sum ' + byNode + ' (rate(windows_net_bytes_received_total{%(queriesSelector)s}[$__rate_interval])))', 'Bps').asTimeSeries('Network received');
      local netTx = tsig('Network transmitted', '(sum ' + byNode + ' (rate(node_network_transmit_bytes_total{device!="lo", %(queriesSelector)s}[$__rate_interval]))) or (sum ' + byNode + ' (rate(windows_net_bytes_sent_total{%(queriesSelector)s}[$__rate_interval])))', 'Bps').asTimeSeries('Network transmitted');
      local dash = board(c.uidClusterDetail, c.titleClusterDetail, c.tags + ['cluster-level'], [dsVar, clusterVar(c, false), instanceVar(c), nodeCountVar(c), namespaceVar(c)], [
                     // servers/cpus/gpus share one height per selection-size bucket.
                     local computeStack(h) = [
                       grid.item('servers', 0, 0, 24, h),
                       grid.item('cpus', 0, h, 24, h),
                       grid.item('gpus', 0, 2 * h, 24, h),
                       grid.item('batteries', 0, 3 * h, 24, h),
                     ];
                     { title: 'Compute', elements: { servers: serversTable(c, capacity=true), cpus: cpusTable(c), gpus: gpusTable(c), batteries: batteriesTable(c) }, buckets: {
                       n1: computeStack(4),
                       n23: computeStack(6),
                       n46: computeStack(9),
                       n79: computeStack(11),
                       rest: computeStack(13),
                     } },
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
                     // partitions/disks heights step with the node-count buckets like the
                     // Compute stack (partition rows scale ~4-5 per node).
                     local storageStack(ph, dh) = [
                       grid.item('partitions', 0, 0, 24, ph),
                       grid.item('disks', 0, ph, 24, dh),
                       grid.item('storagePie', 0, ph + dh, 4, 5) + { spec+: { repeat: { mode: 'variable', value: 'instance', direction: 'h', maxPerRow: 6 } } },
                     ];
                     { title: 'Storage', elements: { partitions: partitionsTable(c), disks: diskTempsTable(c), storagePie: storagePie(c) }, buckets: {
                       n1: storageStack(4, 4),
                       n23: storageStack(6, 6),
                       n46: storageStack(9, 9),
                       n79: storageStack(11, 11),
                       rest: storageStack(13, 13),
                     } },
                     // the tab grows with the cap: 10 rows of grid for the
                     // first 40 alerts, one more per 20 after that, up to 20
                     { title: 'Alerts', width: 24, height: std.min(20, 10 + std.floor(std.max(0, c.alertLimit - 40) / 20)), elements: {
                       alertList: alertPanels.list('Alerts', instanceFilter='{cluster=~"$cluster"}', groupMode='custom', groupBy=['alertname']),
                       alertsFiring: alertPanels.firingTable('Firing alerts', c.datasource, cl + '=~"$cluster"' + selComma(c)),
                       alertsFiringDetail: alertPanels.firingDetailTable('Firing alerts - detail', c.datasource, cl + '=~"$cluster"' + selComma(c), c.podBoardUid, c.nodeUid),
                       alertTimeline: alertPanels.timeline('Alert state', c.datasource, c.clusterLabel + '=~"$cluster"', c.alertLimit),
                     } },
                     // the fleet-wide workload count on top, then one row per
                     // $namespace (row repeat) with its app x component table
                     { title: 'Applications', elements: { workload: workload, apps: appsTable(c) }, layout:
                       layout.rows.new() + layout.rows.withRows([
                         layout.rows.row('Workload', layout.grid.new() + layout.grid.withItems([grid.item('workload', 0, 0, 24, 8)])),
                         layout.rows.row('$namespace', layout.grid.new() + layout.grid.withItems([grid.item('apps', 0, 0, 24, 8)]))
                         + layout.rows.withRepeat('namespace'),
                       ]) },
                   ], asTabs=true)
                   // no explicit link to the Kubernetes board: it carries the
                   // cluster-level tag, so the traversal dropdown already has it
                   + dashboard.withLinks(clusterTraversalLinks)
                   // annotation toggles: firing alerts on; pod / container /
                   // systemd-unit starts off until wanted
                   + dashboard.withAnnotationsMixin(
                     local podSel = clComma(c) + ', namespace=~"$namespace"';
                     annotations.alert.bySeverity(c.datasource, clComma(c))
                     + [
                       annotations.restart.newAt('Pod starts', annotations.restart.kubePodStart(c.datasource, podSel), ['namespace', 'node'], '{{pod}} started on {{node}}')
                       + annotations.base.asToggle(false),
                       annotations.restart.newAt('Container starts', annotations.restart.kubeContainerStart(c.datasource, podSel), ['namespace', 'pod'], '{{pod}} / {{container}} started')
                       + annotations.base.asToggle(false),
                       annotations.restart.new('Container restarts', annotations.restart.kubeContainer(c.datasource, podSel), ['namespace', 'pod', 'container'])
                       + annotations.base.withTitleFormat('{{pod}} / {{container}} restarted')
                       + annotations.base.asToggle(false),
                       annotations.restart.new('Service starts', annotations.restart.systemdUnitActivated(c.datasource, clComma(c) + ', ' + nl + '=~"$instance"'), ['instance', 'name'])
                       + annotations.base.withTitleFormat('{{name}} started on {{instance}}')
                       + annotations.base.asToggle(false),
                     ]
                   );
      {
        config: c,
        local fdash = dash + folderOf(c),
        grafana: { dashboard: fdash, dashboards: { [c.uidClusterDetail + '.json']: fdash } },
        prometheus: {
          alerts: [],
          // materializes the per-cluster node count (6h retention window, same
          // idea as the tables' row stretch) as label "n" — feeds $nodecount.
          rules: [{
            name: 'base-node-count',
            interval: '1m',
            rules: [{
              record: 'base:cluster_nodes:n',
              expr: 'count_values by (' + cl + ') ("n", count by (' + cl + ') (group by (' + cl + ', ' + nl + ') ((last_over_time(' + c.nodeMetric + selBrace(c) + '[6h])) or (last_over_time(' + c.windowsNodeMetric + selBrace(c) + '[6h])))))',
            }],
          }],
        },
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
