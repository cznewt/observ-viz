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
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { datasource: gv.datasource + cv.datasource, query: gv.query + cv.query };

local defaults = {
  clusterLabel: 'cluster',
  nodeLabel: 'instance',
  appLabel: 'app_part_of',
  selector: '',  // optional base label filter, e.g. 'job=~".+"'
  datasource: '${datasource}',
  uidHome: 'observ-viz-base-home',
  uidCluster: 'observ-viz-base-cluster',
  nodeUid: 'observ-viz-linux',  // per-node board for node drill-through
  tags: ['base'],
};

// ---- helpers ----
local selBrace(c) = '{' + c.selector + '}';
local selComma(c) = if c.selector != '' then ', ' + c.selector else '';
local clComma(c) = c.selector + (if c.selector != '' then ', ' else '') + c.clusterLabel + '=~"$cluster"';

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
  + variable.query.withLabelValues(c.clusterLabel, 'node_uname_info' + selBrace(c))
  + variable.query.withMulti() + variable.query.withIncludeAll() + allCurrent;

// rows-of-grids layout (same shape as pack.build)
local board(uid, title, tags, vars, groups) =
  dashboard.new(title)
  + dashboard.withUid(uid)
  + dashboard.withTags(tags)
  + dashboard.withVariables(vars)
  + dashboard.withElements(std.foldl(function(acc, g) acc + g.elements, groups, {}))
  + dashboard.withLayout(
    layout.rows.new()
    + layout.rows.withRows([
      layout.rows.row(
        g.title,
        layout.grid.new() + layout.grid.withItems(grid.wrapItems(std.objectFields(g.elements), g.width, g.height))
      )
      for g in groups
    ])
  );

// count-by table: two count() queries (A=count, B=alerts) joined into columns.
local countTable(c, title, byLabel, countExpr, alertExpr, names) =
  panel.table.new(title)
  + panel.table.withTargets([tq(c, countExpr), tq(c, alertExpr)])
  + panel.table.withTransformations([
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
      local clusters =
        countTable(
          c, 'Clusters', c.clusterLabel,
          'count(node_uname_info' + selBrace(c) + ') by (' + c.clusterLabel + ')',
          'count(ALERTS{alertstate="firing"' + selComma(c) + '}) by (' + c.clusterLabel + ')',
          ['Cluster', 'Nodes', 'Alerts']
        )
        + panel.table.withOverrides([
          ov('Cluster', [{ id: 'links', value: [{ title: '${__value.raw}', url: '/d/' + c.uidCluster + '?var-cluster=${__value.raw}' }] }]),
        ]);
      local apps =
        countTable(
          c, 'Applications', c.appLabel,
          'count(up{' + c.appLabel + '=~".+"' + selComma(c) + '}) by (' + c.appLabel + ')',
          'count(ALERTS{alertstate="firing", ' + c.appLabel + '=~".+"' + selComma(c) + '}) by (' + c.appLabel + ')',
          ['App', 'Workloads', 'Alerts']
        );
      {
        config: c,
        grafana: { dashboard: board(c.uidHome, 'Base / Home', c.tags + ['env-level'], [dsVar], [
          { title: 'Overview', width: 12, height: 12, elements: { clusters: clusters, apps: apps } },
        ]) },
      },
  },

  cluster:: {
    new(config={}):
      local c = defaults + config;
      local nl = c.nodeLabel;
      local s = clComma(c);  // base selector + cluster=~"$cluster"
      local workload =
        countTable(
          c, 'Workload', c.appLabel,
          'count(up{' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          'count(ALERTS{alertstate="firing", ' + c.appLabel + '=~".+", ' + s + '}) by (' + c.appLabel + ')',
          ['App', 'Pods', 'Alerts']
        );
      local linuxServers =
        panel.table.new('Linux servers')
        + panel.table.withTargets([
          tq(c, 'sum by (' + c.clusterLabel + ', ' + nl + ', release) (node_uname_info{' + s + '})'),
          tq(c, '(1 - avg by (' + c.clusterLabel + ', ' + nl + ') (rate(node_cpu_seconds_total{mode="idle", ' + s + '}[5m]))) * 100'),
          tq(c, '(1 - avg by (' + c.clusterLabel + ', ' + nl + ') (node_memory_MemAvailable_bytes{' + s + '}) / avg by (' + c.clusterLabel + ', ' + nl + ') (node_memory_MemTotal_bytes{' + s + '})) * 100'),
          tq(c, 'max by (' + c.clusterLabel + ', ' + nl + ') (time() - node_boot_time_seconds{' + s + '})'),
        ])
        + panel.table.withTransformations([
          { id: 'filterFieldsByName', options: { include: { names: [c.clusterLabel, nl, 'release', 'Value #B', 'Value #C', 'Value #D'] } } },
          { id: 'seriesToColumns', options: { byField: nl } },
          { id: 'organize', options: {
            excludeByName: { 'Value #A': true, [c.clusterLabel + ' 2']: true, [c.clusterLabel + ' 3']: true, [c.clusterLabel + ' 4']: true },
            indexByName: { [c.clusterLabel]: 0, [nl]: 1, release: 2, 'Value #B': 3, 'Value #C': 4, 'Value #D': 5 },
            renameByName: { [c.clusterLabel]: 'Cluster', [nl]: 'Node', release: 'Release', 'Value #B': 'CPU', 'Value #C': 'Memory', 'Value #D': 'Uptime' },
          } },
        ])
        + panel.table.withOverrides([
          ov('Node', [{ id: 'links', value: [{ title: '${__value.raw}', url: '/d/' + c.nodeUid + '?var-cluster=${cluster}&var-instance=${__value.raw}' }] }]),
          ov('Uptime', [{ id: 'unit', value: 'dtdurations' }]),
          ov('CPU|Memory', [{ id: 'unit', value: 'percent' }, { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } }, { id: 'min', value: 0 }, { id: 'max', value: 100 }]),
        ]);
      {
        config: c,
        grafana: { dashboard: board(c.uidCluster, 'Base / Cluster', c.tags + ['cluster-level'], [dsVar, clusterVar(c)], [
          { title: 'Resources', width: 12, height: 14, elements: { workload: workload, linuxServers: linuxServers } },
        ]) },
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
