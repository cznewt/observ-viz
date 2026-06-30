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
  nodeUid: 'observ-viz-linux',  // per-node board for Linux node drill-through
  windowsNodeUid: 'observ-viz-windows',  // per-node board for Windows node drill-through
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
local clusterVar(c) =
  variable.query.new('cluster')
  + variable.query.withLabel('Cluster')
  + variable.query.withLabelValues(c.clusterLabel, c.nodeMetric + selBrace(c))
  + variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent;

// rows-of-grids (or tabs) layout (same shape as pack.build)
local gridOf(g) =
  layout.grid.new() + layout.grid.withItems(grid.wrapItems(std.objectFields(g.elements), g.width, g.height));
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
          tq(c, 'sum((node_memory_MemTotal_bytes' + clBrace(c) + ') or (windows_os_visible_memory_bytes' + clBrace(c) + ')) by (' + c.clusterLabel + ')'),
          tq(c, '(1 - avg by (' + c.clusterLabel + ') ((rate(node_cpu_seconds_total{mode="idle"' + clAnd(c) + '}[5m])) or (rate(windows_cpu_time_total{mode="idle"' + clAnd(c) + '}[5m])))) * 100'),
          tq(c, '(1 - sum by (' + c.clusterLabel + ') ((node_memory_MemAvailable_bytes' + clBrace(c) + ') or (windows_os_physical_memory_free_bytes' + clBrace(c) + ')) / sum by (' + c.clusterLabel + ') ((node_memory_MemTotal_bytes' + clBrace(c) + ') or (windows_os_visible_memory_bytes' + clBrace(c) + '))) * 100'),
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
      local dash = board(c.uidHome, 'Base / Home', c.tags + ['env-level'], [dsVar], [
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
      // Servers table unions Linux (node_exporter) and Windows (windows_exporter)
      // hosts: every target is `<linux> or <windows>`, joined per node into one
      // row. Windows labels are normalised into the shared columns via
      // label_replace (product -> pretty_name OS, version -> release Release).
      // A hidden `board` column (the per-node board uid, stamped per OS family)
      // drives the Node drill link so Windows rows open the Windows board and
      // Linux rows the Linux board. Requires Windows hosts to carry the cluster
      // label, like Linux hosts (else they drop out of this per-cluster board).
      local servers =
        panel.table.new('Servers')
        + panel.table.withTargets([
          tq(c, '(sum by (' + cl + ', ' + nl + ', release, board) (label_replace(' + c.nodeMetric + '{' + s + '}, "board", "' + c.nodeUid + '", "", ""))) or '
              + '(sum by (' + cl + ', ' + nl + ', release, board) (label_replace(label_replace(' + c.windowsNodeMetric + '{' + s + '}, "release", "$1", "version", "(.+)"), "board", "' + c.windowsNodeUid + '", "", "")))'),
          tq(c, '((1 - avg ' + byNode + ' (rate(node_cpu_seconds_total{mode="idle", ' + s + '}[5m]))) * 100) or '
              + '((1 - avg ' + byNode + ' (rate(windows_cpu_time_total{mode="idle", ' + s + '}[5m]))) * 100)'),
          tq(c, '((1 - avg ' + byNode + ' (node_memory_MemAvailable_bytes{' + s + '}) / avg ' + byNode + ' (node_memory_MemTotal_bytes{' + s + '})) * 100) or '
              + '((1 - avg ' + byNode + ' (windows_os_physical_memory_free_bytes{' + s + '}) / avg ' + byNode + ' (windows_os_visible_memory_bytes{' + s + '})) * 100)'),
          tq(c, '(max ' + byNode + ' (time() - node_boot_time_seconds{' + s + '})) or '
              + '(max ' + byNode + ' (time() - windows_system_system_up_time{' + s + '}))'),
          tq(c, '(sum by (' + cl + ', ' + nl + ', pretty_name) (node_os_info{' + s + '})) or '
              + '(sum by (' + cl + ', ' + nl + ', pretty_name) (label_replace(' + c.windowsNodeMetric + '{' + s + '}, "pretty_name", "$1", "product", "(.+)")))'),
        ])
        + panel.table.withTransformations([
          { id: 'labelsToFields' },
          { id: 'filterFieldsByName', options: { include: { names: [cl, nl, 'pretty_name', 'release', 'board', 'Value #B', 'Value #C', 'Value #D'] } } },
          { id: 'seriesToColumns', options: { byField: nl } },
          { id: 'organize', options: {
            excludeByName: { 'Value #A': true, 'Value #E': true, [cl + ' 2']: true, [cl + ' 3']: true, [cl + ' 4']: true, [cl + ' 5']: true },
            indexByName: { [cl]: 0, [nl]: 1, pretty_name: 2, release: 3, 'Value #B': 4, 'Value #C': 5, 'Value #D': 6, board: 7 },
            renameByName: { [cl]: 'Cluster', [nl]: 'Node', pretty_name: 'OS', release: 'Release', 'Value #B': 'CPU', 'Value #C': 'Memory', 'Value #D': 'Uptime', board: 'Board' },
          } },
        ])
        + panel.table.withOverrides([
          ov('Node', [{ id: 'links', value: [{ title: '${__value.raw}', url: '/d/${__data.fields["Board"]}?var-cluster=${cluster}&var-instance=${__value.raw}' }] }]),
          ov('Uptime', [{ id: 'unit', value: 'dtdurations' }]),
          ov('CPU|Memory', [{ id: 'unit', value: 'percent' }, { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } }, { id: 'min', value: 0 }, { id: 'max', value: 100 }]),
          ov('Board', [{ id: 'custom.hidden', value: true }]),
        ]);
      local dash = board(c.uidCluster, 'Base / Cluster', c.tags + ['cluster-level'], [dsVar, clusterVar(c)], [
        { title: 'Servers', width: 24, height: 12, elements: { servers: servers } },
        { title: 'Workload', width: 24, height: 8, elements: { workload: workload } },
      ], asTabs=true);
      {
        config: c,
        grafana: { dashboard: dash, dashboards: { [c.uidCluster + '.json']: dash } },
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
