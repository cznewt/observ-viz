// observ-viz analysis sources (hand-written).
// A *source* says where a method's numbers come from, so the same RED or USE
// board can be pointed at any instrumentation. A RED source names a request
// counter, how to pick the failures out of it (a label selector on the same
// counter, or a separate counter), a latency histogram, and the dimension the
// breakdown tables group by.
{
  red: {
    // OpenTelemetry HTTP server semconv (otel-sdk, and anything using it)
    otelHttpServer: {
      title: 'HTTP server (OpenTelemetry)',
      counter: 'http_server_request_duration_seconds_count',
      bucket: 'http_server_request_duration_seconds_bucket',
      errorSelector: 'http_response_status_code=~"5.."',
      groupBy: ['http_route'],
      description: 'OpenTelemetry HTTP server semantic conventions: one histogram per request, split by route and status code.',
    },
    // prometheus/client_* defaults, the shape most hand-instrumented apps emit
    prometheusClient: {
      title: 'HTTP server (Prometheus client)',
      counter: 'http_requests_total',
      bucket: 'http_request_duration_seconds_bucket',
      errorSelector: 'status=~"5.."',
      groupBy: ['handler'],
      description: 'The `http_requests_total` / `http_request_duration_seconds` pair the Prometheus client libraries expose.',
    },
    ingressNginx: {
      title: 'Ingress NGINX',
      counter: 'nginx_ingress_controller_requests',
      bucket: 'nginx_ingress_controller_request_duration_seconds_bucket',
      errorSelector: 'status=~"5.."',
      groupBy: ['ingress'],
      description: 'Every request the cluster ingress terminates, as the controller counts them.',
    },
    django: {
      title: 'Django',
      counter: 'django_http_responses_total_by_status_total',
      bucket: 'django_http_requests_latency_seconds_by_view_method_bucket',
      errorSelector: 'status=~"5.."',
      groupBy: ['view'],
      description: 'django-prometheus: responses by status, latency by view and method.',
    },
    grafana: {
      title: 'Grafana',
      counter: 'grafana_http_request_duration_seconds_count',
      bucket: 'grafana_http_request_duration_seconds_bucket',
      errorSelector: 'status_code=~"5.."',
      groupBy: ['handler'],
      description: 'Grafana\'s own HTTP handlers.',
    },
    apiserver: {
      title: 'Kubernetes API server',
      counter: 'apiserver_request_duration_seconds_count',
      bucket: 'apiserver_request_duration_seconds_bucket',
      errorSelector: 'code=~"5.."',
      groupBy: ['resource'],
      description: 'Every call to the API server, by resource and verb.',
    },
    // spans, not scrapes: Tempo's metrics-generator turns traces into the same
    // three numbers, and failures are their own counter rather than a label.
    serviceGraph: {
      title: 'Service graph (from traces)',
      counter: 'traces_service_graph_request_total',
      errorCounter: 'traces_service_graph_request_failed_total',
      bucket: 'traces_service_graph_request_server_seconds_bucket',
      groupBy: ['client', 'server'],
      description: 'Tempo\'s metrics-generator, counting every edge between two traced services.',
    },
  },

  // A USE source names the four resources and how each one is measured. The
  // node profile is the node_exporter one the node mixin uses; the container
  // profile reads the same four from cAdvisor.
  use: {
    node: {
      title: 'Nodes (node_exporter)',
      groupBy: ['instance'],
      description: 'Brendan Gregg\'s USE method over node_exporter: for every resource, how busy it is, how much work is queued, and what is failing.',
      resources: {
        CPU: {
          utilisation: { expr: '1 - avg by (%(by)s) (rate(node_cpu_seconds_total{mode="idle", %(sel)s}[$__rate_interval]))', unit: 'percentunit' },
          saturation: { expr: 'sum by (%(by)s) (node_load1{%(sel)s}) / count by (%(by)s) (node_cpu_seconds_total{mode="idle", %(sel)s})', unit: 'percentunit' },
        },
        Memory: {
          utilisation: { expr: '1 - (node_memory_MemAvailable_bytes{%(sel)s} / node_memory_MemTotal_bytes{%(sel)s})', unit: 'percentunit' },
          saturation: { expr: 'rate(node_vmstat_pgmajfault{%(sel)s}[$__rate_interval])', unit: 'short' },
        },
        Disk: {
          utilisation: { expr: 'rate(node_disk_io_time_seconds_total{%(sel)s}[$__rate_interval])', unit: 'percentunit' },
          saturation: { expr: 'rate(node_disk_io_time_weighted_seconds_total{%(sel)s}[$__rate_interval])', unit: 'short' },
        },
        Network: {
          utilisation: { expr: 'rate(node_network_receive_bytes_total{%(sel)s, device!~"lo|veth.*"}[$__rate_interval]) + rate(node_network_transmit_bytes_total{%(sel)s, device!~"lo|veth.*"}[$__rate_interval])', unit: 'Bps' },
          saturation: { expr: 'rate(node_network_receive_drop_total{%(sel)s}[$__rate_interval]) + rate(node_network_transmit_drop_total{%(sel)s}[$__rate_interval])', unit: 'pps' },
          errors: { expr: 'rate(node_network_receive_errs_total{%(sel)s}[$__rate_interval]) + rate(node_network_transmit_errs_total{%(sel)s}[$__rate_interval])', unit: 'pps' },
        },
      },
    },
    container: {
      title: 'Containers (cAdvisor)',
      groupBy: ['namespace', 'pod'],
      description: 'The same four resources per container, read from cAdvisor; saturation is what the cgroup throttled or reclaimed.',
      resources: {
        CPU: {
          utilisation: { expr: 'sum by (%(by)s) (rate(container_cpu_usage_seconds_total{%(sel)s, container!=""}[$__rate_interval]))', unit: 'short' },
          saturation: { expr: 'sum by (%(by)s) (rate(container_cpu_cfs_throttled_seconds_total{%(sel)s, container!=""}[$__rate_interval]))', unit: 'short' },
        },
        Memory: {
          utilisation: { expr: 'sum by (%(by)s) (container_memory_working_set_bytes{%(sel)s, container!=""})', unit: 'bytes' },
          saturation: { expr: 'sum by (%(by)s) (rate(container_memory_failcnt{%(sel)s, container!=""}[$__rate_interval]))', unit: 'short' },
        },
        Disk: {
          utilisation: { expr: 'sum by (%(by)s) (rate(container_fs_reads_bytes_total{%(sel)s}[$__rate_interval]) + rate(container_fs_writes_bytes_total{%(sel)s}[$__rate_interval]))', unit: 'Bps' },
        },
        Network: {
          utilisation: { expr: 'sum by (%(by)s) (rate(container_network_receive_bytes_total{%(sel)s}[$__rate_interval]) + rate(container_network_transmit_bytes_total{%(sel)s}[$__rate_interval]))', unit: 'Bps' },
          saturation: { expr: 'sum by (%(by)s) (rate(container_network_receive_packets_dropped_total{%(sel)s}[$__rate_interval]) + rate(container_network_transmit_packets_dropped_total{%(sel)s}[$__rate_interval]))', unit: 'pps' },
          errors: { expr: 'sum by (%(by)s) (rate(container_network_receive_errors_total{%(sel)s}[$__rate_interval]) + rate(container_network_transmit_errors_total{%(sel)s}[$__rate_interval]))', unit: 'pps' },
        },
      },
    },
  },
}
