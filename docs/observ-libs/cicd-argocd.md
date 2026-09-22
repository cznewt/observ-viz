# Argo CD  (`g.libs.cicd.argocd`)

Dashboard uid `observ-viz-argocd` · 26 signals · 6 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `appTable` | short | `max by (name, project, sync_status, health_status) (argocd_app_info{job=~"$job"})` | — |
| `apps` | short | `count(argocd_app_info{job=~"$job"})` | — |
| `appsByHealth` | short | `sum by (health_status) (argocd_app_info{job=~"$job"})` | — |
| `appsBySync` | short | `sum by (sync_status) (argocd_app_info{job=~"$job"})` | — |
| `appsOutOfSync` | short | `sum(argocd_app_info{job=~"$job", sync_status="OutOfSync"}) or vector(0)` | — |
| `appsUnhealthy` | short | `sum(argocd_app_info{job=~"$job", health_status!~"Healthy\|Progressing"}) or vector(0)` | — |
| `clusterEvents` | short | `sum by (server) (rate(argocd_cluster_events_total{job=~"$job"}[$__rate_interval]))` | — |
| `clusterObjects` | short | `sum by (server) (argocd_cluster_api_resource_objects{job=~"$job"})` | — |
| `clusters` | short | `count(argocd_cluster_info{job=~"$job"})` | — |
| `clustersDown` | short | `count(argocd_cluster_connection_status{job=~"$job"} == 0) or vector(0)` | — |
| `cpu` | short | `sum by (pod) (rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval]))` | — |
| `gitP99` | s | `histogram_quantile(0.99, sum by (le, request_type) (rate(argocd_git_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `gitRequests` | reqps | `sum by (request_type) (rate(argocd_git_request_total{job=~"$job"}[$__rate_interval]))` | — |
| `k8sRequests` | reqps | `sum by (verb, response_code) (rate(argocd_app_k8s_request_total{job=~"$job"}[$__rate_interval]))` | — |
| `kubectlPending` | short | `sum by (command) (argocd_kubectl_exec_pending{job=~"$job"})` | — |
| `reconcileP50` | s | `histogram_quantile(0.50, sum by (le) (rate(argocd_app_reconcile_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `reconcileP99` | s | `histogram_quantile(0.99, sum by (le) (rate(argocd_app_reconcile_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `reconcileRate` | short | `sum(rate(argocd_app_reconcile_count{job=~"$job"}[$__rate_interval]))` | — |
| `redisFailed` | short | `sum(rate(argocd_redis_request_total{job=~"$job", failed="true"}[$__rate_interval]))` | — |
| `repoPending` | short | `sum(argocd_repo_pending_request_total{job=~"$job"})` | — |
| `rss` | bytes | `sum by (pod) (process_resident_memory_bytes{job=~"$job"})` | — |
| `syncFailures1h` | short | `sum(increase(argocd_app_sync_total{job=~"$job", phase=~"Error\|Failed"}[1h])) or vector(0)` | — |
| `syncFailuresByApp` | short | `sum by (name) (increase(argocd_app_sync_total{job=~"$job", phase=~"Error\|Failed"}[$__rate_interval]))` | — |
| `syncs` | short | `sum by (phase) (rate(argocd_app_sync_total{job=~"$job"}[$__rate_interval]))` | — |
| `workqueueDepth` | short | `sum by (name) (workqueue_depth{job=~"$job"})` | — |
| `workqueueLatencyP99` | s | `histogram_quantile(0.99, sum by (le, name) (rate(workqueue_queue_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |

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

## Recording rules

| Record | Expression |
|--------|------------|
| `project:argocd_app_sync_failed:increase10m` | `sum by (project, name) (increase(argocd_app_sync_total{phase=~"Error\|Failed"}[10m]))` |
| `job:argocd_app_reconcile_seconds:p99_5m` | `histogram_quantile(0.99, sum by (le, job) (rate(argocd_app_reconcile_bucket[5m])))` |
