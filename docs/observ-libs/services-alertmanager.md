# Alertmanager service  (`g.libs.services.alertmanager`)

Dashboard uid `observ-viz-svc-alertmanager` · 113 signals · 29 alerts · 15 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `aggregationGroups` | short | `sum(alertmanager_dispatcher_aggregation_groups{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `alertsActive` | short | `sum(alertmanager_alerts{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", state="active"})` | — |
| `alertsByState` | short | `sum by (state) (alertmanager_alerts{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `alertsSuppressed` | short | `sum(alertmanager_alerts{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", state="suppressed"})` | — |
| `clusterFailedPeers` | short | `alertmanager_cluster_failed_peers{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `clusterHealth` | short | `alertmanager_cluster_health_score{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `clusterMembers` | short | `alertmanager_cluster_members{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `clusterQueued` | short | `alertmanager_cluster_messages_queued{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `clusterReconnectFailed` | short | `sum by (pod) (rate(alertmanager_cluster_reconnections_failed_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])` | — |
| `failureRatio` | percentunit | `sum by (integration) (rate(alertmanager_notifications_failed_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])) / sum by (integration) (rate(alertmanager_notifications_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | `integration:alertmanager_notifications_failed:ratio_rate5m` |
| `failureRatioTotal` | percentunit | `sum(rate(alertmanager_notifications_failed_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])) / sum(rate(alertmanager_notifications_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `hproc_cpu` | short | `sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total{groupname=~"alertmanager", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_ctxSwitches` | ops | `sum by (instance, groupname, ctxswitchtype) (rate(namedprocess_namegroup_context_switches_total{groupname=~"alertmanager", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_fdRatio` | percentunit | `max by (instance, groupname) (namedprocess_namegroup_worst_fd_ratio{groupname=~"alertmanager", instance=~"$host"})` | — |
| `hproc_fds` | short | `sum by (instance, groupname) (namedprocess_namegroup_open_filedesc{groupname=~"alertmanager", instance=~"$host"})` | — |
| `hproc_ioRead` | Bps | `sum by (instance, groupname) (rate(namedprocess_namegroup_read_bytes_total{groupname=~"alertmanager", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_ioWrite` | Bps | `sum by (instance, groupname) (rate(namedprocess_namegroup_write_bytes_total{groupname=~"alertmanager", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_majFaults` | short | `sum by (instance, groupname) (rate(namedprocess_namegroup_major_page_faults_total{groupname=~"alertmanager", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_procs` | short | `sum by (instance, groupname) (namedprocess_namegroup_num_procs{groupname=~"alertmanager", instance=~"$host"})` | — |
| `hproc_rss` | bytes | `sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{groupname=~"alertmanager", memtype="resident", instance=~"$host"})` | — |
| `hproc_states` | short | `sum by (instance, groupname, state) (namedprocess_namegroup_states{groupname=~"alertmanager", instance=~"$host"})` | — |
| `hproc_threads` | short | `sum by (instance, groupname) (namedprocess_namegroup_num_threads{groupname=~"alertmanager", instance=~"$host"})` | — |
| `hproc_uptime` | dtdurations | `time() - min by (instance, groupname) (namedprocess_namegroup_oldest_start_time_seconds{groupname=~"alertmanager", instance=~"$host"})` | — |
| `httpInFlight` | short | `sum(alertmanager_http_requests_in_flight{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `httpP99` | s | `histogram_quantile(0.99, sum by (le) (rate(alertmanager_http_request_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])))` | — |
| `httpRate` | reqps | `sum by (handler) (rate(alertmanager_http_request_duration_seconds_count{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `ing_byHost` | reqps | `sum by (host) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval]))` | — |
| `ing_byIngress` | reqps | `sum by (namespace, ingress) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval]))` | — |
| `ing_byMethod` | reqps | `sum by (method) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval]))` | — |
| `ing_byPath` | reqps | `topk(10, sum by (host, path) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval])))` | — |
| `ing_byStatus` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval]))` | — |
| `ing_bytesIn` | Bps | `sum(rate(nginx_ingress_controller_request_size_sum{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval]))` | — |
| `ing_bytesOut` | Bps | `sum(rate(nginx_ingress_controller_response_size_sum{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval]))` | — |
| `ing_err4xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*", status=~"4.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval]))` | — |
| `ing_err5xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*", status=~"5.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval]))` | — |
| `ing_hosts` | short | `count(count by (host) (nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}))` | — |
| `ing_ingresses` | short | `count(count by (namespace, ingress) (nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}))` | — |
| `ing_p50` | s | `histogram_quantile(0.50, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval])))` | — |
| `ing_p95` | s | `histogram_quantile(0.95, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval])))` | — |
| `ing_p99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval])))` | — |
| `ing_rate` | reqps | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval]))` | — |
| `ing_upstreamErrors` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*", status=~"502\|503\|504"}[$__rate_interval]))` | — |
| `ing_upstreamP99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_response_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"alertmanager.*"}[$__rate_interval])))` | — |
| `inhibitionRules` | short | `max(alertmanager_inhibition_rules{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `integrations` | short | `max(alertmanager_integrations{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `invalid` | short | `sum(rate(alertmanager_alerts_invalid_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `kube_age` | s | `time() - kube_pod_start_time{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"}` | — |
| `kube_cpu` | short | `sum by (pod) (rate(container_cpu_usage_seconds_total{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", container!=""}[$__rate_interval]))` | — |
| `kube_cpuLimits` | short | `sum by (pod) (kube_pod_container_resource_limits{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="cpu"})` | — |
| `kube_cpuRequests` | short | `sum by (pod) (kube_pod_container_resource_requests{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="cpu"})` | — |
| `kube_deployAvailable` | short | `kube_deployment_status_replicas_available{cluster=~"$cluster", namespace=~"$namespace", deployment=~"alertmanager-server.*"}` | — |
| `kube_deployDesired` | short | `kube_deployment_spec_replicas{cluster=~"$cluster", namespace=~"$namespace", deployment=~"alertmanager-server.*"}` | — |
| `kube_dsDesired` | short | `kube_daemonset_status_desired_number_scheduled{cluster=~"$cluster", namespace=~"$namespace", daemonset=~"alertmanager-server.*"}` | — |
| `kube_dsReady` | short | `kube_daemonset_status_number_ready{cluster=~"$cluster", namespace=~"$namespace", daemonset=~"alertmanager-server.*"}` | — |
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
| `kube_stsDesired` | short | `kube_statefulset_replicas{cluster=~"$cluster", namespace=~"$namespace", statefulset=~"alertmanager-server.*"}` | — |
| `kube_stsReady` | short | `kube_statefulset_status_replicas_ready{cluster=~"$cluster", namespace=~"$namespace", statefulset=~"alertmanager-server.*"}` | — |
| `kube_waiting` | short | `sum by (pod, reason) (kube_pod_container_status_waiting_reason{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"} == 1)` | — |
| `kube_waitingTotal` | short | `sum(kube_pod_container_status_waiting{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `kube_youngest` | dtdurations | `min(time() - kube_pod_start_time{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `logs_journal` | short | `{instance=~"$host", unit=~"alertmanager.service"}` | — |
| `logs_pod` | short | `{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"}` | — |
| `nflogErrors` | short | `sum(rate(alertmanager_nflog_query_errors_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `notificationP99` | s | `histogram_quantile(0.99, sum by (le, integration) (rate(alertmanager_notification_latency_seconds_bucket{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])))` | — |
| `notifications` | short | `sum by (integration) (rate(alertmanager_notifications_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `notificationsFailed` | short | `sum by (integration, reason) (rate(alertmanager_notifications_failed_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `proc_cpu` | short | `rate(process_cpu_seconds_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])` | — |
| `proc_fdRatio` | percentunit | `process_open_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"} / process_max_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_fds` | short | `process_open_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_rss` | bytes | `process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_uptime` | s | `time() - process_start_time_seconds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_virt` | bytes | `process_virtual_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `processingAvg` | s | `sum(rate(alertmanager_dispatcher_alert_processing_duration_seconds_sum{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])) / sum(rate(alertmanager_dispatcher_alert_processing_duration_seconds_count{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `received` | short | `sum by (status) (rate(alertmanager_alerts_received_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `receivers` | short | `max(alertmanager_receivers{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `reloadAge` | dtdurations | `time() - max(alertmanager_config_last_reload_success_timestamp_seconds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `reloadOk` | short | `min(alertmanager_config_last_reload_successful{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `requestsFailed` | short | `sum by (integration) (rate(alertmanager_notification_requests_failed_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `silenceErrors` | short | `sum(rate(alertmanager_silences_query_errors_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `silences` | short | `sum by (state) (alertmanager_silences{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `silencesActive` | short | `sum(alertmanager_silences{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", state="active"})` | — |
| `suppressed` | short | `sum by (reason) (rate(alertmanager_notifications_suppressed_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `systemd_active` | short | `count(node_systemd_unit_state{name=~"alertmanager.service", state="active", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_failed` | short | `count(node_systemd_unit_state{name=~"alertmanager.service", state="failed", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_failedTable` | short | `node_systemd_unit_state{name=~"alertmanager.service", state="failed", instance=~"$host"} == 1` | — |
| `systemd_hosts` | short | `count(count by (instance) (node_systemd_unit_state{name=~"alertmanager.service", instance=~"$host"}))` | — |
| `systemd_inactive` | short | `count(node_systemd_unit_state{name=~"alertmanager.service", state="inactive", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_restarts` | short | `sum by (instance, name) (increase(node_systemd_service_restart_total{name=~"alertmanager.service", instance=~"$host"}[$__rate_interval]))` | — |
| `systemd_state` | short | `max by (instance, name) ((node_systemd_unit_state{name=~"alertmanager.service", state="active", instance=~"$host"} == 1) * 1 or (node_systemd_unit_state{name=~"alertmanager.service", state=~"activating\|deactivating", instance=~"$host"} == 1) * 2 or (node_systemd_unit_state{name=~"alertmanager.service", state="inactive", instance=~"$host"} == 1) * 3 or (node_systemd_unit_state{name=~"alertmanager.service", state="failed", instance=~"$host"} == 1) * 4)` | — |
| `systemd_tasks` | short | `node_systemd_unit_tasks_current{name=~"alertmanager.service", instance=~"$host"}` | — |
| `systemd_tasksMax` | short | `node_systemd_unit_tasks_max{name=~"alertmanager.service", instance=~"$host"}` | — |
| `systemd_tasksUtil` | percent | `100 * node_systemd_unit_tasks_current{name=~"alertmanager.service", instance=~"$host"} / clamp_min(node_systemd_unit_tasks_max{name=~"alertmanager.service", instance=~"$host"}, 1)` | — |
| `systemd_uptime` | s | `time() - node_systemd_unit_start_time_seconds{name=~"alertmanager.service", instance=~"$host"}` | — |
| `uptime` | dtdurations | `min(time() - process_start_time_seconds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `win_cpu` | short | `sum by (instance) (rate(windows_process_cpu_time_total{process=~"(?i)alertmanager", instance=~"$host"}[$__rate_interval]))` | — |
| `win_handles` | short | `sum by (instance) (windows_process_handles{process=~"(?i)alertmanager", instance=~"$host"})` | — |
| `win_io` | Bps | `sum by (instance, mode) (rate(windows_process_io_bytes_total{process=~"(?i)alertmanager", instance=~"$host"}[$__rate_interval]))` | — |
| `win_state` | short | `max by (instance, name) ((windows_service_state{name=~"(?i)alertmanager", state="running", instance=~"$host"} == 1) * 1 or (windows_service_state{name=~"(?i)alertmanager", state=~"start pending\|continue pending", instance=~"$host"} == 1) * 2 or (windows_service_state{name=~"(?i)alertmanager", state=~"paused\|pause pending\|stop pending", instance=~"$host"} == 1) * 3 or (windows_service_state{name=~"(?i)alertmanager", state="stopped", instance=~"$host"} == 1) * 4)` | — |
| `win_threads` | short | `sum by (instance) (windows_process_threads{process=~"(?i)alertmanager", instance=~"$host"})` | — |
| `win_uptime` | s | `time() - min by (instance) (windows_process_start_time{process=~"(?i)alertmanager", instance=~"$host"})` | — |
| `win_workingSet` | bytes | `sum by (instance) (windows_process_working_set_private_bytes{process=~"(?i)alertmanager", instance=~"$host"} or windows_process_working_set_bytes{process=~"(?i)alertmanager", instance=~"$host"})` | — |

## Dashboard

- **Overview** — `ov01_active`, `ov02_suppressed`, `ov03_silences`, `ov04_failureRatio`, `ov05_reloadOk`, `ov06_reloadAge`, `ov07_receivers`, `ov08_integrations`, `ov09_inhibitions`, `ov10_groups`, `ov11_failedPeers`, `ov12_uptime`
- **Alerts** — `aggregationGroups`, `alertsByState`, `invalid`, `processingAvg`, `received`, `silences`
- **Notifications** — `failureRatio`, `notificationP99`, `notifications`, `notificationsFailed`, `requestsFailed`, `suppressed`
- **Cluster** — `clusterFailedPeers`, `clusterHealth`, `clusterMembers`, `clusterQueued`, `clusterReconnectFailed`
- **API & resources** — `cpu`, `httpInFlight`, `httpP99`, `httpRate`, `rss`, `storeErrors`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `AlertmanagerDown` | critical | 5m | — |
| `AlertmanagerFailedReload` | critical | 10m | — |
| `AlertmanagerClusterFailedPeers` | warning | 15m | — |
| `AlertmanagerFailedToSendAlerts` | warning | 5m | — |
| `AlertmanagerClusterFailedToSendAlerts` | critical | 5m | — |
| `AlertmanagerClusterCrashlooping` | critical | 0m | — |
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
| `integration:alertmanager_notifications_failed:ratio_rate5m` | `sum by (integration) (rate(alertmanager_notifications_failed_total[5m])) / sum by (integration) (rate(alertmanager_notifications_total[5m]))` |
| `job:alertmanager_alerts_received:rate5m` | `sum by (job, status) (rate(alertmanager_alerts_received_total[5m]))` |
| `namespace_pod:container_cpu_usage:rate5m` | `sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!="", pod=~"alertmanager-server.*"}[5m]))` |
| `namespace_pod:container_memory_working_set_bytes:sum` | `sum by (namespace, pod) (container_memory_working_set_bytes{container!="", pod=~"alertmanager-server.*"})` |
| `pod:container_cpu_usage:rate5m` | `sum by (pod, container) (rate(container_cpu_usage_seconds_total{container!="", pod=~"alertmanager-server.*"}[5m]))` |
| `pod:container_memory_working_set:sum` | `sum by (pod, container) (container_memory_working_set_bytes{container!="", pod=~"alertmanager-server.*"})` |
| `instance_name:container_cpu_usage:rate5m` | `sum by (name) (rate(container_cpu_usage_seconds_total{name!="", name=~".*alertmanager.*"}[5m]))` |
| `instance_name:container_memory_working_set_bytes:sum` | `sum by (name) (container_memory_working_set_bytes{name!="", name=~".*alertmanager.*"})` |
| `instance:node_systemd_units_failed:count` | `count by (instance) (node_systemd_unit_state{state="failed", name=~"alertmanager.service"} == 1)` |
| `instance:node_systemd_units_active:count` | `count by (instance) (node_systemd_unit_state{state="active", name=~"alertmanager.service"} == 1)` |
| `instance_groupname:namedprocess_cpu:rate5m` | `sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total{groupname=~"alertmanager"}[5m]))` |
| `instance_groupname:namedprocess_rss:sum` | `sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{memtype="resident", groupname=~"alertmanager"})` |
| `ingress:nginx_ingress_controller_requests:rate5m` | `sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{service=~"alertmanager.*"}[5m]))` |
| `ingress:nginx_ingress_controller_5xx:ratio_rate5m` | `sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{status=~"5..", service=~"alertmanager.*"}[5m])) / sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{service=~"alertmanager.*"}[5m]))` |
| `ingress:nginx_ingress_controller_request_duration_seconds:p99_5m` | `histogram_quantile(0.99, sum by (le, cluster, namespace, ingress) (rate(nginx_ingress_controller_request_duration_seconds_bucket{service=~"alertmanager.*"}[5m])))` |
