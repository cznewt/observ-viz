# mimir-ruler

- **source**: recording rules (deployed via deploy-lib with MIMIR_RULER_URL)

## recording-rules

- **patterns**: `base:cluster_nodes:n`, `node_namespace_pod_container:.*`, `namespace_cpu:.*`, `namespace_memory:.*`, `namespace_workload_pod:.*`, `instance:.*`, `cluster:.*`

### Live metrics (24)

- `base:cluster_nodes:n`
- `instance:cortex_queries:rate5m`
- `instance:cortex_received_samples:rate5m`
- `instance:guardian_installed_apps:sum`
- `instance:loki_bytes_received:rate5m`
- `instance:loki_lines_received:rate5m`
- `instance:node_cpu_utilisation:rate5m`
- `instance:node_load1_per_cpu:ratio`
- `instance:node_memory_swap_io_pages:rate5m`
- `instance:node_memory_utilisation:ratio`
- `instance:node_network_receive_bytes_excluding_lo:rate5m`
- `instance:node_network_transmit_bytes_excluding_lo:rate5m`
- `instance:temperature_celsius:max`
- `instance:tempo_request_rate:rate5m`
- `instance:tempo_spans_received:rate5m`
- `instance:windows_cpu_utilisation:rate5m`
- `instance:windows_logical_disk_free_bytes:sum`
- `instance:windows_memory_utilisation:ratio`
- `namespace_cpu:kube_pod_container_resource_limits:sum`
- `namespace_cpu:kube_pod_container_resource_requests:sum`
- `namespace_memory:kube_pod_container_resource_limits:sum`
- `namespace_memory:kube_pod_container_resource_requests:sum`
- `namespace_workload_pod:kube_pod_owner:relabel`
- `node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate`

