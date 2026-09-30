# MinIO  (`g.libs.applications.minio`)

Dashboard uid `observ-viz-minio` · 34 signals · 7 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `bucketBytes` | bytes | `sum by (namespace, bucket) (minio_bucket_usage_total_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `bucketObjects` | short | `sum by (namespace, bucket) (minio_bucket_usage_object_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `bucketRequests` | reqps | `sum by (namespace, bucket) (rate(minio_bucket_requests_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `bucketRx` | Bps | `sum by (namespace, bucket) (rate(minio_bucket_traffic_received_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `bucketTx` | Bps | `sum by (namespace, bucket) (rate(minio_bucket_traffic_sent_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `buckets` | short | `sum(minio_cluster_bucket_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `capacityUsed` | percentunit | `1 - sum(minio_cluster_capacity_usable_free_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}) / sum(minio_cluster_capacity_usable_total_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `cpu` | short | `sum by (namespace, pod) (rate(minio_node_process_cpu_total_seconds{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `dataStored` | bytes | `sum(minio_cluster_usage_total_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `driveErrors` | short | `sum by (namespace, drive) (increase(minio_node_drive_errors_ioerror{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]) + increase(minio_node_drive_errors_timeout{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]) + increase(minio_node_drive_errors_availability{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `driveFreeInodes` | short | `minio_node_drive_free_inodes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `driveLatency` | µs | `max by (namespace, api) (minio_node_drive_latency_us{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `driveUsed` | percentunit | `minio_node_drive_used_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"} / minio_node_drive_total_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}` | — |
| `drivesOffline` | short | `sum(minio_cluster_drive_offline_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `drivesOnline` | short | `sum(minio_cluster_drive_online_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `fds` | percentunit | `sum by (namespace, pod) (minio_node_file_descriptor_open_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}) / sum by (namespace, pod) (minio_node_file_descriptor_limit_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `goroutines` | short | `sum by (namespace, pod) (minio_node_go_routine_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `memory` | bytes | `sum by (namespace, pod) (minio_node_process_resident_memory_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `nodesOffline` | short | `sum(minio_cluster_nodes_offline_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `nodesOnline` | short | `sum(minio_cluster_nodes_online_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `objects` | short | `sum(minio_cluster_usage_object_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `s3Errors4xx` | reqps | `sum by (api) (rate(minio_s3_requests_4xx_errors_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `s3Errors5xx` | reqps | `sum by (api) (rate(minio_s3_requests_errors_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])) - sum by (api) (rate(minio_s3_requests_4xx_errors_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `s3Inflight` | short | `sum by (namespace) (minio_s3_requests_inflight_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `s3RejectedAuth` | reqps | `sum by (namespace) (rate(minio_s3_requests_rejected_auth_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `s3Requests` | reqps | `sum by (api) (rate(minio_s3_requests_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `s3Rx` | Bps | `sum by (namespace) (rate(minio_s3_traffic_received_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `s3Tx` | Bps | `sum by (namespace) (rate(minio_s3_traffic_sent_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `s3Waiting` | short | `sum by (namespace) (minio_s3_requests_waiting_total{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `ttfbP99` | s | `histogram_quantile(0.99, sum by (le, api) (rate(minio_s3_requests_ttfb_seconds_distribution{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"}[$__rate_interval])))` | — |
| `unhealthy` | short | `count(minio_cluster_health_status{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"} == 0) or vector(0)` | — |
| `usableTotal` | bytes | `sum by (cluster, namespace) (minio_cluster_capacity_usable_total_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `usableUsed` | bytes | `sum by (cluster, namespace) (minio_cluster_capacity_usable_total_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"} - minio_cluster_capacity_usable_free_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |
| `usageByNs` | bytes | `sum by (cluster, namespace) (minio_cluster_usage_total_bytes{job=~"$job", cluster=~"$cluster", namespace=~"$namespace"})` | — |

## Dashboard

- **Overview** — `a_unhealthy`, `b_nodesOnline`, `c_nodesOffline`, `d_drivesOnline`, `e_drivesOffline`, `f_capacityUsed`, `g_dataStored`, `h_objects`
- **Capacity** — `a_usable`, `b_usage`
- **Buckets** — `bucketsTable`
- **Bucket activity** — `a_size`, `b_objects`, `c_requests`, `d_traffic`
- **S3 API** — `a_requests`, `b_errors`, `c_ttfb`, `d_traffic`, `e_inflight`, `f_rejected`
- **Drives** — `a_used`, `b_latency`, `c_errors`, `d_inodes`
- **Process** — `a_memory`, `b_cpu`, `c_fds`, `d_goroutines`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `MinioDown` | critical | 5m | — |
| `MinioClusterUnhealthy` | critical | 5m | — |
| `MinioNodesOffline` | critical | 5m | — |
| `MinioDrivesOffline` | critical | 5m | — |
| `MinioCapacityHigh` | warning | 15m | — |
| `MinioCapacityCritical` | critical | 15m | — |
| `MinioS3ServerErrors` | warning | 15m | — |
