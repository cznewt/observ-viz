# Kubernetes cluster  (`g.libs.kubernetes.cluster`)

Dashboard uid `kube-cluster` · 7 signals · 55 alerts · 24 recording rules · [every tab rendered](../dashboards/kube-cluster.md).

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `apiserverErrors` | percentunit | `sum (rate(apiserver_request_total{code=~"5..", cluster=~"$cluster"}[$__rate_interval])) / sum (rate(apiserver_request_total{cluster=~"$cluster"}[$__rate_interval]))` | — |
| `apiserverInflight` | short | `sum by (request_kind) (apiserver_current_inflight_requests{cluster=~"$cluster"})` | — |
| `apiserverRate` | reqps | `sum by (code) (rate(apiserver_request_total{cluster=~"$cluster"}[$__rate_interval]))` | — |
| `kubeletErrors` | ops | `sum by (instance) (rate(kubelet_runtime_operations_errors_total{cluster=~"$cluster"}[$__rate_interval]))` | — |
| `kubeletPods` | short | `sum by (instance) (kubelet_running_pods{cluster=~"$cluster"})` | — |
| `workqueueAdds` | ops | `sum (rate(workqueue_adds_total{cluster=~"$cluster"}[$__rate_interval]))` | — |
| `workqueueDepth` | short | `sum (workqueue_depth{cluster=~"$cluster"})` | — |

## Dashboard

