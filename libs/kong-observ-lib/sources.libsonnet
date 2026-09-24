// observ-viz Kong sources (hand-written).
// Kong reports the same gateway two ways, and the metric names share nothing:
//
//   prometheus     the Kong Prometheus plugin (kong_*). Kong 3.x renamed most
//                  of these - kong_http_status -> kong_http_requests_total,
//                  kong_latency_bucket -> kong_{request,kong,upstream}_latency_ms_bucket,
//                  kong_bandwidth -> kong_bandwidth_bytes - so `prometheus2`
//                  keeps the 2.x names for a gateway that has not moved yet.
//   opentelemetry  HTTP server semantic conventions, which is what comes out of
//                  the OTLP metrics path (from Kong itself or a collector in
//                  front of it). Route and status live in different labels, and
//                  duration is in seconds rather than milliseconds.
//
// A profile names the metrics, the labels the board groups and filters by, and
// the unit its latency histogram is in. Anything the implementation cannot
// answer is simply absent, and the board drops those panels.
{
  prometheus: {
    title: 'Prometheus plugin',
    description: 'Kong 3.x with the Prometheus plugin enabled (`kong_*`), which is the only source that also reports what the gateway itself is doing: its shared dictionaries, its connections and whether it can reach the datastore.',
    requests: 'kong_http_requests_total',
    statusLabel: 'code',
    routeLabels: ['service', 'route'],
    latencyBucket: 'kong_request_latency_ms_bucket',
    latencyUnit: 'ms',
    // what the gateway adds on top of the upstream, split out
    proxyLatencyBucket: 'kong_kong_latency_ms_bucket',
    upstreamLatencyBucket: 'kong_upstream_latency_ms_bucket',
    bandwidth: 'kong_bandwidth_bytes',
    directionLabel: 'direction',
    // gateway internals, Prometheus plugin only
    connections: 'kong_nginx_http_current_connections',
    sharedDict: 'kong_memory_lua_shared_dict_bytes',
    sharedDictTotal: 'kong_memory_lua_shared_dict_total_bytes',
    workerVms: 'kong_memory_workers_lua_vms_bytes',
    datastore: 'kong_datastore_reachable',
    targetHealth: 'kong_upstream_target_health',
    timers: 'kong_nginx_timers',
  },
  // Kong 2.x, same plugin, older metric names
  prometheus2: self.prometheus {
    title: 'Prometheus plugin (Kong 2.x)',
    description: 'Kong 2.x with the Prometheus plugin: the same numbers under the names that version used.',
    requests: 'kong_http_status',
    latencyBucket: 'kong_latency_bucket{type="request"}',
    proxyLatencyBucket: 'kong_latency_bucket{type="kong"}',
    upstreamLatencyBucket: 'kong_latency_bucket{type="upstream"}',
    bandwidth: 'kong_bandwidth',
    connections: 'kong_nginx_http_current_connections',
  },
  opentelemetry: {
    title: 'OpenTelemetry',
    description: 'Kong through the OTLP metrics path, reporting HTTP server semantic conventions. It describes the traffic, not the gateway: there is no Kong-versus-upstream split and no shared-dictionary or datastore reporting here.',
    requests: 'http_server_request_duration_seconds_count',
    statusLabel: 'http_response_status_code',
    routeLabels: ['http_route'],
    latencyBucket: 'http_server_request_duration_seconds_bucket',
    latencyUnit: 's',
    upstreamLatencyBucket: 'http_client_request_duration_seconds_bucket',
    bandwidthIn: 'http_server_request_body_size_bytes_total',
    bandwidthOut: 'http_server_response_body_size_bytes_total',
    activeRequests: 'http_server_active_requests',
  },
}
