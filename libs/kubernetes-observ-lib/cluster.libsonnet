// observ-viz Kubernetes cluster pack — a hand-port of the essentials of
// github.com/kubernetes-monitoring/kubernetes-mixin, scoped to what this
// fleet's scrape pipeline actually collects (apiserver/kubelet/workqueue/
// cAdvisor-per-pod/KSM/PVC; scheduler and per-pod network metrics are not
// scraped, so those mixin boards are intentionally absent).
// The mixin's dashboards lean on its recording rules, so the k8s.rules
// essentials are ported too (deploy them to the ruler with the dashboards).
// Its alerts are ported too: kubernetes-apps, -storage, -system (control
// plane, kubelet, certificates) and kube-apiserver-slos with the burn-rate
// recording rules; the Down alerts work per cluster, so several clusters can
// share one ruler.
// Usage:
//   g.libs.kubernetes.cluster.new({}).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local tabs = import 'libs/common-lib/tabs.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'kube-cluster',
      dashboardTitle: 'Kubernetes cluster',
      dashboardTags: ['kubernetes', 'cluster-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],

      datasource: '${datasource}',
      selector: 'cluster=~"$cluster"',
      varMetric: 'kube_node_info',
      lokiDatasource: true,  // the Logs tab reads whichever Loki is selected
      tracesDatasource: 'newt-tempo',  // site Tempo (kspan + salt job spans)
      varLabels: ['cluster'],
      varMulti: false,
      podBoardUid: 'observ-viz-kube-pod',  // per-row drill target
      ruleSelector: '',  // static label filter for the alerting/recording rules
      nodesMissingSelector: '',  // nodes KubeNodesMissing counts, e.g. 'node=~".*worker.*"'
      nodesMissingRatio: 0.75,  // KubeNodesMissing fires below this share of the nodes seen 1-2h ago
      // control-plane scrape jobs (regexes): k8s-monitoring's names, then the mixin defaults
      apiserverJob: 'integrations/kubernetes/kube-apiserver|apiserver|kube-apiserver',
      kubeletJob: 'integrations/kubernetes/kubelet|kubelet',
      controllerManagerJob: 'kube-controller-manager|integrations/kubernetes/kube-controller-manager',
      schedulerJob: 'kube-scheduler|integrations/kubernetes/kube-scheduler',
      proxyJob: 'integrations/kubernetes/kube-proxy|kube-proxy',
      // kubeadm binds the controller-manager, scheduler and kube-proxy metrics to
      // 127.0.0.1, so their scrape often never works: their Down/Unreachable alerts
      // only cover a component that was up within this window (and resolve once
      // it has been down for longer)
      controlPlaneWindow: '1d',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // the Namespaces tab already tables what runs here
      overviewInstances: false,
      // a cluster board, not a workload: no per-pod rows on its Overview
      overviewPods: false,
      // Platform / Kubernetes, beside the pod and container boards
      folderPath: (import 'libs/common-lib/folders.libsonnet').kubernetes,
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
        { color: 'green', value: null },
        { color: 'red', value: 80 },
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

    // ---- API server SLO (ported from kubernetes-mixin kube-apiserver-burnrate.rules) ----
    // a request is bad when it fails (5xx) or is slow: reads over 1s (one object),
    // 5s (a namespace) or 30s (the whole cluster), writes over 1s. Streaming and
    // proxied subresources do not count.
    local api(extra) = '{job=~"' + cfg.apiserverJob + '"' + (if extra != '' then ', ' + extra else '') + rsComma + '}';
    local apiRate(metric, extra, w) = 'rate(' + metric + api(extra) + '[' + w + '])';
    local sliSub = 'subresource!~"proxy|attach|log|exec|portforward"';
    // alternatives sorted: Mimir 2.10 drops a value from the mixin's
    // verb=~"LIST|GET" (and POST from "POST|PUT|PATCH|DELETE")
    local verbs = { read: 'verb=~"GET|LIST"', write: 'verb=~"DELETE|PATCH|POST|PUT"' };
    local fastBuckets = {
      read: [@'scope=~"resource|", le=~"1(\\.0)?"', @'scope="namespace", le=~"5(\\.0)?"', @'scope="cluster", le=~"30(\\.0)?"'],
      write: [@'le=~"1(\\.0)?"'],
    };
    // the per-scope buckets and the 5xx counter are summed as one union (`or`),
    // so a scope without requests or an API server that has not answered a 5xx
    // since its start does not empty the whole SLI
    local fastEnough(verb, w) =
      'sum by (cluster) (' + std.join(' or ', [
        apiRate('apiserver_request_sli_duration_seconds_bucket', verbs[verb] + ', ' + sliSub + ', ' + b, w)
        for b in fastBuckets[verb]
      ]) + ')';
    local errors(verb, w) =
      'sum by (cluster) (' + apiRate('apiserver_request_total', verbs[verb] + ', code=~"5.."', w) + ' or 0 * ' + apiRate('apiserver_request_total', verbs[verb], w) + ')';
    local badEvents(verb, w) =
      '(sum by (cluster) (' + apiRate('apiserver_request_sli_duration_seconds_count', verbs[verb] + ', ' + sliSub, w) + ') - ' + fastEnough(verb, w) + ') + ' + errors(verb, w);
    local events(verb, w) = 'sum by (cluster) (' + apiRate('apiserver_request_total', verbs[verb], w) + ')';
    local badRecord = 'cluster_verb:apiserver_request_sli_bad_events:rate5m' + rsBrace;
    local eventsRecord = 'cluster_verb:apiserver_request_sli_events:rate5m' + rsBrace;
    local apiserverBurnrate = alert.rule.group('kube-apiserver-burnrate.rules', std.flattenArrays([
      [
        alert.rule.record('cluster_verb:apiserver_request_sli_bad_events:rate5m', badEvents(verb, '5m'), { verb: verb }),
        alert.rule.record('cluster_verb:apiserver_request_sli_events:rate5m', events(verb, '5m'), { verb: verb }),
      ]
      for verb in ['read', 'write']
    ]) + [
      alert.rule.record('apiserver_request:burnrate5m', badRecord + ' / ' + eventsRecord, {}),
    ] + [
      alert.rule.record('apiserver_request:burnrate' + w, '(' + badEvents(verb, w) + ') / ' + events(verb, w), { verb: verb })
      for w in ['30m', '1h', '2h', '6h']
      for verb in ['read', 'write']
    ] + [
      // the long windows average the 5m records instead of reading days of buckets
      alert.rule.record('apiserver_request:burnrate' + w, 'avg_over_time(' + badRecord + '[' + w + ']) / avg_over_time(' + eventsRecord + '[' + w + '])', {})
      for w in ['1d', '3d']
    ]);

    local rules = [
      alert.rule.group('k8s-cluster.rules', [
        alert.rule.record(
          'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate',
          'sum by (cluster, namespace, pod, container) (irate(container_cpu_usage_seconds_total{container!="", pod!=""' + rsComma + '}[5m]))',
          {},
        ),
        alert.rule.record('namespace_cpu:kube_pod_container_resource_requests:sum',
                          'sum by (cluster, namespace) (kube_pod_container_resource_requests{resource="cpu"' + rsComma + '})',
                          {}),
        alert.rule.record('namespace_cpu:kube_pod_container_resource_limits:sum',
                          'sum by (cluster, namespace) (kube_pod_container_resource_limits{resource="cpu"' + rsComma + '})',
                          {}),
        alert.rule.record('namespace_memory:kube_pod_container_resource_requests:sum',
                          'sum by (cluster, namespace) (kube_pod_container_resource_requests{resource="memory"' + rsComma + '})',
                          {}),
        alert.rule.record('namespace_memory:kube_pod_container_resource_limits:sum',
                          'sum by (cluster, namespace) (kube_pod_container_resource_limits{resource="memory"' + rsComma + '})',
                          {}),
        ownerRule('ReplicaSet', 'deployment'),
        ownerRule('StatefulSet', 'statefulset'),
        ownerRule('DaemonSet', 'daemonset'),
        ownerRule('Job', 'job'),
      ]),
      apiserverBurnrate,
    ];

    // ---- alerts (kubernetes-mixin apps / storage / system / API server SLO, plus node health) ----
    local pressure = 'kube_node_status_condition{condition=~"MemoryPressure|DiskPressure|PIDPressure", status="true"' + rsComma + '}';
    local nodeSel = std.join(', ', std.filter(function(x) x != '', [cfg.nodesMissingSelector, cfg.ruleSelector]));
    local nodeCount = 'count by (cluster) (group by (cluster, node) (kube_node_info' + (if nodeSel != '' then '{' + nodeSel + '}' else '') + '))';
    local nodeBaseline = 'max_over_time(' + nodeCount + '[1h:5m] offset 1h)';
    // control-plane liveness, per cluster so that several clusters can share one
    // ruler (the mixin's absent(up) only notices the last cluster's target going):
    // <X>Down = the cluster still reports nodes but no <X> instance is up;
    // <X>InstanceUnreachable = one instance is down. `guarded` components count
    // only when they were up within cfg.controlPlaneWindow.
    local upOf(job) = 'up{job=~"' + job + '"' + rsComma + '}';
    local seenUp(job) = '(max_over_time(' + upOf(job) + '[' + cfg.controlPlaneWindow + ']) == 1)';
    local liveness(name, title, job, guarded) = [
      alert.rule.new(name + 'Down',
                     (if guarded then 'group by (cluster) ' + seenUp(job) + ' and on (cluster) ' else '')
                     + 'group by (cluster) (kube_node_info' + rsBrace + ') unless on (cluster) group by (cluster) (' + upOf(job) + ' == 1)',
                     '15m',
                     'critical',
                     {},
                     { summary: title + ' is down.', description: 'No ' + title + ' target of {{ $labels.cluster }} has been up for 15 minutes.' }),
      alert.rule.new(name + 'InstanceUnreachable',
                     '(' + upOf(job) + ' == 0)' + (if guarded then ' and on (cluster, job, instance) ' + seenUp(job) else ''),
                     '15m',
                     'warning',
                     {},
                     { summary: title + ' instance is unreachable.', description: title + ' {{ $labels.instance }} on {{ $labels.cluster }} has been unreachable for 15 minutes.' }),
    ];
    // PVCs that never fill (read-only) or opted out of the storage alerts
    local pvcExcluded =
      ' unless on (cluster, namespace, persistentvolumeclaim) kube_persistentvolumeclaim_access_mode{access_mode="ReadOnlyMany"' + rsComma + '} == 1'
      + ' unless on (cluster, namespace, persistentvolumeclaim) kube_persistentvolumeclaim_labels{label_excluded_from_alerts="true"' + rsComma + '} == 1';
    local clientCertTtl = 'histogram_quantile(0.01, sum without (namespace, service, endpoint) (rate(apiserver_client_certificate_expiration_seconds_bucket' + api('') + '[5m])))';
    local alerts = [
      alert.rule.group('kubernetes-apps', [
        alert.rule.new('KubePodCrashLooping',
                       'max_over_time(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"' + rsComma + '}[5m]) >= 1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Pod is crash looping.', description: '{{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) is in waiting state CrashLoopBackOff.' }),
        alert.rule.new('KubePodNotReady',
                       'sum by (cluster, namespace, pod) (max by (cluster, namespace, pod) (kube_pod_status_phase{phase=~"Pending|Unknown|Failed"' + rsComma + '}) * on (cluster, namespace, pod) group_left (owner_kind) topk by (cluster, namespace, pod) (1, max by (cluster, namespace, pod, owner_kind) (kube_pod_owner{owner_kind!="Job"}))) > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Pod has been in a non-ready state for more than 15 minutes.', description: '{{ $labels.namespace }}/{{ $labels.pod }} is not ready.' }),
        alert.rule.new('KubeDeploymentReplicasMismatch',
                       '(kube_deployment_spec_replicas' + rsBrace + ' > kube_deployment_status_replicas_available' + rsBrace + ') and (changes(kube_deployment_status_replicas_updated' + rsBrace + '[10m]) == 0)',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Deployment has not matched the expected number of replicas.', description: '{{ $labels.namespace }}/{{ $labels.deployment }} replica mismatch.' }),
        alert.rule.new('KubeStatefulSetReplicasMismatch',
                       '(kube_statefulset_status_replicas_ready' + rsBrace + ' != kube_statefulset_status_replicas' + rsBrace + ') and (changes(kube_statefulset_status_replicas_updated' + rsBrace + '[10m]) == 0)',
                       '15m',
                       'warning',
                       {},
                       { summary: 'StatefulSet has not matched the expected number of replicas.', description: '{{ $labels.namespace }}/{{ $labels.statefulset }} replica mismatch.' }),
        alert.rule.new('KubeContainerWaiting',
                       'sum by (cluster, namespace, pod, container, reason) (kube_pod_container_status_waiting_reason{reason!="CrashLoopBackOff"' + rsComma + '}) > 0',
                       '1h',
                       'warning',
                       {},
                       { summary: 'Pod container waiting longer than 1 hour.', description: '{{ $labels.namespace }}/{{ $labels.pod }} container {{ $labels.container }} waiting ({{ $labels.reason }}).' }),
        alert.rule.new('KubeCPUOvercommit',
                       'sum by (cluster) (namespace_cpu:kube_pod_container_resource_requests:sum' + rsBrace + ') - (sum by (cluster) (kube_node_status_allocatable{resource="cpu"' + rsComma + '}) - max by (cluster) (kube_node_status_allocatable{resource="cpu"' + rsComma + '})) > 0 and (sum by (cluster) (kube_node_status_allocatable{resource="cpu"' + rsComma + '}) - max by (cluster) (kube_node_status_allocatable{resource="cpu"' + rsComma + '})) > 0',
                       '10m',
                       'warning',
                       {},
                       { summary: 'Cluster has overcommitted CPU resource requests.', description: 'CPU requests exceed what remains if the largest node fails.' }),
        alert.rule.new('KubeMemoryOvercommit',
                       'sum by (cluster) (namespace_memory:kube_pod_container_resource_requests:sum' + rsBrace + ') - (sum by (cluster) (kube_node_status_allocatable{resource="memory"' + rsComma + '}) - max by (cluster) (kube_node_status_allocatable{resource="memory"' + rsComma + '})) > 0 and (sum by (cluster) (kube_node_status_allocatable{resource="memory"' + rsComma + '}) - max by (cluster) (kube_node_status_allocatable{resource="memory"' + rsComma + '})) > 0',
                       '10m',
                       'warning',
                       {},
                       { summary: 'Cluster has overcommitted memory resource requests.', description: 'Memory requests exceed what remains if the largest node fails.' }),
        alert.rule.new('KubeDeploymentGenerationMismatch',
                       'kube_deployment_status_observed_generation' + rsBrace + ' != kube_deployment_metadata_generation' + rsBrace,
                       '15m',
                       'warning',
                       {},
                       { summary: 'Deployment generation mismatch due to possible roll-back.', description: '{{ $labels.namespace }}/{{ $labels.deployment }} has not observed its latest generation: the rollout failed and was not rolled back.' }),
        alert.rule.new('KubeDeploymentRolloutStuck',
                       'kube_deployment_status_condition{condition="Progressing", status="false"' + rsComma + '} != 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Deployment rollout is not progressing.', description: 'The rollout of {{ $labels.namespace }}/{{ $labels.deployment }} has not progressed for 15 minutes.' }),
        alert.rule.new('KubeStatefulSetGenerationMismatch',
                       'kube_statefulset_status_observed_generation' + rsBrace + ' != kube_statefulset_metadata_generation' + rsBrace,
                       '15m',
                       'warning',
                       {},
                       { summary: 'StatefulSet generation mismatch due to possible roll-back.', description: '{{ $labels.namespace }}/{{ $labels.statefulset }} has not observed its latest generation: the rollout failed and was not rolled back.' }),
        alert.rule.new('KubeStatefulSetUpdateNotRolledOut',
                       '(max by (cluster, namespace, statefulset) (kube_statefulset_status_current_revision' + rsBrace + ' unless kube_statefulset_status_update_revision' + rsBrace + ') * on (cluster, namespace, statefulset) (kube_statefulset_replicas' + rsBrace + ' != kube_statefulset_status_replicas_updated' + rsBrace + ')) and on (cluster, namespace, statefulset) (changes(kube_statefulset_status_replicas_updated' + rsBrace + '[5m]) == 0)',
                       '15m',
                       'warning',
                       {},
                       { summary: 'StatefulSet update has not been rolled out.', description: 'The update of {{ $labels.namespace }}/{{ $labels.statefulset }} has not reached all replicas.' }),
        alert.rule.new('KubeDaemonSetRolloutStuck',
                       '((kube_daemonset_status_current_number_scheduled' + rsBrace + ' != kube_daemonset_status_desired_number_scheduled' + rsBrace + ') or (kube_daemonset_status_number_misscheduled' + rsBrace + ' != 0) or (kube_daemonset_status_updated_number_scheduled' + rsBrace + ' != kube_daemonset_status_desired_number_scheduled' + rsBrace + ') or (kube_daemonset_status_number_available' + rsBrace + ' != kube_daemonset_status_desired_number_scheduled' + rsBrace + ')) and (changes(kube_daemonset_status_updated_number_scheduled' + rsBrace + '[5m]) == 0)',
                       '15m',
                       'warning',
                       {},
                       { summary: 'DaemonSet rollout is stuck.', description: '{{ $labels.namespace }}/{{ $labels.daemonset }} has not finished or progressed for 15 minutes.' }),
        alert.rule.new('KubeDaemonSetNotScheduled',
                       'kube_daemonset_status_desired_number_scheduled' + rsBrace + ' - kube_daemonset_status_current_number_scheduled' + rsBrace + ' > 0',
                       '10m',
                       'warning',
                       {},
                       { summary: 'DaemonSet pods are not scheduled.', description: '{{ $value }} pods of {{ $labels.namespace }}/{{ $labels.daemonset }} are not scheduled.' }),
        alert.rule.new('KubeDaemonSetMisScheduled',
                       'kube_daemonset_status_number_misscheduled' + rsBrace + ' > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'DaemonSet pods are misscheduled.', description: '{{ $value }} pods of {{ $labels.namespace }}/{{ $labels.daemonset }} run where they are not supposed to.' }),
        alert.rule.new('KubeJobNotCompleted',
                       'time() - max by (cluster, namespace, job_name) (kube_job_status_start_time' + rsBrace + ' and kube_job_status_active' + rsBrace + ' > 0) > 43200 unless on (cluster, namespace, job_name) max by (cluster, namespace, job_name) (kube_job_labels{label_excluded_from_alerts="true"' + rsComma + '} == 1)',
                       '0s',
                       'warning',
                       {},
                       { summary: 'Job did not complete in time.', description: '{{ $labels.namespace }}/{{ $labels.job_name }} has been running for more than 12 hours.' }),
        alert.rule.new('KubeJobFailed',
                       'kube_job_failed' + rsBrace + ' > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Job failed to complete.', description: '{{ $labels.namespace }}/{{ $labels.job_name }} failed; deleting the failed Job after investigation clears the alert.' }),
        alert.rule.new('KubePdbNotEnoughHealthyPods',
                       '(kube_poddisruptionbudget_status_desired_healthy' + rsBrace + ' - kube_poddisruptionbudget_status_current_healthy' + rsBrace + ') > 0 and kube_poddisruptionbudget_status_expected_pods' + rsBrace + ' > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'PodDisruptionBudget does not have enough healthy pods.', description: '{{ $labels.namespace }}/{{ $labels.poddisruptionbudget }} needs {{ $value }} more healthy pods.' }),
      ]),
      alert.rule.group('kubernetes-storage', [
        alert.rule.new('KubePersistentVolumeFillingUp',
                       '(kubelet_volume_stats_available_bytes' + rsBrace + ' / kubelet_volume_stats_capacity_bytes' + rsBrace + ') < 0.15 and kubelet_volume_stats_used_bytes' + rsBrace + ' > 0 and predict_linear(kubelet_volume_stats_available_bytes' + rsBrace + '[6h], 4 * 24 * 3600) < 0',
                       '1h',
                       'warning',
                       {},
                       { summary: 'PersistentVolume is filling up.', description: 'PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is expected to fill up within four days.' }),
        alert.rule.new('KubePersistentVolumeInodesFillingUp',
                       '(kubelet_volume_stats_inodes_free' + rsBrace + ' / kubelet_volume_stats_inodes' + rsBrace + ') < 0.03 and kubelet_volume_stats_inodes_used' + rsBrace + ' > 0' + pvcExcluded,
                       '1m',
                       'critical',
                       {},
                       { summary: 'PersistentVolume is running out of inodes.', description: 'PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} has only {{ $value | humanizePercentage }} of its inodes free.' }),
        alert.rule.new('KubePersistentVolumeInodesFillingUp',
                       '(kubelet_volume_stats_inodes_free' + rsBrace + ' / kubelet_volume_stats_inodes' + rsBrace + ') < 0.15 and kubelet_volume_stats_inodes_used' + rsBrace + ' > 0 and predict_linear(kubelet_volume_stats_inodes_free' + rsBrace + '[6h], 4 * 24 * 3600) < 0' + pvcExcluded,
                       '1h',
                       'warning',
                       {},
                       { summary: 'PersistentVolume is running out of inodes.', description: 'PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is expected to run out of inodes within four days ({{ $value | humanizePercentage }} free).' }),
        alert.rule.new('KubePersistentVolumeErrors',
                       'kube_persistentvolume_status_phase{phase=~"Failed|Pending"' + rsComma + '} > 0',
                       '5m',
                       'critical',
                       {},
                       { summary: 'PersistentVolume is having issues with provisioning.', description: 'PersistentVolume {{ $labels.persistentvolume }} on {{ $labels.cluster }} is {{ $labels.phase }}.' }),
      ]),
      alert.rule.group('kubernetes-nodes', [
        alert.rule.new('KubeNodePressure',
                       'sum by (cluster, node, condition) (' + pressure + ') > 0 and on (cluster, node) sum by (cluster, node) (kube_node_spec_unschedulable' + rsBrace + ') == 0',
                       '5m',
                       'warning',
                       {},
                       { summary: 'Node is under resource pressure.', description: '{{ $labels.node }} reports {{ $labels.condition }}.' }),
        alert.rule.new('KubeClusterPressure',
                       'count by (cluster, condition) (sum by (cluster, node, condition) (' + pressure + ') > 0) > 1',
                       '5m',
                       'critical',
                       {},
                       { summary: 'Several nodes are under the same resource pressure.', description: '{{ $value }} nodes in {{ $labels.cluster }} report {{ $labels.condition }}.' }),
        alert.rule.new('KubeNodesMissing',
                       '(' + nodeCount + ' or ' + nodeBaseline + ' * 0) / ' + nodeBaseline + ' < ' + cfg.nodesMissingRatio,
                       '5m',
                       'critical',
                       {},
                       { summary: 'Nodes have left the cluster.', description: '{{ $labels.cluster }} has {{ $value | humanizePercentage }} of the nodes it had 1-2 hours ago.' }),
        alert.rule.new('KubeNodeNotReady',
                       'kube_node_status_condition{condition="Ready", status="true"' + rsComma + '} == 0 and on (cluster, node) kube_node_spec_unschedulable' + rsBrace + ' == 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Node is not ready.', description: '{{ $labels.node }} on {{ $labels.cluster }} has been unready for 15 minutes.' }),
        // the mixin reads the node.kubernetes.io/unreachable taint, but
        // kube_node_spec_taint is not collected everywhere; the node controller
        // sets that taint when it turns the Ready condition Unknown
        alert.rule.new('KubeNodeUnreachable',
                       'kube_node_status_condition{condition="Ready", status="unknown"' + rsComma + '} == 1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Node is unreachable.', description: '{{ $labels.node }} on {{ $labels.cluster }} is unreachable; its workloads may be rescheduled.' }),
        alert.rule.new('KubeNodeReadinessFlapping',
                       'sum by (cluster, node) (changes(kube_node_status_condition{condition="Ready", status="true"' + rsComma + '}[15m])) > 2 and on (cluster, node) kube_node_spec_unschedulable' + rsBrace + ' == 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Node readiness status is flapping.', description: 'The readiness of {{ $labels.node }} on {{ $labels.cluster }} changed {{ $value }} times in 15 minutes.' }),
        alert.rule.new('KubeNodeEviction',
                       'sum by (cluster, eviction_signal, instance) (rate(kubelet_evictions' + rsBrace + '[15m])) * on (cluster, instance) group_left (node) max by (cluster, instance, node) (kubelet_node_name' + rsBrace + ') > 0',
                       '0s',
                       'info',
                       {},
                       { summary: 'Node is evicting pods.', description: '{{ $labels.node }} on {{ $labels.cluster }} is evicting pods ({{ $labels.eviction_signal }}).' }),
      ]),
      alert.rule.group('kubernetes-system', [
        alert.rule.new('KubeVersionMismatch',
                       'count by (cluster) (count by (cluster, git_version) (label_replace(kubernetes_build_info{job!~"kube-dns|coredns"' + rsComma + '}, "git_version", "$1", "git_version", "(v[0-9]*.[0-9]*).*"))) > 1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Different semantic versions of Kubernetes components are running.', description: '{{ $value }} different Kubernetes minor versions run on {{ $labels.cluster }}.' }),
        alert.rule.new('KubeClientErrors',
                       '(sum by (cluster, instance, job, namespace) (rate(rest_client_requests_total' + api('code=~"5.."') + '[5m])) / sum by (cluster, instance, job, namespace) (rate(rest_client_requests_total' + api('') + '[5m]))) > 0.01',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Kubernetes API server client is experiencing errors.', description: 'The client of {{ $labels.job }}/{{ $labels.instance }} on {{ $labels.cluster }} sees {{ $value | humanizePercentage }} errors.' }),
      ]),
      alert.rule.group('kubernetes-system-apiserver', [
        alert.rule.new('KubeClientCertificateExpiration',
                       clientCertTtl + ' < 604800 and on (cluster, job, instance) apiserver_client_certificate_expiration_seconds_count' + api('') + ' > 0',
                       '5m',
                       'warning',
                       {},
                       { summary: 'Client certificate is about to expire.', description: 'A client certificate used to authenticate to the API server of {{ $labels.cluster }} expires in less than 7 days.' }),
        alert.rule.new('KubeClientCertificateExpiration',
                       clientCertTtl + ' < 86400 and on (cluster, job, instance) apiserver_client_certificate_expiration_seconds_count' + api('') + ' > 0',
                       '5m',
                       'critical',
                       {},
                       { summary: 'Client certificate is about to expire.', description: 'A client certificate used to authenticate to the API server of {{ $labels.cluster }} expires in less than 24 hours.' }),
        // [5m], not the mixin's [1m]: a one-minute scrape leaves a single sample in 1m
        alert.rule.new('KubeAggregatedAPIErrors',
                       'sum by (cluster, instance, name, reason) (increase(aggregator_unavailable_apiservice_total' + api('') + '[5m])) > 0',
                       '10m',
                       'warning',
                       {},
                       { summary: 'Kubernetes aggregated API has reported errors.', description: 'Aggregated API {{ $labels.name }} on {{ $labels.cluster }} reported {{ $labels.reason }} errors.' }),
        alert.rule.new('KubeAggregatedAPIDown',
                       '(1 - max by (cluster, namespace, name) (avg_over_time(aggregator_unavailable_apiservice' + api('') + '[10m]))) * 100 < 85',
                       '5m',
                       'warning',
                       {},
                       { summary: 'Kubernetes aggregated API is down.', description: 'Aggregated API {{ $labels.name }} on {{ $labels.cluster }} has been only {{ $value | humanize }}% available over 10 minutes.' }),
        alert.rule.new('KubeAPITerminatedRequests',
                       'sum by (cluster) (rate(apiserver_request_terminations_total' + api('') + '[10m])) / (sum by (cluster) (rate(apiserver_request_total' + api('') + '[10m])) + sum by (cluster) (rate(apiserver_request_terminations_total' + api('') + '[10m]))) > 0.2',
                       '5m',
                       'warning',
                       {},
                       { summary: 'The Kubernetes API server has terminated too many incoming requests.', description: 'The API server of {{ $labels.cluster }} terminated {{ $value | humanizePercentage }} of its incoming requests.' }),
      ] + liveness('KubeAPI', 'API server', cfg.apiserverJob, false)),
      alert.rule.group('kubernetes-system-kubelet', [
        alert.rule.new('KubeletTooManyPods',
                       '(max by (cluster, instance) (kubelet_running_pods' + rsBrace + ' > 1) * on (cluster, instance) group_left (node) max by (cluster, instance, node) (kubelet_node_name' + rsBrace + ')) / on (cluster, node) group_left () max by (cluster, node) (kube_node_status_capacity{resource="pods"' + rsComma + '} != 1) > 0.95',
                       '15m',
                       'info',
                       {},
                       { summary: 'Kubelet is running at capacity.', description: 'The kubelet on {{ $labels.node }} ({{ $labels.cluster }}) runs {{ $value | humanizePercentage }} of its pod capacity.' }),
        alert.rule.new('KubeletPlegDurationHigh',
                       'histogram_quantile(0.99, sum by (cluster, instance, le) (rate(kubelet_pleg_relist_duration_seconds_bucket' + rsBrace + '[5m])) * on (cluster, instance) group_left (node) max by (cluster, instance, node) (kubelet_node_name' + rsBrace + ')) >= 10',
                       '5m',
                       'warning',
                       {},
                       { summary: 'Kubelet Pod Lifecycle Event Generator is taking too long to relist.', description: 'The PLEG relist on {{ $labels.node }} ({{ $labels.cluster }}) takes {{ $value }}s at the 99th percentile.' }),
        alert.rule.new('KubeletPodStartUpLatencyHigh',
                       'histogram_quantile(0.99, sum by (cluster, instance, le) (topk by (cluster, instance, le, operation_type) (1, rate(kubelet_pod_worker_duration_seconds_bucket' + rsBrace + '[5m])))) * on (cluster, instance) group_left (node) topk by (cluster, instance, node) (1, kubelet_node_name' + rsBrace + ') > 60',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Kubelet pod start-up latency is too high.', description: 'Pod start-up on {{ $labels.node }} ({{ $labels.cluster }}) takes {{ $value }}s at the 99th percentile.' }),
        alert.rule.new('KubeletClientCertificateExpiration',
                       'kubelet_certificate_manager_client_ttl_seconds' + rsBrace + ' < 604800',
                       '0s',
                       'warning',
                       {},
                       { summary: 'Kubelet client certificate is about to expire.', description: 'The client certificate of the kubelet on {{ $labels.node }} ({{ $labels.cluster }}) expires in {{ $value | humanizeDuration }}.' }),
        alert.rule.new('KubeletClientCertificateExpiration',
                       'kubelet_certificate_manager_client_ttl_seconds' + rsBrace + ' < 86400',
                       '0s',
                       'critical',
                       {},
                       { summary: 'Kubelet client certificate is about to expire.', description: 'The client certificate of the kubelet on {{ $labels.node }} ({{ $labels.cluster }}) expires in {{ $value | humanizeDuration }}.' }),
        alert.rule.new('KubeletClientCertificateRenewalErrors',
                       'increase(kubelet_certificate_manager_client_expiration_renew_errors' + rsBrace + '[5m]) > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Kubelet has failed to renew its client certificate.', description: 'The kubelet on {{ $labels.node }} ({{ $labels.cluster }}) failed to renew its client certificate {{ $value | humanize }} times in 5 minutes.' }),
      ] + liveness('Kubelet', 'Kubelet', cfg.kubeletJob, false)),
      alert.rule.group('kubernetes-system-controller-manager', liveness('KubeControllerManager', 'Controller manager', cfg.controllerManagerJob, true)),
      alert.rule.group('kubernetes-system-scheduler', liveness('KubeScheduler', 'Scheduler', cfg.schedulerJob, true)),
      alert.rule.group('kubernetes-system-kube-proxy', liveness('KubeProxy', 'kube-proxy', cfg.proxyJob, true)),
      // multi-window, multi-burn-rate alerts on the API server's 99% SLO
      alert.rule.group('kube-apiserver-slos', [
        alert.rule.new('KubeAPIErrorBudgetBurn',
                       'sum by (cluster) (apiserver_request:burnrate' + w.long + rsBrace + ') > (' + w.factor + ' * 0.01) and on (cluster) sum by (cluster) (apiserver_request:burnrate' + w.short + rsBrace + ') > (' + w.factor + ' * 0.01)',
                       w['for'],
                       w.severity,
                       { long: w.long, short: w.short },
                       { summary: 'The Kubernetes API server is burning too much error budget.', description: 'The API server of {{ $labels.cluster }} burns its error budget too fast over both ' + w.long + ' and ' + w.short + '.' })
        for w in [
          { long: '1h', short: '5m', factor: '14.4', 'for': '2m', severity: 'critical' },
          { long: '6h', short: '30m', factor: '6', 'for': '15m', severity: 'critical' },
          { long: '1d', short: '2h', factor: '3', 'for': '1h', severity: 'warning' },
          { long: '3d', short: '6h', factor: '1', 'for': '3h', severity: 'warning' },
        ]
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
        // a workload's pods on the pod board (its $pod takes the regex unescaped)
        ov('^Workload$', [{ id: 'links', value: [{ title: 'Pods of ${__value.raw}', url: '/d/' + cfg.podBoardUid + '?var-cluster=${cluster}&var-namespace=${__data.fields.Namespace}&var-pod=${__value.raw}(-.*)?' }] }]),
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

    // Tempo traces panel (TraceQL search) — same shape as the standalone
    // kspan board, scoped to this board's $cluster.
    local tracesPanel(title, traceql) =
      panel.traces.new(title)
      + panel.traces.withTargets([
        query.base('tempo', { query: traceql, queryType: 'traceql', limit: 50, tableType: 'traces' })
        + query.withDatasource(cfg.tracesDatasource),
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
          // utilisation, on a second row (elements lay out in key order)
          ovUtilCpu: pctStat('CPU utilisation', '100 * sum(rate(container_cpu_usage_seconds_total{container!="", container!="POD", ' + s + '}[$__rate_interval])) / sum(kube_node_status_allocatable{resource="cpu", ' + s + '})'),
          ovUtilLoad: pctStat('Load per core', '100 * sum(node_load5{' + s + '}) / count(node_cpu_seconds_total{mode="idle", ' + s + '})'),
          ovUtilMem: pctStat('Memory utilisation', '100 * sum(container_memory_working_set_bytes{container!="", container!="POD", ' + s + '}) / sum(kube_node_status_allocatable{resource="memory", ' + s + '})'),
          ovUtilRootFs: pctStat('Root filesystem usage', '100 * (1 - sum(node_filesystem_avail_bytes{mountpoint="/", fstype!="", ' + s + '}) / sum(node_filesystem_size_bytes{mountpoint="/", fstype!="", ' + s + '}))'),
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
    ], alerts, rules, [
      // kspan turns k8s object events into OTLP spans (component/kspan ->
      // the site's Alloy -> Tempo); the tab shows only where kspan is running,
      // gated on its deployment being reported by kube-state-metrics.
      {
        title: 'Cluster Events',
        width: 24,
        height: 11,
        presence: { query: 'kube_deployment_status_replicas_available{deployment="kspan", cluster=~"$cluster"}', label: 'cluster' },
        elements: {
          a_kspanObjects: tracesPanel(
            'Kubernetes object events (kspan)',
            '{ resource.cluster =~ "$cluster" && name =~ "(Deployment|Pod|ReplicaSet|StatefulSet|DaemonSet|Job|Service|Node)\\..*" }'
          ),
          b_kspanAll: tracesPanel('All recent traces (kspan + salt jobs)', '{ resource.cluster =~ "$cluster" }'),
        },
      },
      // what is firing in this cluster, and what it is saying
      tabs.alerts(cfg.datasource, 'cluster=~"$cluster"'),
      tabs.logs('${loki_datasource}', tabs.kubernetesStreams('.+', '.+', '$cluster')),
    ]),
}