- **Overview** — `ovCpuAlloc`, `ovCpuCommit`, `ovMemCommit`, `ovNamespaces`, `ovNodes`, `ovPods`, `ovUtilCpu`, `ovUtilLoad`, `ovUtilMem`, `ovUtilRootFs`
- **Namespaces** — `namespaces`
- **Nodes** — `nodes`
- **Workloads** — `workloads`
- **Control plane** — `apiserverErrors`, `apiserverInflight`, `apiserverRate`, `kubeletErrors`, `kubeletPods`, `workqueueAdds`, `workqueueDepth`
- **Storage** — `pvcs`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `KubePodCrashLooping` | warning | 15m | — |
| `KubePodNotReady` | warning | 15m | — |
| `KubeDeploymentReplicasMismatch` | warning | 15m | — |
| `KubeStatefulSetReplicasMismatch` | warning | 15m | — |
| `KubeContainerWaiting` | warning | 1h | — |
| `KubeCPUOvercommit` | warning | 10m | — |
| `KubeMemoryOvercommit` | warning | 10m | — |
| `KubeDeploymentGenerationMismatch` | warning | 15m | — |
| `KubeDeploymentRolloutStuck` | warning | 15m | — |
| `KubeStatefulSetGenerationMismatch` | warning | 15m | — |
| `KubeStatefulSetUpdateNotRolledOut` | warning | 15m | — |
| `KubeDaemonSetRolloutStuck` | warning | 15m | — |
| `KubeDaemonSetNotScheduled` | warning | 10m | — |
| `KubeDaemonSetMisScheduled` | warning | 15m | — |
| `KubeJobNotCompleted` | warning | 0s | — |
| `KubeJobFailed` | warning | 15m | — |
| `KubePdbNotEnoughHealthyPods` | warning | 15m | — |
| `KubePersistentVolumeFillingUp` | warning | 1h | — |
| `KubePersistentVolumeInodesFillingUp` | critical | 1m | — |
| `KubePersistentVolumeErrors` | critical | 5m | — |
| `KubeNodePressure` | warning | 5m | — |
| `KubeClusterPressure` | critical | 5m | — |
| `KubeNodesMissing` | critical | 5m | — |
| `KubeNodeNotReady` | warning | 15m | — |
| `KubeNodeUnreachable` | warning | 15m | — |
| `KubeNodeReadinessFlapping` | warning | 15m | — |
| `KubeNodeEviction` | info | 0s | — |
| `KubeVersionMismatch` | warning | 15m | — |
| `KubeClientErrors` | warning | 15m | — |
| `KubeClientCertificateExpiration` | warning | 5m | — |
| `KubeAggregatedAPIErrors` | warning | 10m | — |
| `KubeAggregatedAPIDown` | warning | 5m | — |
| `KubeAPITerminatedRequests` | warning | 5m | — |
| `KubeAPIDown` | critical | 15m | — |
| `KubeAPIInstanceUnreachable` | warning | 15m | — |
| `KubeletTooManyPods` | info | 15m | — |
| `KubeletPlegDurationHigh` | warning | 5m | — |
| `KubeletPodStartUpLatencyHigh` | warning | 15m | — |
| `KubeletClientCertificateExpiration` | warning | 0s | — |
| `KubeletClientCertificateRenewalErrors` | warning | 15m | — |
| `KubeletDown` | critical | 15m | — |
| `KubeletInstanceUnreachable` | warning | 15m | — |
| `KubeControllerManagerDown` | critical | 15m | — |
| `KubeControllerManagerInstanceUnreachable` | warning | 15m | — |
| `KubeSchedulerDown` | critical | 15m | — |
| `KubeSchedulerInstanceUnreachable` | warning | 15m | — |
| `KubeProxyDown` | critical | 15m | — |
| `KubeProxyInstanceUnreachable` | warning | 15m | — |
| `KubeAPIErrorBudgetBurn` | critical | 2m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate` | `sum by (cluster, namespace, pod, container) (irate(container_cpu_usage_seconds_total{container!="", pod!=""}[5m]))` |
| `namespace_cpu:kube_pod_container_resource_requests:sum` | `sum by (cluster, namespace) (kube_pod_container_resource_requests{resource="cpu"})` |
| `namespace_cpu:kube_pod_container_resource_limits:sum` | `sum by (cluster, namespace) (kube_pod_container_resource_limits{resource="cpu"})` |
| `namespace_memory:kube_pod_container_resource_requests:sum` | `sum by (cluster, namespace) (kube_pod_container_resource_requests{resource="memory"})` |
| `namespace_memory:kube_pod_container_resource_limits:sum` | `sum by (cluster, namespace) (kube_pod_container_resource_limits{resource="memory"})` |
| `namespace_workload_pod:kube_pod_owner:relabel` | `sum by (cluster, namespace, workload, pod) (label_replace(label_replace(kube_pod_owner{owner_kind="ReplicaSet"}, "replicaset", "$1", "owner_name", "(.*)") * on (replicaset, namespace, cluster) group_left (owner_name) topk by (replicaset, namespace, cluster) (1, max by (replicaset, namespace, owner_name, cluster) (kube_replicaset_owner)), "workload", "$1", "owner_name", "(.*)"))` |
| `namespace_workload_pod:kube_pod_owner:relabel` | `sum by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{owner_kind="StatefulSet"}, "workload", "$1", "owner_name", "(.*)"))` |
| `namespace_workload_pod:kube_pod_owner:relabel` | `sum by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{owner_kind="DaemonSet"}, "workload", "$1", "owner_name", "(.*)"))` |
| `namespace_workload_pod:kube_pod_owner:relabel` | `sum by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{owner_kind="Job"}, "workload", "$1", "owner_name", "(.*)"))` |
| `cluster_verb:apiserver_request_sli_bad_events:rate5m` | `(sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward"}[5m])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope=~"resource\|", le=~"1(\\.0)?"}[5m]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="namespace", le=~"5(\\.0)?"}[5m]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="cluster", le=~"30(\\.0)?"}[5m]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", code=~"5.."}[5m]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[5m]))` |
| `cluster_verb:apiserver_request_sli_events:rate5m` | `sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[5m]))` |
| `cluster_verb:apiserver_request_sli_bad_events:rate5m` | `(sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward"}[5m])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward", le=~"1(\\.0)?"}[5m]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", code=~"5.."}[5m]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[5m]))` |
| `cluster_verb:apiserver_request_sli_events:rate5m` | `sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[5m]))` |
| `apiserver_request:burnrate5m` | `cluster_verb:apiserver_request_sli_bad_events:rate5m / cluster_verb:apiserver_request_sli_events:rate5m` |
| `apiserver_request:burnrate30m` | `((sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward"}[30m])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope=~"resource\|", le=~"1(\\.0)?"}[30m]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="namespace", le=~"5(\\.0)?"}[30m]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="cluster", le=~"30(\\.0)?"}[30m]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", code=~"5.."}[30m]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[30m]))) / sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[30m]))` |
| `apiserver_request:burnrate30m` | `((sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward"}[30m])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward", le=~"1(\\.0)?"}[30m]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", code=~"5.."}[30m]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[30m]))) / sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[30m]))` |
| `apiserver_request:burnrate1h` | `((sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward"}[1h])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope=~"resource\|", le=~"1(\\.0)?"}[1h]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="namespace", le=~"5(\\.0)?"}[1h]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="cluster", le=~"30(\\.0)?"}[1h]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", code=~"5.."}[1h]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[1h]))) / sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[1h]))` |
| `apiserver_request:burnrate1h` | `((sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward"}[1h])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward", le=~"1(\\.0)?"}[1h]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", code=~"5.."}[1h]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[1h]))) / sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[1h]))` |
| `apiserver_request:burnrate2h` | `((sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward"}[2h])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope=~"resource\|", le=~"1(\\.0)?"}[2h]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="namespace", le=~"5(\\.0)?"}[2h]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="cluster", le=~"30(\\.0)?"}[2h]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", code=~"5.."}[2h]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[2h]))) / sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[2h]))` |
| `apiserver_request:burnrate2h` | `((sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward"}[2h])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward", le=~"1(\\.0)?"}[2h]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", code=~"5.."}[2h]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[2h]))) / sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[2h]))` |
| `apiserver_request:burnrate6h` | `((sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward"}[6h])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope=~"resource\|", le=~"1(\\.0)?"}[6h]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="namespace", le=~"5(\\.0)?"}[6h]) or rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", subresource!~"proxy\|attach\|log\|exec\|portforward", scope="cluster", le=~"30(\\.0)?"}[6h]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST", code=~"5.."}[6h]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[6h]))) / sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"GET\|LIST"}[6h]))` |
| `apiserver_request:burnrate6h` | `((sum by (cluster) (rate(apiserver_request_sli_duration_seconds_count{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward"}[6h])) - sum by (cluster) (rate(apiserver_request_sli_duration_seconds_bucket{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", subresource!~"proxy\|attach\|log\|exec\|portforward", le=~"1(\\.0)?"}[6h]))) + sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT", code=~"5.."}[6h]) or 0 * rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[6h]))) / sum by (cluster) (rate(apiserver_request_total{job=~"integrations/kubernetes/kube-apiserver\|apiserver\|kube-apiserver", verb=~"DELETE\|PATCH\|POST\|PUT"}[6h]))` |
| `apiserver_request:burnrate1d` | `avg_over_time(cluster_verb:apiserver_request_sli_bad_events:rate5m[1d]) / avg_over_time(cluster_verb:apiserver_request_sli_events:rate5m[1d])` |
| `apiserver_request:burnrate3d` | `avg_over_time(cluster_verb:apiserver_request_sli_bad_events:rate5m[3d]) / avg_over_time(cluster_verb:apiserver_request_sli_events:rate5m[3d])` |
