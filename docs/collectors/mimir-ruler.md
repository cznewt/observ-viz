# mimir.ruler

- **source**: recording rules (deployed via deploy-lib with MIMIR_RULER_URL)
- **patterns**: `base:cluster_nodes:n`, `node_namespace_pod_container:.*`, `namespace_cpu:.*`, `namespace_memory:.*`, `namespace_workload_pod:.*`, `instance:.*`, `cluster:.*`

## Live metrics (13)

- `base:cluster_nodes:n`
- `instance:node_cpu_utilisation:rate5m`
- `instance:node_load1_per_cpu:ratio`
- `instance:node_memory_swap_io_pages:rate5m`
- `instance:node_memory_utilisation:ratio`
- `instance:node_network_receive_bytes_excluding_lo:rate5m`
- `instance:node_network_transmit_bytes_excluding_lo:rate5m`
- `namespace_cpu:kube_pod_container_resource_limits:sum`
- `namespace_cpu:kube_pod_container_resource_requests:sum`
- `namespace_memory:kube_pod_container_resource_limits:sum`
- `namespace_memory:kube_pod_container_resource_requests:sum`
- `namespace_workload_pod:kube_pod_owner:relabel`
- `node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate`
