// observ-viz OpenCost pack (hand-written).
// Kubernetes cost from OpenCost's exported metrics: node hourly cost (CPU,
// RAM, total), allocation per namespace and pod priced with the node rates,
// persistent volume cost, spot nodes, network egress and the cluster
// management fee.
//   g.libs.monitoring.opencost.new({}).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-opencost',
      dashboardTitle: 'OpenCost',
      dashboardTags: ['opencost', 'cost', 'kubernetes', 'app-level'],
      description: 'Kubernetes cost from OpenCost: node hourly cost, allocation per namespace priced with the node rates, persistent volumes, spot nodes, egress and the cluster management fee. Monthly figures assume 730 hours.',
      datasource: '${datasource}',
      // OpenCost series carry the cluster; cost is per node / namespace.
      selector: 'cluster=~"$cluster"',
      varMetric: 'node_total_hourly_cost',
      varLabels: ['cluster'],
      ruleSelector: '',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table
      overviewSignals: ['clusterMonthly', 'cpuAllocated', 'ramAllocated', 'nodes', 'pvTotal'],
      // what it costs to run the cluster is a monitoring concern, not a
      // property of Kubernetes itself
      folderUid: 'components-monitoring',
      folderTitle: 'Monitoring',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend='{{node}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local nsCpu = 'sum by (namespace) (container_cpu_allocation{%(queriesSelector)s} * on (node) group_left () node_cpu_hourly_cost{%(queriesSelector)s})';
    local nsRam = 'sum by (namespace) (container_memory_allocation_bytes{%(queriesSelector)s} / 1024 / 1024 / 1024 * on (node) group_left () node_ram_hourly_cost{%(queriesSelector)s})';

    local signals = {
      nodeTotal: sig('Node hourly cost', 'node_total_hourly_cost{%(queriesSelector)s}', 'currencyUSD', desc='Hourly cost of each node (CPU + RAM + GPU) at the configured or cloud rates.'),
      nodeCpu: sig('Node CPU hourly cost', 'node_cpu_hourly_cost{%(queriesSelector)s}', 'currencyUSD', desc='Hourly cost of one CPU core on each node.'),
      nodeRam: sig('Node RAM hourly cost', 'node_ram_hourly_cost{%(queriesSelector)s}', 'currencyUSD', desc='Hourly cost of one GiB of memory on each node.'),
      clusterHourly: sig('Cluster hourly cost', 'sum(node_total_hourly_cost{%(queriesSelector)s}) + sum(kubecost_cluster_management_cost{%(queriesSelector)s} or vector(0)) + sum(pv_hourly_cost{%(queriesSelector)s} or vector(0))', 'currencyUSD', 'hourly', desc='Total hourly cost: nodes plus persistent volumes plus the cluster management fee.'),
      clusterMonthly: sig('Cluster monthly cost', '(sum(node_total_hourly_cost{%(queriesSelector)s}) + sum(kubecost_cluster_management_cost{%(queriesSelector)s} or vector(0)) + sum(pv_hourly_cost{%(queriesSelector)s} or vector(0))) * 730', 'currencyUSD', 'monthly', desc='Total cost projected over a 730-hour month.'),
      managementFee: sig('Management fee', 'sum(kubecost_cluster_management_cost{%(queriesSelector)s})', 'currencyUSD', 'fee', desc='Hourly cluster management fee (control plane) as configured.'),
      nodes: sig('Nodes', 'count(node_total_hourly_cost{%(queriesSelector)s})', 'short', 'nodes', desc='Nodes with cost data.'),
      spotNodes: sig('Spot nodes', 'sum(kubecost_node_is_spot{%(queriesSelector)s})', 'short', 'spot', desc='Nodes OpenCost identifies as spot or preemptible.'),
      nsCpuCost: sig('Namespace CPU cost', nsCpu, 'currencyUSD', '{{namespace}}', desc='Hourly CPU cost per namespace: allocated cores (max of request and usage) priced at the node CPU rate.'),
      nsRamCost: sig('Namespace RAM cost', nsRam, 'currencyUSD', '{{namespace}}', desc='Hourly memory cost per namespace: allocated GiB priced at the node RAM rate.'),
      nsTotalCost: sig('Namespace cost', '(' + nsCpu + ') + (' + nsRam + ')', 'currencyUSD', '{{namespace}}', desc='Hourly CPU plus memory cost per namespace.'),
      nsTopMonthly: sig('Top namespaces (monthly)', 'topk(10, ((' + nsCpu + ') + (' + nsRam + ')) * 730)', 'currencyUSD', '{{namespace}}', desc='The ten most expensive namespaces, projected per month.'),
      cpuAllocated: sig('CPU allocated', 'sum(container_cpu_allocation{%(queriesSelector)s})', 'short', 'cores', desc='CPU cores allocated across all containers (max of request and usage).'),
      ramAllocated: sig('Memory allocated', 'sum(container_memory_allocation_bytes{%(queriesSelector)s})', 'bytes', 'bytes', desc='Memory allocated across all containers.'),
      cpuAllocByNode: sig('CPU allocation by node', 'sum by (node) (container_cpu_allocation{%(queriesSelector)s})', 'short', desc='Allocated cores per node.'),
      ramAllocByNode: sig('Memory allocation by node', 'sum by (node) (container_memory_allocation_bytes{%(queriesSelector)s})', 'bytes', desc='Allocated memory per node.'),
      pvCost: sig('PV hourly cost', 'sum by (persistentvolume) (pv_hourly_cost{%(queriesSelector)s})', 'currencyUSD', '{{persistentvolume}}', desc='Hourly cost per persistent volume.'),
      pvTotal: sig('PV cost', 'sum(pv_hourly_cost{%(queriesSelector)s})', 'currencyUSD', 'pv', desc='Hourly cost of all persistent volumes.'),
      pvcByNamespace: sig('PVC cost by namespace', 'sum by (namespace) (pod_pvc_allocation{%(queriesSelector)s} / 1024 / 1024 / 1024 * on (persistentvolume) group_left () pv_hourly_cost{%(queriesSelector)s})', 'currencyUSD', '{{namespace}}', desc='Hourly persistent volume cost attributed to namespaces through their claims.'),
      egress: sig('Network egress cost', 'sum(kubecost_network_internet_egress_cost{%(queriesSelector)s}) + sum(kubecost_network_region_egress_cost{%(queriesSelector)s}) + sum(kubecost_network_zone_egress_cost{%(queriesSelector)s})', 'currencyUSD', 'egress', desc='Configured per-GB egress prices (internet, cross-region, cross-zone) summed. Zero unless network costs are configured.'),
      version: sig('OpenCost version', 'max by (version) (opencost_build_info{%(queriesSelector)s})', 'short', '{{version}}', desc='Running OpenCost version.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov01_hourly: signals.clusterHourly.asStat('Cluster cost / hour'),
          ov02_monthly: signals.clusterMonthly.asStat('Cluster cost / month'),
          ov03_nodes: signals.nodes.asStat('Nodes'),
          ov04_spot: signals.spotNodes.asStat('Spot nodes'),
          ov05_cpu: signals.cpuAllocated.asStat('CPU allocated'),
          ov06_ram: signals.ramAllocated.asStat('Memory allocated'),
          ov07_pv: signals.pvTotal.asStat('PV cost / hour'),
          ov08_fee: signals.managementFee.asStat('Management fee / hour'),
          ov09_egress: signals.egress.asStat('Egress price'),
        },
      } + stats,
      {
        title: 'Namespaces',
        elements: {
          nsTotalCost: signals.nsTotalCost.asTimeSeries('Cost / hour by namespace'),
          nsTopMonthly: signals.nsTopMonthly.asTable('Top namespaces / month'),
          nsCpuCost: signals.nsCpuCost.asTimeSeries('CPU cost / hour by namespace'),
          nsRamCost: signals.nsRamCost.asTimeSeries('Memory cost / hour by namespace'),
          pvcByNamespace: signals.pvcByNamespace.asTimeSeries('PVC cost / hour by namespace'),
        },
      } + charts,
      {
        title: 'Nodes',
        elements: {
          nodeTotal: signals.nodeTotal.asTimeSeries('Node cost / hour'),
          nodeRates: signals.nodeCpu.asTimeSeries('Node rates: CPU core / GiB RAM per hour')
                     + panel.withTargetsMixin([signals.nodeRam.asTarget()]),
          cpuAllocByNode: signals.cpuAllocByNode.asTimeSeries('CPU allocated by node'),
          ramAllocByNode: signals.ramAllocByNode.asTimeSeries('Memory allocated by node'),
          pvCost: signals.pvCost.asTimeSeries('PV cost / hour'),
        },
      } + charts,
    ], [
      alert.rule.group('opencost', [
        alert.rule.new('OpencostDown',
                       (import 'libs/common-lib/alert/rule.libsonnet').targetDown('opencost_build_info', cfg.ruleSelector),
                       '10m',
                       'warning',
                       {},
                       { summary: 'OpenCost {{ $labels.instance }} is down; cost data stops.' }),
        alert.rule.new('OpencostNoNodeCostData',
                       'absent(node_total_hourly_cost' + rsBrace + ')',
                       '30m',
                       'warning',
                       {},
                       { summary: 'OpenCost is exporting no node cost data.' }),
        alert.rule.new('OpencostClusterCostJump',
                       'sum(node_total_hourly_cost' + rsBrace + ') > 1.5 * sum(avg_over_time(node_total_hourly_cost' + rsBrace + '[1d] offset 1d))',
                       '1h',
                       'warning',
                       {},
                       { summary: 'Cluster node cost is more than 50% above yesterday: nodes were added or repriced.' }),
      ]),
    ], [
      alert.rule.group('opencost.rules', [
        alert.rule.record('namespace:opencost_cpu_cost:hourly', 'sum by (namespace) (container_cpu_allocation' + rsBrace + ' * on (node) group_left () node_cpu_hourly_cost' + rsBrace + ')'),
        alert.rule.record('namespace:opencost_memory_cost:hourly', 'sum by (namespace) (container_memory_allocation_bytes' + rsBrace + ' / 1024 / 1024 / 1024 * on (node) group_left () node_ram_hourly_cost' + rsBrace + ')'),
        alert.rule.record('cluster:opencost_total_cost:hourly', 'sum(node_total_hourly_cost' + rsBrace + ') + sum(pv_hourly_cost' + rsBrace + ' or vector(0))'),
      ]),
    ]),
}
