# Elasticsearch  (`g.libs.databases.search.elasticsearch`)

Dashboard uid `observ-viz-elasticsearch` · 28 signals · 7 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `active` | short | `sum(elasticsearch_cluster_health_active_shards{job=~"$job", cluster=~"$cluster"})` | — |
| `activePrimary` | short | `sum(elasticsearch_cluster_health_active_primary_shards{job=~"$job", cluster=~"$cluster"})` | — |
| `breakers` | short | `sum by (name, breaker) (increase(elasticsearch_breakers_tripped{job=~"$job", cluster=~"$cluster", name=~"$name"}[$__rate_interval]))` | — |
| `cpu` | percentunit | `elasticsearch_process_cpu_percent{job=~"$job", cluster=~"$cluster", name=~"$name"} / 100` | — |
| `dataNodes` | short | `sum(elasticsearch_cluster_health_number_of_data_nodes{job=~"$job", cluster=~"$cluster"})` | — |
| `delayedUnassigned` | short | `sum(elasticsearch_cluster_health_delayed_unassigned_shards{job=~"$job", cluster=~"$cluster"})` | — |
| `disk` | percentunit | `1 - sum by (name) (elasticsearch_filesystem_data_available_bytes{job=~"$job", cluster=~"$cluster", name=~"$name"}) / sum by (name) (elasticsearch_filesystem_data_size_bytes{job=~"$job", cluster=~"$cluster", name=~"$name"})` | — |
| `docsPerNode` | short | `elasticsearch_indices_docs{job=~"$job", cluster=~"$cluster", name=~"$name"}` | — |
| `documents` | short | `sum(elasticsearch_indices_docs{job=~"$job", cluster=~"$cluster", name=~"$name"})` | — |
| `gc` | s | `rate(elasticsearch_jvm_gc_collection_seconds_sum{job=~"$job", cluster=~"$cluster", name=~"$name"}[$__rate_interval])` | — |
| `health` | short | `min(2 * max by (cluster, exported_cluster) (elasticsearch_cluster_health_status{color="green", job=~"$job", cluster=~"$cluster"}) + max by (cluster, exported_cluster) (elasticsearch_cluster_health_status{color="yellow", job=~"$job", cluster=~"$cluster"}))` | — |
| `heap` | percentunit | `elasticsearch_jvm_memory_used_bytes{area="heap", job=~"$job", cluster=~"$cluster", name=~"$name"} / elasticsearch_jvm_memory_max_bytes{area="heap", job=~"$job", cluster=~"$cluster", name=~"$name"}` | — |
| `heapAvg` | percentunit | `avg_over_time(elasticsearch_jvm_memory_used_bytes{area="heap", job=~"$job", cluster=~"$cluster", name=~"$name"}[15m]) / elasticsearch_jvm_memory_max_bytes{area="heap", job=~"$job", cluster=~"$cluster", name=~"$name"}` | — |
| `indexRate` | ops | `rate(elasticsearch_indices_indexing_index_total{job=~"$job", cluster=~"$cluster", name=~"$name"}[$__rate_interval])` | — |
| `indexSize` | bytes | `elasticsearch_indices_store_size_bytes{job=~"$job", cluster=~"$cluster", name=~"$name"}` | — |
| `initializing` | short | `sum(elasticsearch_cluster_health_initializing_shards{job=~"$job", cluster=~"$cluster"})` | — |
| `memory` | bytes | `elasticsearch_jvm_memory_used_bytes{job=~"$job", cluster=~"$cluster", name=~"$name"}` | — |
| `nodes` | short | `sum(elasticsearch_cluster_health_number_of_nodes{job=~"$job", cluster=~"$cluster"})` | — |
| `pendingTasks` | short | `sum(elasticsearch_cluster_health_number_of_pending_tasks{job=~"$job", cluster=~"$cluster"})` | — |
| `poolActive` | short | `sum by (type) (elasticsearch_thread_pool_active_count{job=~"$job", cluster=~"$cluster", name=~"$name"})` | — |
| `poolQueue` | short | `sum by (type) (elasticsearch_thread_pool_queue_count{type!="management", job=~"$job", cluster=~"$cluster", name=~"$name"})` | — |
| `poolRejections` | ops | `rate(elasticsearch_thread_pool_rejected_count{job=~"$job", cluster=~"$cluster", name=~"$name"}[$__rate_interval])` | — |
| `queryLatency` | s | `rate(elasticsearch_indices_search_query_time_seconds{job=~"$job", cluster=~"$cluster", name=~"$name"}[$__rate_interval]) / rate(elasticsearch_indices_search_query_total{job=~"$job", cluster=~"$cluster", name=~"$name"}[$__rate_interval])` | — |
| `queryRate` | ops | `rate(elasticsearch_indices_search_query_total{job=~"$job", cluster=~"$cluster", name=~"$name"}[$__rate_interval])` | — |
| `relocating` | short | `sum(elasticsearch_cluster_health_relocating_shards{job=~"$job", cluster=~"$cluster"})` | — |
| `transportRx` | Bps | `rate(elasticsearch_transport_rx_size_bytes_total{job=~"$job", cluster=~"$cluster", name=~"$name"}[$__rate_interval])` | — |
| `transportTx` | Bps | `rate(elasticsearch_transport_tx_size_bytes_total{job=~"$job", cluster=~"$cluster", name=~"$name"}[$__rate_interval])` | — |
| `unassigned` | short | `sum(elasticsearch_cluster_health_unassigned_shards{job=~"$job", cluster=~"$cluster"})` | — |

## Dashboard

- **Overview** — `a_health`, `b_nodes`, `c_dataNodes`, `d_pending`, `e_unassigned`, `f_documents`
- **Shards** — `a_shards`
- **Documents** — `a_docs`, `b_size`, `c_index`, `d_query`, `e_latency`
- **Nodes** — `a_heap`, `b_heapAvg`, `c_memory`, `d_gc`, `e_cpu`, `f_disk`, `g_breakers`
- **Threads & network** — `a_active`, `b_queue`, `c_rejections`, `d_transport`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `ElasticsearchDown` | critical | 5m | — |
| `ElasticsearchClusterRed` | critical | 5m | — |
| `ElasticsearchClusterYellow` | warning | 20m | — |
| `ElasticsearchTooFewNodesRunning` | critical | 5m | — |
| `ElasticsearchHeapTooHigh` | critical | 15m | — |
| `ElasticsearchDiskSpaceLow` | warning | 15m | — |
| `ElasticsearchThreadPoolRejections` | warning | 10m | — |
