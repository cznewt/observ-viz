# Argo CD service  (`g.libs.services.argocd`)

Dashboard uid `observ-viz-svc-argo-cd` · 101 signals · 29 alerts · 15 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `appTable` | short | `max by (name, project, sync_status, health_status) (argocd_app_info{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `apps` | short | `count(argocd_app_info{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `appsByHealth` | short | `sum by (health_status) (argocd_app_info{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `appsBySync` | short | `sum by (sync_status) (argocd_app_info{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `appsOutOfSync` | short | `sum(argocd_app_info{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", sync_status="OutOfSync"}) or vector(0)` | — |
| `appsUnhealthy` | short | `sum(argocd_app_info{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", health_status!~"Healthy\|Progressing"}) or vector(0)` | — |
| `clusterEvents` | short | `sum by (server) (rate(argocd_cluster_events_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `clusterObjects` | short | `sum by (server) (argocd_cluster_api_resource_objects{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `clusters` | short | `count(argocd_cluster_info{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `clustersDown` | short | `count(argocd_cluster_connection_status{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"} == 0) or vector(0)` | — |
| `cpu` | short | `sum by (pod) (rate(process_cpu_seconds_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `gitP99` | s | `histogram_quantile(0.99, sum by (le, request_type) (rate(argocd_git_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])))` | — |
| `gitRequests` | reqps | `sum by (request_type) (rate(argocd_git_request_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `hproc_cpu` | short | `sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total{groupname=~"argo-cd", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_ctxSwitches` | ops | `sum by (instance, groupname, ctxswitchtype) (rate(namedprocess_namegroup_context_switches_total{groupname=~"argo-cd", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_fdRatio` | percentunit | `max by (instance, groupname) (namedprocess_namegroup_worst_fd_ratio{groupname=~"argo-cd", instance=~"$host"})` | — |
| `hproc_fds` | short | `sum by (instance, groupname) (namedprocess_namegroup_open_filedesc{groupname=~"argo-cd", instance=~"$host"})` | — |
| `hproc_ioRead` | Bps | `sum by (instance, groupname) (rate(namedprocess_namegroup_read_bytes_total{groupname=~"argo-cd", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_ioWrite` | Bps | `sum by (instance, groupname) (rate(namedprocess_namegroup_write_bytes_total{groupname=~"argo-cd", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_majFaults` | short | `sum by (instance, groupname) (rate(namedprocess_namegroup_major_page_faults_total{groupname=~"argo-cd", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_procs` | short | `sum by (instance, groupname) (namedprocess_namegroup_num_procs{groupname=~"argo-cd", instance=~"$host"})` | — |
| `hproc_rss` | bytes | `sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{groupname=~"argo-cd", memtype="resident", instance=~"$host"})` | — |
| `hproc_states` | short | `sum by (instance, groupname, state) (namedprocess_namegroup_states{groupname=~"argo-cd", instance=~"$host"})` | — |
| `hproc_threads` | short | `sum by (instance, groupname) (namedprocess_namegroup_num_threads{groupname=~"argo-cd", instance=~"$host"})` | — |
| `hproc_uptime` | dtdurations | `time() - min by (instance, groupname) (namedprocess_namegroup_oldest_start_time_seconds{groupname=~"argo-cd", instance=~"$host"})` | — |
| `ing_byHost` | reqps | `sum by (host) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval]))` | — |
| `ing_byIngress` | reqps | `sum by (namespace, ingress) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval]))` | — |
| `ing_byMethod` | reqps | `sum by (method) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval]))` | — |
| `ing_byPath` | reqps | `topk(10, sum by (host, path) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval])))` | — |
| `ing_byStatus` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval]))` | — |
| `ing_bytesIn` | Bps | `sum(rate(nginx_ingress_controller_request_size_sum{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval]))` | — |
| `ing_bytesOut` | Bps | `sum(rate(nginx_ingress_controller_response_size_sum{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval]))` | — |
| `ing_err4xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*", status=~"4.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval]))` | — |
| `ing_err5xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*", status=~"5.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval]))` | — |
| `ing_hosts` | short | `count(count by (host) (nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}))` | — |
| `ing_ingresses` | short | `count(count by (namespace, ingress) (nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}))` | — |
| `ing_p50` | s | `histogram_quantile(0.50, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval])))` | — |
| `ing_p95` | s | `histogram_quantile(0.95, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval])))` | — |
| `ing_p99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval])))` | — |
| `ing_rate` | reqps | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval]))` | — |
| `ing_upstreamErrors` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*", status=~"502\|503\|504"}[$__rate_interval]))` | — |
| `ing_upstreamP99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_response_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"argo-cd.*"}[$__rate_interval])))` | — |
| `k8sRequests` | reqps | `sum by (verb, response_code) (rate(argocd_app_k8s_request_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `kube_age` | s | `time() - kube_pod_start_time{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"}` | — |
| `kube_cpu` | short | `sum by (pod) (rate(container_cpu_usage_seconds_total{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", container!=""}[$__rate_interval]))` | — |
| `kube_cpuLimits` | short | `sum by (pod) (kube_pod_container_resource_limits{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="cpu"})` | — |
| `kube_cpuRequests` | short | `sum by (pod) (kube_pod_container_resource_requests{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="cpu"})` | — |
| `kube_deployAvailable` | short | `kube_deployment_status_replicas_available{cluster=~"$cluster", namespace=~"$namespace", deployment=~"argo-cd-argocd.*"}` | — |
| `kube_deployDesired` | short | `kube_deployment_spec_replicas{cluster=~"$cluster", namespace=~"$namespace", deployment=~"argo-cd-argocd.*"}` | — |
| `kube_dsDesired` | short | `kube_daemonset_status_desired_number_scheduled{cluster=~"$cluster", namespace=~"$namespace", daemonset=~"argo-cd-argocd.*"}` | — |
| `kube_dsReady` | short | `kube_daemonset_status_number_ready{cluster=~"$cluster", namespace=~"$namespace", daemonset=~"argo-cd-argocd.*"}` | — |
| `kube_mem` | bytes | `sum by (pod) (container_memory_working_set_bytes{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", container!=""})` | — |
| `kube_memLimits` | bytes | `sum by (pod) (kube_pod_container_resource_limits{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="memory"})` | — |
| `kube_memRequests` | bytes | `sum by (pod) (kube_pod_container_resource_requests{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="memory"})` | — |
| `kube_notRunning` | short | `sum(kube_pod_status_phase{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", phase!="Running"} == 1) or vector(0)` | — |
| `kube_phase` | short | `sum by (phase) (kube_pod_status_phase{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"} == 1)` | — |
| `kube_pods` | short | `count(kube_pod_info{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `kube_pvcUsage` | percentunit | `kubelet_volume_stats_used_bytes{cluster=~"$cluster", namespace=~"$namespace"} / kubelet_volume_stats_capacity_bytes{cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `kube_ready` | short | `sum by (pod) (kube_pod_container_status_ready{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `kube_readyTotal` | short | `sum(kube_pod_container_status_ready{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `kube_restarts` | short | `sum by (pod) (kube_pod_container_status_restarts_total{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `kube_restarts1h` | short | `sum(increase(kube_pod_container_status_restarts_total{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"}[1h]))` | — |
| `kube_stsDesired` | short | `kube_statefulset_replicas{cluster=~"$cluster", namespace=~"$namespace", statefulset=~"argo-cd-argocd.*"}` | — |
| `kube_stsReady` | short | `kube_statefulset_status_replicas_ready{cluster=~"$cluster", namespace=~"$namespace", statefulset=~"argo-cd-argocd.*"}` | — |
| `kube_waiting` | short | `sum by (pod, reason) (kube_pod_container_status_waiting_reason{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"} == 1)` | — |
| `kube_waitingTotal` | short | `sum(kube_pod_container_status_waiting{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `kube_youngest` | dtdurations | `min(time() - kube_pod_start_time{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `kubectlPending` | short | `sum by (command) (argocd_kubectl_exec_pending{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `logs_journal` | short | `{instance=~"$host", unit=~"argo-cd.service"}` | — |
| `logs_pod` | short | `{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"}` | — |
| `proc_cpu` | short | `rate(process_cpu_seconds_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])` | — |
| `proc_fdRatio` | percentunit | `process_open_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"} / process_max_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_fds` | short | `process_open_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_rss` | bytes | `process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_uptime` | s | `time() - process_start_time_seconds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_virt` | bytes | `process_virtual_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `reconcileP50` | s | `histogram_quantile(0.50, sum by (le) (rate(argocd_app_reconcile_bucket{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])))` | — |
| `reconcileP99` | s | `histogram_quantile(0.99, sum by (le) (rate(argocd_app_reconcile_bucket{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])))` | — |
| `reconcileRate` | short | `sum(rate(argocd_app_reconcile_count{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `redisFailed` | short | `sum(rate(argocd_redis_request_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", failed="true"}[$__rate_interval]))` | — |
| `repoPending` | short | `sum(argocd_repo_pending_request_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `rss` | bytes | `sum by (pod) (process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `syncFailures1h` | short | `sum(increase(argocd_app_sync_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", phase=~"Error\|Failed"}[1h])) or vector(0)` | — |
| `syncFailuresByApp` | short | `sum by (name) (increase(argocd_app_sync_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", phase=~"Error\|Failed"}[$__rate_interval]))` | — |
| `syncs` | short | `sum by (phase) (rate(argocd_app_sync_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `systemd_active` | short | `count(node_systemd_unit_state{name=~"argo-cd.service", state="active", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_failed` | short | `count(node_systemd_unit_state{name=~"argo-cd.service", state="failed", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_failedTable` | short | `node_systemd_unit_state{name=~"argo-cd.service", state="failed", instance=~"$host"} == 1` | — |
| `systemd_hosts` | short | `count(count by (instance) (node_systemd_unit_state{name=~"argo-cd.service", instance=~"$host"}))` | — |
| `systemd_inactive` | short | `count(node_systemd_unit_state{name=~"argo-cd.service", state="inactive", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_restarts` | short | `sum by (instance, name) (increase(node_systemd_service_restart_total{name=~"argo-cd.service", instance=~"$host"}[$__rate_interval]))` | — |
| `systemd_state` | short | `max by (instance, name) ((node_systemd_unit_state{name=~"argo-cd.service", state="active", instance=~"$host"} == 1) * 1 or (node_systemd_unit_state{name=~"argo-cd.service", state=~"activating\|deactivating", instance=~"$host"} == 1) * 2 or (node_systemd_unit_state{name=~"argo-cd.service", state="inactive", instance=~"$host"} == 1) * 3 or (node_systemd_unit_state{name=~"argo-cd.service", state="failed", instance=~"$host"} == 1) * 4)` | — |
| `win_cpu` | short | `sum by (instance) (rate(windows_process_cpu_time_total{process=~"(?i)argo-cd", instance=~"$host"}[$__rate_interval]))` | — |
| `win_handles` | short | `sum by (instance) (windows_process_handles{process=~"(?i)argo-cd", instance=~"$host"})` | — |
| `win_io` | Bps | `sum by (instance, mode) (rate(windows_process_io_bytes_total{process=~"(?i)argo-cd", instance=~"$host"}[$__rate_interval]))` | — |
| `win_state` | short | `max by (instance, name) ((windows_service_state{name=~"(?i)argo-cd", state="running", instance=~"$host"} == 1) * 1 or (windows_service_state{name=~"(?i)argo-cd", state=~"start pending\|continue pending", instance=~"$host"} == 1) * 2 or (windows_service_state{name=~"(?i)argo-cd", state=~"paused\|pause pending\|stop pending", instance=~"$host"} == 1) * 3 or (windows_service_state{name=~"(?i)argo-cd", state="stopped", instance=~"$host"} == 1) * 4)` | — |
| `win_threads` | short | `sum by (instance) (windows_process_threads{process=~"(?i)argo-cd", instance=~"$host"})` | — |
| `win_uptime` | s | `time() - min by (instance) (windows_process_start_time{process=~"(?i)argo-cd", instance=~"$host"})` | — |
| `win_workingSet` | bytes | `sum by (instance) (windows_process_working_set_private_bytes{process=~"(?i)argo-cd", instance=~"$host"} or windows_process_working_set_bytes{process=~"(?i)argo-cd", instance=~"$host"})` | — |
| `workqueueDepth` | short | `sum by (name) (workqueue_depth{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `workqueueLatencyP99` | s | `histogram_quantile(0.99, sum by (le, name) (rate(workqueue_queue_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])))` | — |

## Dashboard

- **Overview** — `ov01_apps`, `ov02_outOfSync`, `ov03_unhealthy`, `ov04_syncFailures`, `ov05_clusters`, `ov06_clustersDown`, `ov07_repoPending`, `ov08_reconcileP99`
- **Applications** — `appTable`, `appsByHealth`, `appsBySync`, `reconcile`, `reconcileRate`, `syncFailuresByApp`, `syncs`
- **Clusters & repositories** — `clusterEvents`, `clusterObjects`, `gitP99`, `gitRequests`, `k8sRequests`, `repoPending`
- **Controller** — `cpu`, `kubectlPending`, `redisFailed`, `rss`, `workqueueDepth`, `workqueueLatencyP99`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `ArgoCdDown` | critical | 5m | — |
| `ArgoCdAppSyncFailed` | warning | 1m | — |
| `ArgoCdAppUnhealthy` | warning | 15m | — |
| `ArgoCdAppOutOfSync` | info | 30m | — |
| `ArgoCdClusterUnreachable` | critical | 10m | — |
| `ArgoCdRepoServerBacklog` | warning | 15m | — |
| `KubePodNotReady` | critical | 15m | — |
| `KubePodCrashLooping` | warning | 15m | — |
| `KubePodCpuOverRequest` | warning | 15m | — |
| `KubePodMemoryNearLimit` | warning | 15m | — |
| `ContainerCpuThrottlingHigh` | warning | 15m | — |
| `ContainerHighMemory` | warning | 15m | — |
| `ContainerHighCpu` | warning | 15m | — |
| `ContainerNetworkUnavailable` | critical | 5m | — |
| `CadvisorDown` | critical | 5m | — |
| `ContainerHighDiskWrite` | warning | 15m | — |
| `SystemdUnitFailed` | critical | 5m | — |
| `SystemdUnitRestarting` | warning | 0m | — |
| `SystemdSystemDegraded` | warning | 15m | — |
| `ProcessGroupFdRatioHigh` | warning | 15m | — |
| `ProcessGroupGone` | warning | 10m | — |
| `ProcessExporterScrapeErrors` | warning | 15m | — |
| `IngressNginxHigh5xxRatio` | warning | 10m | — |
| `IngressNginxHighLatency` | warning | 15m | — |
| `IngressNginxUpstreamErrors` | warning | 10m | — |
| `IngressNginxConfigReloadFailed` | critical | 5m | — |
| `IngressNginxCertificateExpiringSoon` | warning | 1h | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `project:argocd_app_sync_failed:increase10m` | `sum by (project, name) (increase(argocd_app_sync_total{phase=~"Error\|Failed"}[10m]))` |
| `job:argocd_app_reconcile_seconds:p99_5m` | `histogram_quantile(0.99, sum by (le, job) (rate(argocd_app_reconcile_bucket[5m])))` |
| `namespace_pod:container_cpu_usage:rate5m` | `sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!="", pod=~"argo-cd-argocd.*"}[5m]))` |
| `namespace_pod:container_memory_working_set_bytes:sum` | `sum by (namespace, pod) (container_memory_working_set_bytes{container!="", pod=~"argo-cd-argocd.*"})` |
| `pod:container_cpu_usage:rate5m` | `sum by (pod, container) (rate(container_cpu_usage_seconds_total{container!="", pod=~"argo-cd-argocd.*"}[5m]))` |
| `pod:container_memory_working_set:sum` | `sum by (pod, container) (container_memory_working_set_bytes{container!="", pod=~"argo-cd-argocd.*"})` |
| `instance_name:container_cpu_usage:rate5m` | `sum by (name) (rate(container_cpu_usage_seconds_total{name!="", name=~".*argo-cd.*"}[5m]))` |
| `instance_name:container_memory_working_set_bytes:sum` | `sum by (name) (container_memory_working_set_bytes{name!="", name=~".*argo-cd.*"})` |
| `instance:node_systemd_units_failed:count` | `count by (instance) (node_systemd_unit_state{state="failed", name=~"argo-cd.service"} == 1)` |
| `instance:node_systemd_units_active:count` | `count by (instance) (node_systemd_unit_state{state="active", name=~"argo-cd.service"} == 1)` |
| `instance_groupname:namedprocess_cpu:rate5m` | `sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total{groupname=~"argo-cd"}[5m]))` |
| `instance_groupname:namedprocess_rss:sum` | `sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{memtype="resident", groupname=~"argo-cd"})` |
| `ingress:nginx_ingress_controller_requests:rate5m` | `sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{service=~"argo-cd.*"}[5m]))` |
| `ingress:nginx_ingress_controller_5xx:ratio_rate5m` | `sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{status=~"5..", service=~"argo-cd.*"}[5m])) / sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{service=~"argo-cd.*"}[5m]))` |
| `ingress:nginx_ingress_controller_request_duration_seconds:p99_5m` | `histogram_quantile(0.99, sum by (le, cluster, namespace, ingress) (rate(nginx_ingress_controller_request_duration_seconds_bucket{service=~"argo-cd.*"}[5m])))` |
