# Kubernetes cluster  (`g.libs.kubernetes.cluster`)

Dashboard uid `kube-cluster` · 7 signals · 11 alerts · 9 recording rules.

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
| `KubePersistentVolumeFillingUp` | warning | 1h | — |
| `KubeNodePressure` | warning | 5m | — |
| `KubeClusterPressure` | critical | 5m | — |
| `KubeNodesMissing` | critical | 5m | — |

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
