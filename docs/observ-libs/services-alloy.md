# Alloy service  (`g.libs.services.alloy`)

Dashboard uid `observ-viz-svc-alloy` · 63 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `appended` | short | `sum(rate(prometheus_remote_write_wal_samples_appended_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `controllerQueue` | short | `sum(alloy_component_controller_evaluating{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `cpu` | short | `rate(alloy_resources_process_cpu_seconds_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])` | `instance:alloy_cpu_usage:rate5m` |
| `evalP99` | s | `histogram_quantile(0.99, sum by (le)(rate(alloy_component_evaluation_seconds_bucket{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])))` | — |
| `evalRate` | ops | `sum(rate(alloy_component_evaluation_seconds_count{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `hproc_cpu` | short | `sum by (instance) (rate(namedprocess_namegroup_cpu_seconds_total{groupname=~"alloy", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_fdRatio` | percentunit | `max by (instance) (namedprocess_namegroup_worst_fd_ratio{groupname=~"alloy", instance=~"$host"})` | — |
| `hproc_fds` | short | `sum by (instance) (namedprocess_namegroup_open_filedesc{groupname=~"alloy", instance=~"$host"})` | — |
| `hproc_ioRead` | Bps | `sum by (instance) (rate(namedprocess_namegroup_read_bytes_total{groupname=~"alloy", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_ioWrite` | Bps | `sum by (instance) (rate(namedprocess_namegroup_write_bytes_total{groupname=~"alloy", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_majFaults` | short | `sum by (instance) (rate(namedprocess_namegroup_major_page_faults_total{groupname=~"alloy", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_procs` | short | `sum by (instance) (namedprocess_namegroup_num_procs{groupname=~"alloy", instance=~"$host"})` | — |
| `hproc_rss` | bytes | `sum by (instance) (namedprocess_namegroup_memory_bytes{groupname=~"alloy", memtype="resident", instance=~"$host"})` | — |
| `hproc_threads` | short | `sum by (instance) (namedprocess_namegroup_num_threads{groupname=~"alloy", instance=~"$host"})` | — |
| `hproc_uptime` | s | `time() - min by (instance) (namedprocess_namegroup_oldest_start_time_seconds{groupname=~"alloy", instance=~"$host"})` | — |
| `kube_age` | s | `time() - kube_pod_start_time{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"}` | — |
| `kube_cpu` | short | `sum by (pod) (rate(container_cpu_usage_seconds_total{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", container!=""}[$__rate_interval]))` | — |
| `kube_cpuLimits` | short | `sum by (pod) (kube_pod_container_resource_limits{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="cpu"})` | — |
| `kube_cpuRequests` | short | `sum by (pod) (kube_pod_container_resource_requests{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="cpu"})` | — |
| `kube_deployAvailable` | short | `kube_deployment_status_replicas_available{cluster=~"$cluster", namespace=~"$namespace", deployment=~"alloy.*"}` | — |
| `kube_deployDesired` | short | `kube_deployment_spec_replicas{cluster=~"$cluster", namespace=~"$namespace", deployment=~"alloy.*"}` | — |
| `kube_dsDesired` | short | `kube_daemonset_status_desired_number_scheduled{cluster=~"$cluster", namespace=~"$namespace", daemonset=~"alloy.*"}` | — |
| `kube_dsReady` | short | `kube_daemonset_status_number_ready{cluster=~"$cluster", namespace=~"$namespace", daemonset=~"alloy.*"}` | — |
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
| `kube_stsDesired` | short | `kube_statefulset_replicas{cluster=~"$cluster", namespace=~"$namespace", statefulset=~"alloy.*"}` | — |
| `kube_stsReady` | short | `kube_statefulset_status_replicas_ready{cluster=~"$cluster", namespace=~"$namespace", statefulset=~"alloy.*"}` | — |
| `kube_waiting` | short | `sum by (pod, reason) (kube_pod_container_status_waiting_reason{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"} == 1)` | — |
| `kube_waitingTotal` | short | `sum(kube_pod_container_status_waiting{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `kube_youngest` | dtdurations | `min(time() - kube_pod_start_time{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `logs_journal` | short | `{instance=~"$host", unit=~"alloy.service"}` | — |
| `logs_pod` | short | `{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"}` | — |
| `pending` | short | `sum(prometheus_remote_storage_samples_pending{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `proc_cpu` | short | `rate(process_cpu_seconds_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])` | — |
| `proc_fdRatio` | percentunit | `process_open_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"} / process_max_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_fds` | short | `process_open_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_rss` | bytes | `process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_uptime` | s | `time() - process_start_time_seconds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_virt` | bytes | `process_virtual_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `rss` | bytes | `alloy_resources_process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `running` | short | `sum(alloy_component_controller_running_components{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `sendFailed` | short | `sum(rate(prometheus_remote_storage_samples_failed_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `systemd_active` | short | `count(node_systemd_unit_state{name=~"alloy.service", state="active", instance=~"$host"} == 1)` | — |
| `systemd_failed` | short | `count(node_systemd_unit_state{name=~"alloy.service", state="failed", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_hosts` | short | `count(count by (instance) (node_systemd_unit_state{name=~"alloy.service", instance=~"$host"}))` | — |
| `systemd_state` | short | `max by (instance, name) ((node_systemd_unit_state{name=~"alloy.service", state="active", instance=~"$host"} == 1) * 1 or (node_systemd_unit_state{name=~"alloy.service", state=~"activating\|deactivating", instance=~"$host"} == 1) * 2 or (node_systemd_unit_state{name=~"alloy.service", state="inactive", instance=~"$host"} == 1) * 3 or (node_systemd_unit_state{name=~"alloy.service", state="failed", instance=~"$host"} == 1) * 4)` | — |
| `uptime` | s | `time() - alloy_resources_process_start_time_seconds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `win_cpu` | short | `sum by (instance) (rate(windows_process_cpu_time_total{process=~"(?i)alloy", instance=~"$host"}[$__rate_interval]))` | — |
| `win_handles` | short | `sum by (instance) (windows_process_handles{process=~"(?i)alloy", instance=~"$host"})` | — |
| `win_io` | Bps | `sum by (instance, mode) (rate(windows_process_io_bytes_total{process=~"(?i)alloy", instance=~"$host"}[$__rate_interval]))` | — |
| `win_state` | short | `max by (instance, name) ((windows_service_state{name=~"(?i)alloy", state="running", instance=~"$host"} == 1) * 1 or (windows_service_state{name=~"(?i)alloy", state=~"start pending\|continue pending", instance=~"$host"} == 1) * 2 or (windows_service_state{name=~"(?i)alloy", state=~"paused\|pause pending\|stop pending", instance=~"$host"} == 1) * 3 or (windows_service_state{name=~"(?i)alloy", state="stopped", instance=~"$host"} == 1) * 4)` | — |
| `win_threads` | short | `sum by (instance) (windows_process_threads{process=~"(?i)alloy", instance=~"$host"})` | — |
| `win_uptime` | s | `time() - min by (instance) (windows_process_start_time{process=~"(?i)alloy", instance=~"$host"})` | — |
| `win_workingSet` | bytes | `sum by (instance) (windows_process_working_set_private_bytes{process=~"(?i)alloy", instance=~"$host"} or windows_process_working_set_bytes{process=~"(?i)alloy", instance=~"$host"})` | — |

## Dashboard

- **Components** — `controllerQueue`, `evalP99`, `evalRate`, `running`
- **Remote write** — `appended`, `pending`, `sendFailed`
- **Resources** — `cpu`, `rss`, `uptime`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `AlloyNoRunningComponents` | critical | 5m | — |
| `AlloyRemoteWriteFailing` | warning | 15m | — |
| `AlloyRemoteWriteBacklog` | warning | 15m | — |
| `AlloyControllerQueueHigh` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:alloy_cpu_usage:rate5m` | `rate(alloy_resources_process_cpu_seconds_total[5m])` |
| `instance:alloy_samples_appended:rate5m` | `rate(prometheus_remote_write_wal_samples_appended_total[5m])` |
