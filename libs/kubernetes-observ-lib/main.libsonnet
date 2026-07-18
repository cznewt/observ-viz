// observ-viz Kubernetes pod pack (hand-written).
// Pod-level CPU, memory and health from kube-state-metrics + cadvisor, emitted as
// native v2 elements. Usage:
//   g.libs.kubernetes.pod.new({ selector: 'namespace="prod"' }).grafana.dashboard
//   g.libs.kubernetes.pod.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-kube-pod',
      dashboardTitle: 'Kubernetes pod',
      dashboardTags: ['kubernetes', 'pod'],
      datasource: '${datasource}',
      selector: 'namespace=~"$namespace"',
      varMetric: 'kube_pod_info',
      varLabels: ['namespace'],  // $namespace dropdown (label_values scoped by $job)
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      // deploy target: Software / Kubernetes (nested Grafana folders; loader creates both).
      folderUid: 'software-kubernetes',
      folderTitle: 'Kubernetes',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, legend='{{pod}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      // ===== Pods — cAdvisor resource usage =====
      cpuUsage: sig('CPU usage', 'sum by (pod)(rate(container_cpu_usage_seconds_total{%(queriesSelector)s,container!=""}[$__rate_interval]))', 'short'),
      cpuThrottled: sig('CPU throttled', 'sum by (pod)(rate(container_cpu_cfs_throttled_periods_total{%(queriesSelector)s,container!=""}[$__rate_interval])) / sum by (pod)(rate(container_cpu_cfs_periods_total{%(queriesSelector)s,container!=""}[$__rate_interval]))', 'percentunit'),
      memWorkingSet: sig('Memory working set', 'sum by (pod)(container_memory_working_set_bytes{%(queriesSelector)s,container!=""})', 'bytes'),
      memRss: sig('Memory RSS', 'sum by (pod)(container_memory_rss{%(queriesSelector)s,container!=""})', 'bytes'),
      memCache: sig('Memory cache', 'sum by (pod)(container_memory_cache{%(queriesSelector)s,container!=""})', 'bytes'),
      fsReads: sig('Pod disk read', 'sum by (pod)(rate(container_fs_reads_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      fsWrites: sig('Pod disk write', 'sum by (pod)(rate(container_fs_writes_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),

      // ===== Pods — kube-state-metrics requests/limits/status =====
      cpuRequests: sig('CPU requests', 'sum by (pod)(kube_pod_container_resource_requests{%(queriesSelector)s,resource="cpu"})', 'short'),
      cpuLimits: sig('CPU limits', 'sum by (pod)(kube_pod_container_resource_limits{%(queriesSelector)s,resource="cpu"})', 'short'),
      memRequests: sig('Memory requests', 'sum by (pod)(kube_pod_container_resource_requests{%(queriesSelector)s,resource="memory"})', 'bytes'),
      memLimits: sig('Memory limits', 'sum by (pod)(kube_pod_container_resource_limits{%(queriesSelector)s,resource="memory"})', 'bytes'),
      restarts: sig('Container restarts', 'sum by (pod)(kube_pod_container_status_restarts_total{%(queriesSelector)s})', 'short'),
      phase: sig('Pods by phase', 'sum by (phase)(kube_pod_status_phase{%(queriesSelector)s})', 'short', '{{phase}}'),
      containersWaiting: sig('Containers waiting', 'sum by (pod)(kube_pod_container_status_waiting{%(queriesSelector)s})', 'short'),
      containersReady: sig('Containers ready', 'sum by (pod)(kube_pod_container_status_ready{%(queriesSelector)s})', 'short'),

      // ===== Workloads — deployments / statefulsets / daemonsets =====
      deployDesired: sig('Deployment desired', 'kube_deployment_spec_replicas{%(queriesSelector)s}', 'short', '{{deployment}}'),
      deployAvailable: sig('Deployment available', 'kube_deployment_status_replicas_available{%(queriesSelector)s}', 'short', '{{deployment}}'),
      deployUnavailable: sig('Deployment unavailable', 'kube_deployment_status_replicas_unavailable{%(queriesSelector)s}', 'short', '{{deployment}}'),
      stsReplicas: sig('StatefulSet replicas', 'kube_statefulset_status_replicas{%(queriesSelector)s}', 'short', '{{statefulset}}'),
      stsReady: sig('StatefulSet ready', 'kube_statefulset_status_replicas_ready{%(queriesSelector)s}', 'short', '{{statefulset}}'),
      dsDesired: sig('DaemonSet desired', 'kube_daemonset_status_desired_number_scheduled{%(queriesSelector)s}', 'short', '{{daemonset}}'),
      dsReady: sig('DaemonSet ready', 'kube_daemonset_status_number_ready{%(queriesSelector)s}', 'short', '{{daemonset}}'),
      dsUnavailable: sig('DaemonSet unavailable', 'kube_daemonset_status_number_unavailable{%(queriesSelector)s}', 'short', '{{daemonset}}'),

      // ===== Jobs / cronjobs =====
      jobActive: sig('Jobs active', 'sum(kube_job_status_active{%(queriesSelector)s})', 'short', 'active'),
      jobFailed: sig('Jobs failed', 'sum(kube_job_status_failed{%(queriesSelector)s})', 'short', 'failed'),
      jobSucceeded: sig('Jobs succeeded', 'sum(kube_job_status_succeeded{%(queriesSelector)s})', 'short', 'succeeded'),
      cronjobActive: sig('CronJobs active', 'sum by (cronjob)(kube_cronjob_status_active{%(queriesSelector)s})', 'short', '{{cronjob}}'),

      // ===== Storage — PersistentVolumeClaims =====
      pvcPhase: sig('PVC phase', 'kube_persistentvolumeclaim_status_phase{%(queriesSelector)s} == 1', 'short', '{{persistentvolumeclaim}} / {{phase}}'),
      pvcCapacity: sig('PVC requested storage', 'kube_persistentvolumeclaim_resource_requests_storage_bytes{%(queriesSelector)s}', 'bytes', '{{persistentvolumeclaim}}'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Pod resources',  // cAdvisor + KSM requests/limits
        width: 12,
        height: 7,
        elements: {
          cpuUsage: signals.cpuUsage.asTimeSeries('CPU usage (cores)'),
          cpuRequests: signals.cpuRequests.asTimeSeries('CPU requests (cores)'),
          cpuLimits: signals.cpuLimits.asTimeSeries('CPU limits (cores)'),
          cpuThrottled: signals.cpuThrottled.asTimeSeries('CPU throttled ratio'),
          memWorkingSet: signals.memWorkingSet.asTimeSeries('Memory working set'),
          memRss: signals.memRss.asTimeSeries('Memory RSS'),
          memCache: signals.memCache.asTimeSeries('Memory cache'),
          memRequests: signals.memRequests.asTimeSeries('Memory requests'),
          memLimits: signals.memLimits.asTimeSeries('Memory limits'),
        },
      },
      {
        title: 'Pod disk IO',  // cAdvisor fs (container_network_* is unlabeled on this cluster)
        width: 12,
        height: 7,
        elements: {
          fsReads: signals.fsReads.asTimeSeries('Disk read'),
          fsWrites: signals.fsWrites.asTimeSeries('Disk write'),
        },
      },
      {
        title: 'Pod health',  // KSM pod/container status
        width: 12,
        height: 7,
        elements: {
          phase: signals.phase.asTimeSeries('Pods by phase'),
          restarts: signals.restarts.asTimeSeries('Container restarts'),
          containersReady: signals.containersReady.asTimeSeries('Containers ready'),
          containersWaiting: signals.containersWaiting.asTimeSeries('Containers waiting'),
        },
      },
      {
        title: 'Workloads',  // KSM deployments / statefulsets / daemonsets
        width: 12,
        height: 7,
        elements: {
          deployDesired: signals.deployDesired.asTimeSeries('Deployment desired'),
          deployAvailable: signals.deployAvailable.asTimeSeries('Deployment available'),
          deployUnavailable: signals.deployUnavailable.asTimeSeries('Deployment unavailable'),
          stsReplicas: signals.stsReplicas.asTimeSeries('StatefulSet replicas'),
          stsReady: signals.stsReady.asTimeSeries('StatefulSet ready'),
          dsDesired: signals.dsDesired.asTimeSeries('DaemonSet desired'),
          dsReady: signals.dsReady.asTimeSeries('DaemonSet ready'),
          dsUnavailable: signals.dsUnavailable.asTimeSeries('DaemonSet unavailable'),
        },
      },
      {
        title: 'Jobs & storage',  // KSM jobs / cronjobs / PVCs
        width: 12,
        height: 7,
        elements: {
          jobActive: signals.jobActive.asStat('Jobs active'),
          jobFailed: signals.jobFailed.asStat('Jobs failed'),
          jobSucceeded: signals.jobSucceeded.asStat('Jobs succeeded'),
          cronjobActive: signals.cronjobActive.asTimeSeries('CronJobs active'),
          pvcPhase: signals.pvcPhase.asTable('PVC phase'),
          pvcCapacity: signals.pvcCapacity.asTimeSeries('PVC requested storage'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('kubernetes-pod', [
        alert.rule.new(
          'KubePodNotReady',
          'sum by (namespace, pod) (kube_pod_status_phase{phase=~"Pending|Unknown|Failed"' + rsComma + '}) > 0',
          '15m', 'critical', {},
          { summary: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in a non-ready state for more than 15 minutes.' }
        ),
        alert.rule.new(
          'KubePodCrashLooping',
          'rate(kube_pod_container_status_restarts_total' + rsBrace + '[10m]) * 60 * 5 > 0',
          '15m', 'warning', {},
          { summary: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} on {{ $labels.instance }} is restarting frequently.' }
        ),
        alert.rule.new(
          'KubePodCpuOverRequest',
          'sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!=""' + rsComma + '}[5m])) > sum by (namespace, pod) (kube_pod_container_resource_requests{resource="cpu"' + rsComma + '})',
          '15m', 'warning', {},
          { summary: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} on {{ $labels.instance }} is using more CPU than requested.' }
        ),
        alert.rule.new(
          'KubePodMemoryNearLimit',
          'sum by (namespace, pod) (container_memory_working_set_bytes{container!=""' + rsComma + '}) / sum by (namespace, pod) (kube_pod_container_resource_limits{resource="memory"' + rsComma + '}) > 0.9',
          '15m', 'warning', {},
          { summary: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} on {{ $labels.instance }} memory working set is above 90% of its limit.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('kubernetes-pod.rules', [
        alert.rule.record('namespace_pod:container_cpu_usage:rate5m', 'sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!=""' + rsComma + '}[5m]))'),
        alert.rule.record('namespace_pod:container_memory_working_set_bytes:sum', 'sum by (namespace, pod) (container_memory_working_set_bytes{container!=""' + rsComma + '})'),
      ]),
    ]),
}
