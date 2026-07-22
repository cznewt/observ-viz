// observ-viz Kubernetes cluster pack — a hand-port of the essentials of
// github.com/kubernetes-monitoring/kubernetes-mixin, scoped to what this
// fleet's scrape pipeline actually collects (apiserver/kubelet/workqueue/
// cAdvisor-per-pod/KSM/PVC; scheduler and per-pod network metrics are not
// scraped, so those mixin boards are intentionally absent).
// The mixin's dashboards lean on its recording rules, so the k8s.rules
// essentials are ported too (deploy them to the ruler with the dashboards).
// Usage:
//   g.libs.kubernetes.cluster.new({}).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-kube-cluster',
      dashboardTitle: 'Kubernetes cluster',
      dashboardTags: ['kubernetes', 'cluster'],
      datasource: '${datasource}',
      selector: 'cluster=~"$cluster"',
      varMetric: 'kube_node_info',
      varLabels: ['cluster'],
      varMulti: false,
      podBoardUid: 'observ-viz-kube-pod',  // per-row drill target
      ruleSelector: '',  // static label filter for the alerting/recording rules
      docTabs: true,
      folderUid: 'software-kubernetes',
      folderTitle: 'Kubernetes',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local s = cfg.selector;
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';

    local sig(name, expr, unit, legend) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    // ---- table plumbing (house style: instant joins + sparkline trend cells) ----
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local rq(expr) = query.prometheus.new(cfg.datasource, expr);
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local sparkCell(extra={}) =
      { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16 } + extra };
    local pctSpark = [
      { id: 'unit', value: 'percent' },
      sparkCell({ gradientMode: 'scheme', thresholdsStyle: { mode: 'dashed' } }),
      { id: 'min', value: 0 },
      { id: 'max', value: 100 },
      { id: 'color', value: { mode: 'thresholds' } },
      { id: 'thresholds', value: { mode: 'absolute', steps: [
        { color: 'green', value: null }, { color: 'red', value: 80 },
      ] } },
    ];

    // ---- recording rules (ported from kubernetes-mixin k8s.rules) ----
    local ownerRule(kind, workloadType) =
      alert.rule.record(
        'namespace_workload_pod:kube_pod_owner:relabel',
        if kind == 'ReplicaSet' then
          // deployment: pod -> replicaset -> deployment owner chain.
          'sum by (cluster, namespace, workload, pod) (label_replace(label_replace(kube_pod_owner{owner_kind="ReplicaSet"' + rsComma + '}, "replicaset", "$1", "owner_name", "(.*)") * on (replicaset, namespace, cluster) group_left (owner_name) topk by (replicaset, namespace, cluster) (1, max by (replicaset, namespace, owner_name, cluster) (kube_replicaset_owner' + rsBrace + ')), "workload", "$1", "owner_name", "(.*)"))'
        else
          'sum by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{owner_kind="' + kind + '"' + rsComma + '}, "workload", "$1", "owner_name", "(.*)"))',
        { workload_type: workloadType },
      );
    local rules = [
      alert.rule.group('k8s-cluster.rules', [
        alert.rule.record(
          'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate',
          'sum by (cluster, namespace, pod, container) (irate(container_cpu_usage_seconds_total{container!="", pod!=""' + rsComma + '}[5m]))',
          {},
        ),
        alert.rule.record('namespace_cpu:kube_pod_container_resource_requests:sum',
                          'sum by (cluster, namespace) (kube_pod_container_resource_requests{resource="cpu"' + rsComma + '})', {}),
        alert.rule.record('namespace_cpu:kube_pod_container_resource_limits:sum',
                          'sum by (cluster, namespace) (kube_pod_container_resource_limits{resource="cpu"' + rsComma + '})', {}),
        alert.rule.record('namespace_memory:kube_pod_container_resource_requests:sum',
                          'sum by (cluster, namespace) (kube_pod_container_resource_requests{resource="memory"' + rsComma + '})', {}),
        alert.rule.record('namespace_memory:kube_pod_container_resource_limits:sum',
                          'sum by (cluster, namespace) (kube_pod_container_resource_limits{resource="memory"' + rsComma + '})', {}),
        ownerRule('ReplicaSet', 'deployment'),
        ownerRule('StatefulSet', 'statefulset'),
        ownerRule('DaemonSet', 'daemonset'),
        ownerRule('Job', 'job'),
      ]),
    ];

    // ---- alerts (kubernetes-mixin kubernetes-apps / resources subset) ----
    local alerts = [
      alert.rule.group('kubernetes-apps', [
        alert.rule.new('KubePodCrashLooping',
                       'max_over_time(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"' + rsComma + '}[5m]) >= 1',
                       '15m', 'warning', {},
                       { summary: 'Pod is crash looping.', description: '{{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) is in waiting state CrashLoopBackOff.' }),
        alert.rule.new('KubePodNotReady',
                       'sum by (cluster, namespace, pod) (max by (cluster, namespace, pod) (kube_pod_status_phase{phase=~"Pending|Unknown|Failed"' + rsComma + '}) * on (cluster, namespace, pod) group_left (owner_kind) topk by (cluster, namespace, pod) (1, max by (cluster, namespace, pod, owner_kind) (kube_pod_owner{owner_kind!="Job"}))) > 0',
                       '15m', 'warning', {},
                       { summary: 'Pod has been in a non-ready state for more than 15 minutes.', description: '{{ $labels.namespace }}/{{ $labels.pod }} is not ready.' }),
        alert.rule.new('KubeDeploymentReplicasMismatch',
                       '(kube_deployment_spec_replicas' + rsBrace + ' > kube_deployment_status_replicas_available' + rsBrace + ') and (changes(kube_deployment_status_replicas_updated' + rsBrace + '[10m]) == 0)',
                       '15m', 'warning', {},
                       { summary: 'Deployment has not matched the expected number of replicas.', description: '{{ $labels.namespace }}/{{ $labels.deployment }} replica mismatch.' }),
        alert.rule.new('KubeStatefulSetReplicasMismatch',
                       '(kube_statefulset_status_replicas_ready' + rsBrace + ' != kube_statefulset_status_replicas' + rsBrace + ') and (changes(kube_statefulset_status_replicas_updated' + rsBrace + '[10m]) == 0)',
                       '15m', 'warning', {},
                       { summary: 'StatefulSet has not matched the expected number of replicas.', description: '{{ $labels.namespace }}/{{ $labels.statefulset }} replica mismatch.' }),
        alert.rule.new('KubeContainerWaiting',
                       'sum by (cluster, namespace, pod, container, reason) (kube_pod_container_status_waiting_reason{reason!="CrashLoopBackOff"' + rsComma + '}) > 0',
                       '1h', 'warning', {},
                       { summary: 'Pod container waiting longer than 1 hour.', description: '{{ $labels.namespace }}/{{ $labels.pod }} container {{ $labels.container }} waiting ({{ $labels.reason }}).' }),
        alert.rule.new('KubeCPUOvercommit',
                       'sum by (cluster) (namespace_cpu:kube_pod_container_resource_requests:sum' + rsBrace + ') - (sum by (cluster) (kube_node_status_allocatable{resource="cpu"' + rsComma + '}) - max by (cluster) (kube_node_status_allocatable{resource="cpu"' + rsComma + '})) > 0 and (sum by (cluster) (kube_node_status_allocatable{resource="cpu"' + rsComma + '}) - max by (cluster) (kube_node_status_allocatable{resource="cpu"' + rsComma + '})) > 0',
                       '10m', 'warning', {},
                       { summary: 'Cluster has overcommitted CPU resource requests.', description: 'CPU requests exceed what remains if the largest node fails.' }),
        alert.rule.new('KubeMemoryOvercommit',
                       'sum by (cluster) (namespace_memory:kube_pod_container_resource_requests:sum' + rsBrace + ') - (sum by (cluster) (kube_node_status_allocatable{resource="memory"' + rsComma + '}) - max by (cluster) (kube_node_status_allocatable{resource="memory"' + rsComma + '})) > 0 and (sum by (cluster) (kube_node_status_allocatable{resource="memory"' + rsComma + '}) - max by (cluster) (kube_node_status_allocatable{resource="memory"' + rsComma + '})) > 0',
                       '10m', 'warning', {},
                       { summary: 'Cluster has overcommitted memory resource requests.', description: 'Memory requests exceed what remains if the largest node fails.' }),
        alert.rule.new('KubePersistentVolumeFillingUp',
                       '(kubelet_volume_stats_available_bytes' + rsBrace + ' / kubelet_volume_stats_capacity_bytes' + rsBrace + ') < 0.15 and kubelet_volume_stats_used_bytes' + rsBrace + ' > 0 and predict_linear(kubelet_volume_stats_available_bytes' + rsBrace + '[6h], 4 * 24 * 3600) < 0',
                       '1h', 'warning', {},
                       { summary: 'PersistentVolume is filling up.', description: 'PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is expected to fill up within four days.' }),
      ]),
    ];

    // ---- timeseries signals (control plane + kubelet) ----
    local signals = {
      apiserverRate: sig('API server requests', 'sum by (code) (rate(apiserver_request_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{code}}'),
      apiserverErrors: sig('API server 5xx ratio', 'sum (rate(apiserver_request_total{code=~"5..", %(queriesSelector)s}[$__rate_interval])) / sum (rate(apiserver_request_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', '5xx'),
      apiserverInflight: sig('API server inflight', 'sum by (request_kind) (apiserver_current_inflight_requests{%(queriesSelector)s})', 'short', '{{request_kind}}'),
      workqueueDepth: sig('Workqueue depth', 'sum (workqueue_depth{%(queriesSelector)s})', 'short', 'depth'),
      workqueueAdds: sig('Workqueue adds', 'sum (rate(workqueue_adds_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'adds'),
      kubeletPods: sig('Kubelet running pods', 'sum by (instance) (kubelet_running_pods{%(queriesSelector)s})', 'short', '{{instance}}'),
      kubeletErrors: sig('Kubelet runtime errors', 'sum by (instance) (rate(kubelet_runtime_operations_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{instance}}'),
    };

    // ---- stats row ----
    local numStat(title, expr, unit) =
      panel.stat.new(title)
      + panel.stat.withTargets([tq(expr)])
      + panel.stat.withOptions({ reduceOptions: { values: false, calcs: ['lastNotNull'] }, colorMode: 'value' })
      + panel.stat.withUnit(unit);
    local pctStat(title, expr) =
      numStat(title, expr, 'percent')
      + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 80 }, { color: 'red', value: 100 }]);

    // ---- Namespaces table ----
    local namespacesTable =
      panel.table.new('Namespaces')
      + panel.table.withTargets([
        tq('count by (namespace) (kube_pod_info{' + s + '})'),
        tq('sum by (namespace) (namespace_cpu:kube_pod_container_resource_requests:sum{' + s + '})'),
        tq('sum by (namespace) (namespace_memory:kube_pod_container_resource_requests:sum{' + s + '})'),
        rq('sum by (namespace) (node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{' + s + '})'),
        rq('sum by (namespace) (container_memory_working_set_bytes{container!="", pod!="", ' + s + '})'),
      ])
      + panel.table.withTransformations([
        { id: 'timeSeriesTable', options: {} },
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['namespace', 'Value #A', 'Value #B', 'Value #C', 'Trend #D', 'Trend #E'] } } },
        { id: 'seriesToColumns', options: { byField: 'namespace' } },
        { id: 'organize', options: {
          indexByName: { namespace: 0, 'Value #A': 1, 'Trend #D': 2, 'Value #B': 3, 'Trend #E': 4, 'Value #C': 5 },
          renameByName: { namespace: 'Namespace', 'Value #A': 'Pods', 'Trend #D': 'CPU', 'Value #B': 'CPU Req', 'Trend #E': 'Memory', 'Value #C': 'Mem Req' },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Namespace', desc: false }] } },
      ])
      + panel.table.withOverrides([
        ov('Namespace', [{ id: 'links', value: [{ title: '${__value.raw}', url: '/d/' + cfg.podBoardUid + '?var-namespace=${__value.raw}' }] }]),
        ov('Pods', [{ id: 'custom.width', value: 60 }]),
        ov('^CPU$', [{ id: 'unit', value: 'short' }, { id: 'decimals', value: 2 }, sparkCell()]),
        ov('CPU Req', [{ id: 'unit', value: 'short' }, { id: 'decimals', value: 1 }, { id: 'custom.width', value: 90 }]),
        ov('^Memory$', [{ id: 'unit', value: 'bytes' }, sparkCell()]),
        ov('Mem Req', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 100 }]),
      ]);

    // ---- Nodes table (usage as % of allocatable; cadvisor instance == node name) ----
    local nodesTable =
      panel.table.new('Nodes')
      + panel.table.withTargets([
        tq('count by (node) (kube_pod_info{' + s + '})'),
        tq('max by (node) (kube_node_status_allocatable{resource="cpu", ' + s + '})'),
        tq('max by (node) (kube_node_status_allocatable{resource="memory", ' + s + '})'),
        rq('label_replace(100 * sum by (instance) (rate(container_cpu_usage_seconds_total{container!="", pod!="", ' + s + '}[$__rate_interval])), "node", "$1", "instance", "(.+)") / on (node) max by (node) (kube_node_status_allocatable{resource="cpu", ' + s + '})'),
        rq('label_replace(100 * sum by (instance) (container_memory_working_set_bytes{container!="", pod!="", ' + s + '}), "node", "$1", "instance", "(.+)") / on (node) max by (node) (kube_node_status_allocatable{resource="memory", ' + s + '})'),
      ])
      + panel.table.withTransformations([
        { id: 'timeSeriesTable', options: {} },
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['node', 'Value #A', 'Value #B', 'Value #C', 'Trend #D', 'Trend #E'] } } },
        { id: 'seriesToColumns', options: { byField: 'node' } },
        { id: 'organize', options: {
          indexByName: { node: 0, 'Value #A': 1, 'Trend #D': 2, 'Value #B': 3, 'Trend #E': 4, 'Value #C': 5 },
          renameByName: { node: 'Node', 'Value #A': 'Pods', 'Trend #D': 'CPU %', 'Value #B': 'CPU Alloc', 'Trend #E': 'Mem %', 'Value #C': 'Mem Alloc' },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Node', desc: false }] } },
      ])
      + panel.table.withOverrides([
        ov('Pods', [{ id: 'custom.width', value: 60 }]),
        ov('CPU %|Mem %', pctSpark),
        ov('CPU Alloc', [{ id: 'unit', value: 'short' }, { id: 'custom.width', value: 90 }]),
        ov('Mem Alloc', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 100 }]),
      ]);

    // ---- Workloads table (via the ported owner relabel rule) ----
    local workloadsTable =
      panel.table.new('Workloads')
      + panel.table.withTargets([
        tq('count by (namespace, workload, workload_type) (namespace_workload_pod:kube_pod_owner:relabel{' + s + '})'),
        rq('sum by (namespace, workload) (node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{' + s + '} * on (cluster, namespace, pod) group_left (workload) namespace_workload_pod:kube_pod_owner:relabel{' + s + '})'),
        rq('sum by (namespace, workload) (container_memory_working_set_bytes{container!="", pod!="", ' + s + '} * on (cluster, namespace, pod) group_left (workload) namespace_workload_pod:kube_pod_owner:relabel{' + s + '})'),
      ])
      + panel.table.withTransformations([
        { id: 'timeSeriesTable', options: {} },
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['workload', 'namespace', 'workload_type', 'Value #A', 'Trend #B', 'Trend #C'] } } },
        { id: 'seriesToColumns', options: { byField: 'workload' } },
        { id: 'organize', options: {
          excludeByName: { 'namespace 2': true, 'namespace 3': true },
          indexByName: { workload: 0, namespace: 1, workload_type: 2, 'Value #A': 3, 'Trend #B': 4, 'Trend #C': 5 },
          renameByName: { workload: 'Workload', namespace: 'Namespace', workload_type: 'Type', 'Value #A': 'Pods', 'Trend #B': 'CPU', 'Trend #C': 'Memory' },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Namespace', desc: false }] } },
      ])
      + panel.table.withOverrides([
        ov('Type', [{ id: 'custom.width', value: 100 }]),
        ov('Pods', [{ id: 'custom.width', value: 60 }]),
        ov('^CPU$', [{ id: 'unit', value: 'short' }, { id: 'decimals', value: 2 }, sparkCell()]),
        ov('^Memory$', [{ id: 'unit', value: 'bytes' }, sparkCell()]),
      ]);

    // ---- Storage table (PVCs) ----
    local pvcTable =
      panel.table.new('Persistent volume claims')
      + panel.table.withTargets([
        tq('max by (namespace, persistentvolumeclaim) (kubelet_volume_stats_capacity_bytes{' + s + '})'),
        rq('100 * max by (namespace, persistentvolumeclaim) (kubelet_volume_stats_used_bytes{' + s + '}) / max by (namespace, persistentvolumeclaim) (kubelet_volume_stats_capacity_bytes{' + s + '})'),
      ])
      + panel.table.withTransformations([
        { id: 'timeSeriesTable', options: {} },
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['persistentvolumeclaim', 'namespace', 'Value #A', 'Trend #B'] } } },
        { id: 'seriesToColumns', options: { byField: 'persistentvolumeclaim' } },
        { id: 'organize', options: {
          excludeByName: { 'namespace 2': true },
          indexByName: { namespace: 0, persistentvolumeclaim: 1, 'Trend #B': 2, 'Value #A': 3 },
          renameByName: { namespace: 'Namespace', persistentvolumeclaim: 'PVC', 'Trend #B': 'Used %', 'Value #A': 'Capacity' },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Namespace', desc: false }] } },
      ])
      + panel.table.withOverrides([
        ov('Used %', pctSpark),
        ov('Capacity', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 100 }]),
      ]);

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          ovNodes: numStat('Nodes', 'count(kube_node_info{' + s + '})', 'short'),
          ovNamespaces: numStat('Namespaces', 'count(count by (namespace) (kube_pod_info{' + s + '}))', 'short'),
          ovPods: numStat('Pods running', 'sum(kube_pod_status_phase{phase="Running", ' + s + '})', 'short'),
          ovCpuAlloc: numStat('CPU allocatable', 'sum(kube_node_status_allocatable{resource="cpu", ' + s + '})', 'short'),
          ovCpuCommit: pctStat('CPU requests commitment', '100 * sum(namespace_cpu:kube_pod_container_resource_requests:sum{' + s + '}) / sum(kube_node_status_allocatable{resource="cpu", ' + s + '})'),
          ovMemCommit: pctStat('Memory requests commitment', '100 * sum(namespace_memory:kube_pod_container_resource_requests:sum{' + s + '}) / sum(kube_node_status_allocatable{resource="memory", ' + s + '})'),
        },
      },
      { title: 'Namespaces', width: 24, height: 10, elements: { namespaces: namespacesTable } },
      { title: 'Nodes', width: 24, height: 6, elements: { nodes: nodesTable } },
      { title: 'Workloads', width: 24, height: 10, elements: { workloads: workloadsTable } },
      {
        title: 'Control plane',
        width: 12,
        height: 7,
        elements: {
          apiserverRate: signals.apiserverRate.asTimeSeries('API server requests by code'),
          apiserverErrors: signals.apiserverErrors.asTimeSeries('API server 5xx ratio'),
          apiserverInflight: signals.apiserverInflight.asTimeSeries('API server inflight requests'),
          workqueueDepth: signals.workqueueDepth.asTimeSeries('Workqueue depth'),
          workqueueAdds: signals.workqueueAdds.asTimeSeries('Workqueue adds'),
          kubeletPods: signals.kubeletPods.asTimeSeries('Kubelet running pods'),
          kubeletErrors: signals.kubeletErrors.asTimeSeries('Kubelet runtime errors'),
        },
      },
      { title: 'Storage', width: 24, height: 7, elements: { pvcs: pvcTable } },
    ], alerts, rules),
}
