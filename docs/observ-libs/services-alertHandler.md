# Alert-handler  (`g.libs.services.alertHandler`)

Dashboard uid `observ-viz-svc-alert-handler` · 97 signals · 5 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `actions` | short | `sum by (rule, action) (rate(alert_handler_actions_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `actionsByResult` | short | `sum by (result) (rate(alert_handler_actions_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `actionsFailed` | short | `sum by (rule, action) (rate(alert_handler_actions_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", result!~"ok\|success"}[$__rate_interval]))` | — |
| `alerts` | short | `sum by (status) (rate(alert_handler_alerts_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `configAge` | dtdurations | `time() - max(alert_handler_config_loaded_timestamp_seconds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `configRules` | short | `max(alert_handler_config_rules{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `configValid` | short | `min(alert_handler_config_valid{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])` | — |
| `durationAvg` | s | `sum by (rule, action) (rate(alert_handler_action_duration_seconds_sum{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])) / sum by (rule, action) (rate(alert_handler_action_duration_seconds_count{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `durationP99` | s | `histogram_quantile(0.99, sum by (le, action) (rate(alert_handler_action_duration_seconds_bucket{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])))` | — |
| `failureRatio` | percentunit | `sum(rate(alert_handler_actions_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", result!~"ok\|success\|skipped"}[$__rate_interval])) / sum(rate(alert_handler_actions_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `hproc_cpu` | short | `sum by (instance, groupname) (rate(namedprocess_namegroup_cpu_seconds_total{groupname=~"alert-handler", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_ctxSwitches` | ops | `sum by (instance, groupname, ctxswitchtype) (rate(namedprocess_namegroup_context_switches_total{groupname=~"alert-handler", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_fdRatio` | percentunit | `max by (instance, groupname) (namedprocess_namegroup_worst_fd_ratio{groupname=~"alert-handler", instance=~"$host"})` | — |
| `hproc_fds` | short | `sum by (instance, groupname) (namedprocess_namegroup_open_filedesc{groupname=~"alert-handler", instance=~"$host"})` | — |
| `hproc_ioRead` | Bps | `sum by (instance, groupname) (rate(namedprocess_namegroup_read_bytes_total{groupname=~"alert-handler", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_ioWrite` | Bps | `sum by (instance, groupname) (rate(namedprocess_namegroup_write_bytes_total{groupname=~"alert-handler", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_majFaults` | short | `sum by (instance, groupname) (rate(namedprocess_namegroup_major_page_faults_total{groupname=~"alert-handler", instance=~"$host"}[$__rate_interval]))` | — |
| `hproc_procs` | short | `sum by (instance, groupname) (namedprocess_namegroup_num_procs{groupname=~"alert-handler", instance=~"$host"})` | — |
| `hproc_rss` | bytes | `sum by (instance, groupname) (namedprocess_namegroup_memory_bytes{groupname=~"alert-handler", memtype="resident", instance=~"$host"})` | — |
| `hproc_states` | short | `sum by (instance, groupname, state) (namedprocess_namegroup_states{groupname=~"alert-handler", instance=~"$host"})` | — |
| `hproc_threads` | short | `sum by (instance, groupname) (namedprocess_namegroup_num_threads{groupname=~"alert-handler", instance=~"$host"})` | — |
| `hproc_uptime` | dtdurations | `time() - min by (instance, groupname) (namedprocess_namegroup_oldest_start_time_seconds{groupname=~"alert-handler", instance=~"$host"})` | — |
| `inflight` | short | `sum(alert_handler_actions_inflight{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `ing_byHost` | reqps | `sum by (host) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval]))` | — |
| `ing_byIngress` | reqps | `sum by (namespace, ingress) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval]))` | — |
| `ing_byMethod` | reqps | `sum by (method) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval]))` | — |
| `ing_byPath` | reqps | `topk(10, sum by (host, path) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval])))` | — |
| `ing_byStatus` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval]))` | — |
| `ing_bytesIn` | Bps | `sum(rate(nginx_ingress_controller_request_size_sum{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval]))` | — |
| `ing_bytesOut` | Bps | `sum(rate(nginx_ingress_controller_response_size_sum{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval]))` | — |
| `ing_err4xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*", status=~"4.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval]))` | — |
| `ing_err5xx` | percentunit | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*", status=~"5.."}[$__rate_interval])) / sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval]))` | — |
| `ing_hosts` | short | `count(count by (host) (nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}))` | — |
| `ing_ingresses` | short | `count(count by (namespace, ingress) (nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}))` | — |
| `ing_p50` | s | `histogram_quantile(0.50, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval])))` | — |
| `ing_p95` | s | `histogram_quantile(0.95, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval])))` | — |
| `ing_p99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval])))` | — |
| `ing_rate` | reqps | `sum(rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval]))` | — |
| `ing_upstreamErrors` | reqps | `sum by (status) (rate(nginx_ingress_controller_requests{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*", status=~"502\|503\|504"}[$__rate_interval]))` | — |
| `ing_upstreamP99` | s | `histogram_quantile(0.99, sum by (le) (rate(nginx_ingress_controller_response_duration_seconds_bucket{cluster=~"$cluster", namespace=~"$namespace", service=~"alert-handler.*"}[$__rate_interval])))` | — |
| `kube_age` | s | `time() - kube_pod_start_time{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"}` | — |
| `kube_cpu` | short | `sum by (pod) (rate(container_cpu_usage_seconds_total{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", container!=""}[$__rate_interval]))` | — |
| `kube_cpuLimits` | short | `sum by (pod) (kube_pod_container_resource_limits{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="cpu"})` | — |
| `kube_cpuRequests` | short | `sum by (pod) (kube_pod_container_resource_requests{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod", resource="cpu"})` | — |
| `kube_deployAvailable` | short | `kube_deployment_status_replicas_available{cluster=~"$cluster", namespace=~"$namespace", deployment=~"alert-handler.*"}` | — |
| `kube_deployDesired` | short | `kube_deployment_spec_replicas{cluster=~"$cluster", namespace=~"$namespace", deployment=~"alert-handler.*"}` | — |
| `kube_dsDesired` | short | `kube_daemonset_status_desired_number_scheduled{cluster=~"$cluster", namespace=~"$namespace", daemonset=~"alert-handler.*"}` | — |
| `kube_dsReady` | short | `kube_daemonset_status_number_ready{cluster=~"$cluster", namespace=~"$namespace", daemonset=~"alert-handler.*"}` | — |
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
| `kube_stsDesired` | short | `kube_statefulset_replicas{cluster=~"$cluster", namespace=~"$namespace", statefulset=~"alert-handler.*"}` | — |
| `kube_stsReady` | short | `kube_statefulset_status_replicas_ready{cluster=~"$cluster", namespace=~"$namespace", statefulset=~"alert-handler.*"}` | — |
| `kube_waiting` | short | `sum by (pod, reason) (kube_pod_container_status_waiting_reason{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"} == 1)` | — |
| `kube_waitingTotal` | short | `sum(kube_pod_container_status_waiting{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `kube_youngest` | dtdurations | `min(time() - kube_pod_start_time{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"})` | — |
| `logs_journal` | short | `{instance=~"$host", unit=~"alert-handler.service"}` | — |
| `logs_pod` | short | `{cluster=~"$cluster", namespace=~"$namespace", pod=~"$pod"}` | — |
| `matches` | short | `sum by (rule) (rate(alert_handler_rule_matches_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `proc_cpu` | short | `rate(process_cpu_seconds_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval])` | — |
| `proc_fdRatio` | percentunit | `process_open_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"} / process_max_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_fds` | short | `process_open_fds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_rss` | bytes | `process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_uptime` | s | `time() - process_start_time_seconds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `proc_virt` | bytes | `process_virtual_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}` | — |
| `runbooks` | short | `max(alert_handler_runbooks_available{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `secrets` | short | `max(alert_handler_secrets_loaded{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"})` | — |
| `systemd_active` | short | `count(node_systemd_unit_state{name=~"alert-handler.service", state="active", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_failed` | short | `count(node_systemd_unit_state{name=~"alert-handler.service", state="failed", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_failedTable` | short | `node_systemd_unit_state{name=~"alert-handler.service", state="failed", instance=~"$host"} == 1` | — |
| `systemd_hosts` | short | `count(count by (instance) (node_systemd_unit_state{name=~"alert-handler.service", instance=~"$host"}))` | — |
| `systemd_inactive` | short | `count(node_systemd_unit_state{name=~"alert-handler.service", state="inactive", instance=~"$host"} == 1) or vector(0)` | — |
| `systemd_restarts` | short | `sum by (instance, name) (increase(node_systemd_service_restart_total{name=~"alert-handler.service", instance=~"$host"}[$__rate_interval]))` | — |
| `systemd_state` | short | `max by (instance, name) ((node_systemd_unit_state{name=~"alert-handler.service", state="active", instance=~"$host"} == 1) * 1 or (node_systemd_unit_state{name=~"alert-handler.service", state=~"activating\|deactivating", instance=~"$host"} == 1) * 2 or (node_systemd_unit_state{name=~"alert-handler.service", state="inactive", instance=~"$host"} == 1) * 3 or (node_systemd_unit_state{name=~"alert-handler.service", state="failed", instance=~"$host"} == 1) * 4)` | — |
| `systemd_tasks` | short | `node_systemd_unit_tasks_current{name=~"alert-handler.service", instance=~"$host"}` | — |
| `systemd_tasksMax` | short | `node_systemd_unit_tasks_max{name=~"alert-handler.service", instance=~"$host"}` | — |
| `systemd_tasksUtil` | percent | `100 * node_systemd_unit_tasks_current{name=~"alert-handler.service", instance=~"$host"} / clamp_min(node_systemd_unit_tasks_max{name=~"alert-handler.service", instance=~"$host"}, 1)` | — |
| `systemd_uptime` | s | `time() - node_systemd_unit_start_time_seconds{name=~"alert-handler.service", instance=~"$host"}` | — |
| `webhookErrors` | short | `sum(rate(alert_handler_webhook_requests_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|", result!~"ok\|success\|accepted"}[$__rate_interval]))` | — |
| `webhooks` | short | `sum by (result) (rate(alert_handler_webhook_requests_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace\|", pod=~"$pod\|"}[$__rate_interval]))` | — |
| `win_cpu` | short | `sum by (instance) (rate(windows_process_cpu_time_total{process=~"(?i)alert-handler", instance=~"$host"}[$__rate_interval]))` | — |
| `win_handles` | short | `sum by (instance) (windows_process_handles{process=~"(?i)alert-handler", instance=~"$host"})` | — |
| `win_io` | Bps | `sum by (instance, mode) (rate(windows_process_io_bytes_total{process=~"(?i)alert-handler", instance=~"$host"}[$__rate_interval]))` | — |
| `win_state` | short | `max by (instance, name) ((windows_service_state{name=~"(?i)alert-handler", state="running", instance=~"$host"} == 1) * 1 or (windows_service_state{name=~"(?i)alert-handler", state=~"start pending\|continue pending", instance=~"$host"} == 1) * 2 or (windows_service_state{name=~"(?i)alert-handler", state=~"paused\|pause pending\|stop pending", instance=~"$host"} == 1) * 3 or (windows_service_state{name=~"(?i)alert-handler", state="stopped", instance=~"$host"} == 1) * 4)` | — |
| `win_threads` | short | `sum by (instance) (windows_process_threads{process=~"(?i)alert-handler", instance=~"$host"})` | — |
| `win_uptime` | s | `time() - min by (instance) (windows_process_start_time{process=~"(?i)alert-handler", instance=~"$host"})` | — |
| `win_workingSet` | bytes | `sum by (instance) (windows_process_working_set_private_bytes{process=~"(?i)alert-handler", instance=~"$host"} or windows_process_working_set_bytes{process=~"(?i)alert-handler", instance=~"$host"})` | — |

## Dashboard

- **Overview** — `ov01_configValid`, `ov02_rules`, `ov03_configAge`, `ov04_runbooks`, `ov05_secrets`, `ov06_inflight`, `ov07_failureRatio`, `ov08_webhookErrors`
- **Intake** — `alerts`, `matches`, `webhooks`
- **Actions** — `actions`, `actionsByResult`, `actionsFailed`, `durationAvg`, `durationP99`, `inflight`
- **Resources** — `cpu`, `rss`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `AlertHandlerDown` | critical | 5m | — |
| `AlertHandlerConfigInvalid` | critical | 5m | — |
| `AlertHandlerActionsFailing` | warning | 15m | — |
| `AlertHandlerWebhookErrors` | warning | 15m | — |
| `AlertHandlerActionsStuck` | warning | 30m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `rule:alert_handler_actions:rate5m` | `sum by (rule, action, result) (rate(alert_handler_actions_total[5m]))` |
| `job:alert_handler_alerts:rate5m` | `sum by (job, status) (rate(alert_handler_alerts_total[5m]))` |
