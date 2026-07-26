// observ-viz Kubernetes multi-cluster pack — hand-port of the kubernetes-mixin
// "Compute Resources / Multi-Cluster" board: every kube cluster side by side,
// with utilisation vs requests/limits commitment.
// The mixin drives this from cluster:node_cpu:ratio_rate5m and the
// node_namespace_pod_container:* rules, which this fleet's ruler does not
// carry; the equivalents are computed here from cAdvisor + KSM directly
// (container_cpu_usage_seconds_total / container_memory_working_set_bytes,
// both in the cAdvisor scrape allowlist, plus kube_node_status_allocatable).
// Usage:
//   g.libs.kubernetes.multicluster.new({}).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'kube-multicluster',
      dashboardTitle: 'Kubernetes Clusters',
      dashboardTags: ['kubernetes', 'multi-cluster', 'env-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
      ],
      datasource: '${datasource}',
      // env-level: every cluster that reports kube-state-metrics
      selector: 'cluster=~".+"',
      varMetric: 'kube_node_info',
      varLabels: [],
      clusterBoardUid: 'kube-cluster',  // per-row drill target
      ruleSelector: '',
      docTabs: true,
      folderUid: 'software-kubernetes',
      folderTitle: 'Kubernetes',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local s = cfg.selector;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    // containers only (the pod-level pause container and the cgroup roll-ups
    // would double-count usage)
    local cSel = 'container!="", container!="POD", ' + s;

    local sig(name, expr, unit, legend='{{cluster}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(s).withLegendFormat(legend);

    local cpuUsed = 'sum by (cluster) (rate(container_cpu_usage_seconds_total{' + cSel + '}[$__rate_interval]))';
    local cpuAlloc = 'sum by (cluster) (kube_node_status_allocatable{resource="cpu", ' + s + '})';
    local cpuReq = 'sum by (cluster) (namespace_cpu:kube_pod_container_resource_requests:sum{' + s + '})';
    local cpuLim = 'sum by (cluster) (namespace_cpu:kube_pod_container_resource_limits:sum{' + s + '})';
    local memUsed = 'sum by (cluster) (container_memory_working_set_bytes{' + cSel + '})';
    local memAlloc = 'sum by (cluster) (kube_node_status_allocatable{resource="memory", ' + s + '})';
    local memReq = 'sum by (cluster) (namespace_memory:kube_pod_container_resource_requests:sum{' + s + '})';
    local memLim = 'sum by (cluster) (namespace_memory:kube_pod_container_resource_limits:sum{' + s + '})';

    local signals = {
      clusters: sig('Clusters', 'count(count by (cluster) (kube_node_info{%(queriesSelector)s}))', 'short', 'clusters'),
      nodes: sig('Nodes', 'count(kube_node_info{%(queriesSelector)s})', 'short', 'nodes'),
      pods: sig('Pods running', 'sum(kube_pod_status_phase{phase="Running", %(queriesSelector)s})', 'short', 'pods'),
      alerts: sig('Alerts firing', 'count(ALERTS{alertstate="firing", %(queriesSelector)s}) or vector(0)', 'short', 'alerts'),
      cpuUtil: sig('CPU utilisation', '100 * sum(rate(container_cpu_usage_seconds_total{container!="", container!="POD", %(queriesSelector)s}[$__rate_interval])) / sum(kube_node_status_allocatable{resource="cpu", %(queriesSelector)s})', 'percent', 'cpu'),
      memUtil: sig('Memory utilisation', '100 * sum(container_memory_working_set_bytes{container!="", container!="POD", %(queriesSelector)s}) / sum(kube_node_status_allocatable{resource="memory", %(queriesSelector)s})', 'percent', 'memory'),
      cpuByCluster: sig('CPU usage', 'sum by (cluster) (rate(container_cpu_usage_seconds_total{container!="", container!="POD", %(queriesSelector)s}[$__rate_interval]))', 'short'),
      memByCluster: sig('Memory usage', 'sum by (cluster) (container_memory_working_set_bytes{container!="", container!="POD", %(queriesSelector)s})', 'bytes'),
      podsByCluster: sig('Pods running', 'sum by (cluster) (kube_pod_status_phase{phase="Running", %(queriesSelector)s})', 'short'),
      restartsByCluster: sig('Container restarts', 'sum by (cluster) (increase(kube_pod_container_status_restarts_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
    };

    // one row per cluster: capacity, usage, and requests/limits commitment
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local pctCell = [
      { id: 'unit', value: 'percent' },
      { id: 'custom.cellOptions', value: { type: 'gauge', mode: 'basic' } },
      { id: 'min', value: 0 }, { id: 'max', value: 100 }, { id: 'decimals', value: 0 },
      { id: 'thresholds', value: { mode: 'absolute', steps: [
        { color: 'green', value: null }, { color: 'yellow', value: 75 }, { color: 'red', value: 90 },
      ] } },
    ];
    local clustersTable =
      panel.table.new('Clusters')
      + panel.table.withTargets([
        tq('count by (cluster) (kube_node_info{' + s + '})'),  // A: nodes
        tq('sum by (cluster) (kube_pod_status_phase{phase="Running", ' + s + '})'),  // B: pods
        tq(cpuAlloc),  // C: cpu allocatable
        tq('100 * (' + cpuUsed + ') / (' + cpuAlloc + ')'),  // D: cpu util %
        tq('100 * (' + cpuReq + ') / (' + cpuAlloc + ')'),  // E: cpu requests %
        tq('100 * (' + cpuLim + ') / (' + cpuAlloc + ')'),  // F: cpu limits %
        tq(memAlloc),  // G: memory allocatable
        tq('100 * (' + memUsed + ') / (' + memAlloc + ')'),  // H: memory util %
        tq('100 * (' + memReq + ') / (' + memAlloc + ')'),  // I: memory requests %
        tq('100 * (' + memLim + ') / (' + memAlloc + ')'),  // J: memory limits %
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: [
          'cluster', 'Value #A', 'Value #B', 'Value #C', 'Value #D', 'Value #E',
          'Value #F', 'Value #G', 'Value #H', 'Value #I', 'Value #J',
        ] } } },
        { id: 'seriesToColumns', options: { byField: 'cluster' } },
        { id: 'organize', options: {
          // every field indexed: unindexed ones take the low slots and push
          // the Cluster column out of first place
          indexByName: {
            cluster: 0, 'Value #A': 1, 'Value #B': 2, 'Value #C': 3, 'Value #D': 4,
            'Value #E': 5, 'Value #F': 6, 'Value #G': 7, 'Value #H': 8, 'Value #I': 9, 'Value #J': 10,
          },
          renameByName: {
            cluster: 'Cluster', 'Value #A': 'Nodes', 'Value #B': 'Pods', 'Value #C': 'CPUs',
            'Value #D': 'CPU %', 'Value #E': 'CPU req %', 'Value #F': 'CPU lim %',
            'Value #G': 'Memory', 'Value #H': 'Mem %', 'Value #I': 'Mem req %', 'Value #J': 'Mem lim %',
          },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Cluster', desc: false }] } },
      ])
      + panel.table.withOverrides([
        ov('^Cluster$', [
          { id: 'custom.width', value: 150 },
          { id: 'links', value: [{ title: 'Cluster board', url: '/d/' + cfg.clusterBoardUid + '?var-cluster=${__value.raw}' }] },
        ]),
        ov('^Nodes$|^Pods$|^CPUs$', [{ id: 'custom.width', value: 80 }]),
        ov('^Memory$', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 110 }]),
        ov('CPU %|Mem %', pctCell),
        ov('req %|lim %', [
          { id: 'unit', value: 'percent' }, { id: 'decimals', value: 0 }, { id: 'custom.width', value: 110 },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [
            { color: 'text', value: null }, { color: 'yellow', value: 90 }, { color: 'red', value: 100 },
          ] } },
        ]),
      ]);

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          a_clusters: signals.clusters.asStat('Clusters'),
          b_nodes: signals.nodes.asStat('Nodes'),
          c_pods: signals.pods.asStat('Pods running'),
          d_cpu: signals.cpuUtil.asStat('CPU utilisation'),
          e_mem: signals.memUtil.asStat('Memory utilisation'),
          f_alerts: signals.alerts.asStat('Alerts firing'),
        },
      },
      { title: 'Clusters', width: 24, height: 8, elements: { clustersTable: clustersTable } },
      {
        title: 'Usage by cluster',
        width: 12,
        height: 8,
        elements: {
          a_cpu: signals.cpuByCluster.asTimeSeries('CPU usage (cores)'),
          b_mem: signals.memByCluster.asTimeSeries('Memory usage'),
          c_pods: signals.podsByCluster.asTimeSeries('Pods running'),
          d_restarts: signals.restartsByCluster.asTimeSeries('Container restarts'),
        },
      },
    ], [
      alert.rule.group('kubernetes-multicluster', [
        alert.rule.new(
          'KubeClusterCPUOvercommit',
          'sum by (cluster) (namespace_cpu:kube_pod_container_resource_requests:sum' + rsBrace + ') > sum by (cluster) (kube_node_status_allocatable{resource="cpu"})',
          '30m',
          'warning',
          {},
          {
            summary: 'Cluster CPU requests overcommitted.',
            description: 'Cluster {{ $labels.cluster }} has more CPU requested than allocatable — a node failure would leave pods unschedulable.',
          }
        ),
        alert.rule.new(
          'KubeClusterMemoryOvercommit',
          'sum by (cluster) (namespace_memory:kube_pod_container_resource_requests:sum' + rsBrace + ') > sum by (cluster) (kube_node_status_allocatable{resource="memory"})',
          '30m',
          'warning',
          {},
          {
            summary: 'Cluster memory requests overcommitted.',
            description: 'Cluster {{ $labels.cluster }} has more memory requested than allocatable — a node failure would leave pods unschedulable.',
          }
        ),
      ]),
    ], []),
}
