# kube-state-metrics

- **source**: k8s-monitoring KSM
- **patterns**: `kube_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| kubernetes.pod | containersReady | `kube_pod_container_status_ready` |
| kubernetes.pod | containersWaiting | `kube_pod_container_status_waiting` |
| kubernetes.pod | cpuLimits | `kube_pod_container_resource_limits` |
| kubernetes.pod | cpuRequests | `kube_pod_container_resource_requests` |
| kubernetes.pod | cronjobActive | `kube_cronjob_status_active` |
| kubernetes.pod | deployAvailable | `kube_deployment_status_replicas_available` |
| kubernetes.pod | deployDesired | `kube_deployment_spec_replicas` |
| kubernetes.pod | deployUnavailable | `kube_deployment_status_replicas_unavailable` |
| kubernetes.pod | dsDesired | `kube_daemonset_status_desired_number_scheduled` |
| kubernetes.pod | dsReady | `kube_daemonset_status_number_ready` |
| kubernetes.pod | dsUnavailable | `kube_daemonset_status_number_unavailable` |
| kubernetes.pod | jobActive | `kube_job_status_active` |
| kubernetes.pod | jobFailed | `kube_job_status_failed` |
| kubernetes.pod | jobSucceeded | `kube_job_status_succeeded` |
| kubernetes.pod | memLimits | `kube_pod_container_resource_limits` |
| kubernetes.pod | memRequests | `kube_pod_container_resource_requests` |
| kubernetes.pod | phase | `kube_pod_status_phase` |
| kubernetes.pod | pvcCapacity | `kube_persistentvolumeclaim_resource_requests_storage_bytes` |
| kubernetes.pod | pvcPhase | `kube_persistentvolumeclaim_status_phase` |
| kubernetes.pod | restarts | `kube_pod_container_status_restarts_total` |
| kubernetes.pod | stsReady | `kube_statefulset_status_replicas_ready` |
| kubernetes.pod | stsReplicas | `kube_statefulset_status_replicas` |

## Live metrics (193)

- `kube_apiserver_clusterip_allocator_allocated_ips`
- `kube_apiserver_clusterip_allocator_allocation_duration_seconds_bucket`
- `kube_apiserver_clusterip_allocator_allocation_duration_seconds_count`
- `kube_apiserver_clusterip_allocator_allocation_duration_seconds_sum`
- `kube_apiserver_clusterip_allocator_allocation_total`
- `kube_apiserver_clusterip_allocator_available_ips`
- `kube_apiserver_nodeport_allocator_allocated_ports`
- `kube_apiserver_nodeport_allocator_allocation_total`
- `kube_apiserver_nodeport_allocator_available_ports`
- `kube_apiserver_pod_logs_backend_tls_failure_total`
- `kube_apiserver_pod_logs_insecure_backend_total`
- `kube_configmap_created`
- `kube_configmap_info`
- `kube_configmap_metadata_resource_version`
- `kube_cronjob_created`
- `kube_cronjob_info`
- `kube_cronjob_metadata_resource_version`
- `kube_cronjob_next_schedule_time`
- `kube_cronjob_spec_failed_job_history_limit`
- `kube_cronjob_spec_successful_job_history_limit`
- `kube_cronjob_spec_suspend`
- `kube_cronjob_status_active`
- `kube_cronjob_status_last_schedule_time`
- `kube_cronjob_status_last_successful_time`
- `kube_daemonset_created`
- `kube_daemonset_metadata_generation`
- `kube_daemonset_status_current_number_scheduled`
- `kube_daemonset_status_desired_number_scheduled`
- `kube_daemonset_status_number_available`
- `kube_daemonset_status_number_misscheduled`
- `kube_daemonset_status_number_ready`
- `kube_daemonset_status_number_unavailable`
- `kube_daemonset_status_observed_generation`
- `kube_daemonset_status_updated_number_scheduled`
- `kube_deployment_created`
- `kube_deployment_deletion_timestamp`
- `kube_deployment_metadata_generation`
- `kube_deployment_spec_paused`
- `kube_deployment_spec_replicas`
- `kube_deployment_spec_strategy_rollingupdate_max_surge`
- `kube_deployment_spec_strategy_rollingupdate_max_unavailable`
- `kube_deployment_status_condition`
- `kube_deployment_status_observed_generation`
- `kube_deployment_status_replicas`
- `kube_deployment_status_replicas_available`
- `kube_deployment_status_replicas_ready`
- `kube_deployment_status_replicas_unavailable`
- `kube_deployment_status_replicas_updated`
- `kube_endpoint_address`
- `kube_endpoint_created`
- `kube_endpoint_info`
- `kube_endpoint_ports`
- `kube_ingress_created`
- `kube_ingress_info`
- `kube_ingress_metadata_resource_version`
- `kube_ingress_path`
- `kube_ingress_tls`
- `kube_job_complete`
- `kube_job_created`
- `kube_job_failed`
- `kube_job_info`
- `kube_job_owner`
- `kube_job_spec_active_deadline_seconds`
- `kube_job_spec_completions`
- `kube_job_spec_parallelism`
- `kube_job_status_active`
- `kube_job_status_completion_time`
- `kube_job_status_failed`
- `kube_job_status_start_time`
- `kube_job_status_succeeded`
- `kube_lease_owner`
- `kube_lease_renew_time`
- `kube_mutatingwebhookconfiguration_created`
- `kube_mutatingwebhookconfiguration_info`
- `kube_mutatingwebhookconfiguration_metadata_resource_version`
- `kube_mutatingwebhookconfiguration_webhook_clientconfig_service`
- `kube_namespace_created`
- `kube_namespace_status_phase`
- `kube_networkpolicy_created`
- `kube_networkpolicy_spec_egress_rules`
- `kube_networkpolicy_spec_ingress_rules`
- `kube_node_created`
- `kube_node_info`
- `kube_node_labels`
- `kube_node_role`
- `kube_node_spec_taint`
- `kube_node_spec_unschedulable`
- `kube_node_status_addresses`
- `kube_node_status_allocatable`
- `kube_node_status_capacity`
- `kube_node_status_condition`
- `kube_persistentvolume_capacity_bytes`
- `kube_persistentvolume_claim_ref`
- `kube_persistentvolume_created`
- `kube_persistentvolume_deletion_timestamp`
- `kube_persistentvolume_info`
- `kube_persistentvolume_status_phase`
- `kube_persistentvolume_volume_mode`
- `kube_persistentvolumeclaim_access_mode`
- `kube_persistentvolumeclaim_created`
- `kube_persistentvolumeclaim_deletion_timestamp`
- `kube_persistentvolumeclaim_info`
- `kube_persistentvolumeclaim_resource_requests_storage_bytes`
- `kube_persistentvolumeclaim_status_phase`
- `kube_pod_completion_time`
- `kube_pod_container_info`
- `kube_pod_container_resource_limits`
- `kube_pod_container_resource_requests`
- `kube_pod_container_state_started`
- `kube_pod_container_status_last_terminated_exitcode`
- `kube_pod_container_status_last_terminated_reason`
- `kube_pod_container_status_last_terminated_timestamp`
- `kube_pod_container_status_ready`
- `kube_pod_container_status_restarts_total`
- `kube_pod_container_status_running`
- `kube_pod_container_status_terminated`
- `kube_pod_container_status_terminated_reason`
- `kube_pod_container_status_waiting`
- `kube_pod_container_status_waiting_reason`
- `kube_pod_created`
- `kube_pod_deletion_timestamp`
- `kube_pod_info`
- `kube_pod_init_container_info`
- `kube_pod_init_container_resource_limits`
- `kube_pod_init_container_resource_requests`
- `kube_pod_init_container_status_last_terminated_reason`
- `kube_pod_init_container_status_ready`
- `kube_pod_init_container_status_restarts_total`
- `kube_pod_init_container_status_running`
- `kube_pod_init_container_status_terminated`
- `kube_pod_init_container_status_terminated_reason`
- `kube_pod_init_container_status_waiting`
- `kube_pod_init_container_status_waiting_reason`
- `kube_pod_ips`
- `kube_pod_owner`
- `kube_pod_restart_policy`
- `kube_pod_scheduler`
- `kube_pod_service_account`
- `kube_pod_spec_volumes_persistentvolumeclaims_info`
- `kube_pod_spec_volumes_persistentvolumeclaims_readonly`
- `kube_pod_start_time`
- `kube_pod_status_container_ready_time`
- `kube_pod_status_initialized_time`
- `kube_pod_status_phase`
- `kube_pod_status_qos_class`
- `kube_pod_status_ready`
- `kube_pod_status_ready_time`
- `kube_pod_status_reason`
- `kube_pod_status_scheduled`
- `kube_pod_status_scheduled_time`
- `kube_pod_status_unschedulable`
- `kube_pod_status_unscheduled_time`
- `kube_pod_tolerations`
- `kube_poddisruptionbudget_created`
- `kube_poddisruptionbudget_status_current_healthy`
- `kube_poddisruptionbudget_status_desired_healthy`
- `kube_poddisruptionbudget_status_expected_pods`
- `kube_poddisruptionbudget_status_observed_generation`
- `kube_poddisruptionbudget_status_pod_disruptions_allowed`
- `kube_replicaset_created`
- `kube_replicaset_metadata_generation`
- `kube_replicaset_owner`
- `kube_replicaset_spec_replicas`
- `kube_replicaset_status_fully_labeled_replicas`
- `kube_replicaset_status_observed_generation`
- `kube_replicaset_status_ready_replicas`
- `kube_replicaset_status_replicas`
- `kube_secret_created`
- `kube_secret_info`
- `kube_secret_metadata_resource_version`
- `kube_secret_owner`
- `kube_secret_type`
- `kube_service_created`
- `kube_service_info`
- `kube_service_spec_type`
- `kube_statefulset_created`
- `kube_statefulset_metadata_generation`
- `kube_statefulset_persistentvolumeclaim_retention_policy`
- `kube_statefulset_replicas`
- `kube_statefulset_status_current_revision`
- `kube_statefulset_status_observed_generation`
- `kube_statefulset_status_replicas`
- `kube_statefulset_status_replicas_available`
- `kube_statefulset_status_replicas_current`
- `kube_statefulset_status_replicas_ready`
- `kube_statefulset_status_replicas_updated`
- `kube_statefulset_status_update_revision`
- `kube_storageclass_created`
- `kube_storageclass_info`
- `kube_validatingwebhookconfiguration_created`
- `kube_validatingwebhookconfiguration_info`
- `kube_validatingwebhookconfiguration_metadata_resource_version`
- `kube_validatingwebhookconfiguration_webhook_clientconfig_service`
