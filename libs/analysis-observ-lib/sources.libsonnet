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
    kong: {
      title: 'Kong',
      counter: 'kong_http_requests_total',
      bucket: 'kong_request_latency_ms_bucket',
      errorSelector: 'code=~"5.."',
      groupBy: ['service', 'route'],
      description: 'Every request the Kong gateway proxied, as its Prometheus plugin counts them. Point it at http_server_request_duration_seconds_* instead for a Kong exporting OpenTelemetry.',
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
      description: "Grafana's own HTTP handlers.",
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
      description: "Tempo's metrics-generator, counting every edge between two traced services.",
    },
  },

  // An anomaly source is just a set of series to watch; the method compares
  // each with its own past, so anything with a number works.
  anomaly: {
    process: {
      title: 'Process',
      service: 'process',
      description: 'The three numbers every Prometheus client exposes, whatever the service is written in.',
      series: [
        { key: 'cpu', title: 'CPU', unit: 'short', expr: 'sum by (instance) (rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval]))' },
        { key: 'rss', title: 'Resident memory', unit: 'bytes', expr: 'sum by (instance) (process_resident_memory_bytes{%(queriesSelector)s})' },
        { key: 'fds', title: 'Open file descriptors', unit: 'short', expr: 'sum by (instance) (process_open_fds{%(queriesSelector)s})' },
      ],
    },
    requests: {
      title: 'Requests',
      service: 'requests',
      description: 'Rate, failures and latency of a request-driven service, each against its own past - the RED numbers, watched for a change of shape rather than a threshold.',
      series: [
        { key: 'rate', title: 'Request rate', unit: 'reqps', expr: 'sum(rate(http_requests_total{%(queriesSelector)s}[$__rate_interval]))' },
        { key: 'errors', title: 'Error ratio', unit: 'percentunit', expr: 'sum(rate(http_requests_total{%(queriesSelector)s, status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(http_requests_total{%(queriesSelector)s}[$__rate_interval])), 1e-9)' },
        { key: 'latency', title: 'Duration p99', unit: 's', expr: 'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))' },
      ],
    },
  },

  // A burn-rate source is either windows of recorded burn rate, or an
  // availability and the objective it is measured against.
  burnRate: {
    apiserver: {
      title: 'Kubernetes API server',
      kind: 'windows',
      prefix: 'apiserver_request:burnrate',
      windows: ['5m', '30m', '1h', '2h', '6h', '1d', '3d'],
      groupBy: ['verb'],
      description: 'The kubernetes-mixin records these seven windows for the API server\'s own SLO, split by read and write.',
    },
    pyrra: {
      title: 'Pyrra SLOs',
      kind: 'budget',
      availability: 'pyrra_availability',
      objective: 'pyrra_objective',
      groupBy: ['slo'],
      description: 'Pyrra publishes the availability and the objective per SLO; the burn and the budget left follow from the two.',
    },
  },

  // A golden-signals source names the four: latency, traffic, errors and - the
  // one RED leaves out - saturation.
  golden: {
    apiserver: {
      title: 'Kubernetes API server',
      groupBy: ['verb'],
      overviewSignals: ['latency', 'traffic', 'errors'],
      description: 'Saturation here is the flowcontrol queue: requests waiting for a seat, which is what the API server does instead of failing when it is full.',
      signals: {
        latency: { title: 'Latency p99', unit: 's', expr: 'histogram_quantile(0.99, sum by (le, verb) (rate(apiserver_request_duration_seconds_bucket{%(queriesSelector)s, verb!~"WATCH|CONNECT"}[$__rate_interval])))' },
        traffic: { title: 'Requests', unit: 'reqps', expr: 'sum by (verb) (rate(apiserver_request_total{%(queriesSelector)s}[$__rate_interval]))' },
        errors: { title: 'Error ratio', unit: 'percentunit', expr: 'sum by (verb) (rate(apiserver_request_total{%(queriesSelector)s, code=~"5.."}[$__rate_interval])) / clamp_min(sum by (verb) (rate(apiserver_request_total{%(queriesSelector)s}[$__rate_interval])), 1e-9)' },
        // flowcontrol, not the old concurrency limit: a request that cannot get
        // a seat waits in a queue, and that queue is the saturation signal.
        // It carries no verb label, so it is not a column of the table.
        saturation: { title: 'Requests queued for a seat', unit: 'short', expr: 'sum (apiserver_flowcontrol_current_inqueue_requests)', description: 'Anything above zero means the API server is shedding concurrency: requests are waiting for a seat in their priority level. It carries neither verb nor the board\'s filters - flowcontrol queues by priority level, not by verb.' },
      },
    },
    node: {
      title: 'Linux node',
      groupBy: ['instance'],
      description: 'Traffic and errors come from the network, saturation from load against the CPUs it has - the number that leads the rest.',
      signals: {
        latency: { title: 'Disk IO latency', unit: 's', expr: 'sum by (instance) (rate(node_disk_io_time_weighted_seconds_total{%(queriesSelector)s}[$__rate_interval]))' },
        traffic: { title: 'Network throughput', unit: 'Bps', expr: 'sum by (instance) (rate(node_network_receive_bytes_total{%(queriesSelector)s, device!~"lo|veth.*"}[$__rate_interval]) + rate(node_network_transmit_bytes_total{%(queriesSelector)s, device!~"lo|veth.*"}[$__rate_interval]))' },
        errors: { title: 'Network errors and drops', unit: 'pps', expr: 'sum by (instance) (rate(node_network_receive_errs_total{%(queriesSelector)s}[$__rate_interval]) + rate(node_network_receive_drop_total{%(queriesSelector)s}[$__rate_interval]))' },
        saturation: { title: 'Load per CPU', unit: 'percentunit', expr: 'sum by (instance) (node_load1{%(queriesSelector)s}) / clamp_min(count by (instance) (node_cpu_seconds_total{%(queriesSelector)s, mode="idle"}), 1)' },
      },
    },
    ingressNginx: {
      title: 'Ingress NGINX',
      groupBy: ['ingress'],
      description: 'Saturation is the share of configured upstream connections in use, so it rises before the latency does.',
      signals: {
        latency: { title: 'Latency p99', unit: 's', expr: 'histogram_quantile(0.99, sum by (le, ingress) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))' },
        traffic: { title: 'Requests', unit: 'reqps', expr: 'sum by (ingress) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval]))' },
        errors: { title: 'Error ratio', unit: 'percentunit', expr: 'sum by (ingress) (rate(nginx_ingress_controller_requests{%(queriesSelector)s, status=~"5.."}[$__rate_interval])) / clamp_min(sum by (ingress) (rate(nginx_ingress_controller_requests{%(queriesSelector)s}[$__rate_interval])), 1e-9)' },
        saturation: { title: 'Active connections', unit: 'short', expr: 'sum (nginx_ingress_controller_nginx_process_connections{%(queriesSelector)s, state="active"})' },
      },
    },
    container: {
      title: 'Container',
      groupBy: ['namespace', 'pod'],
      description: 'Saturation is memory against the limit the container was given: the number that decides whether it is about to be killed.',
      signals: {
        latency: { title: 'CPU throttled', unit: 'percentunit', expr: 'sum by (namespace, pod) (rate(container_cpu_cfs_throttled_periods_total{%(queriesSelector)s, container!=""}[$__rate_interval])) / clamp_min(sum by (namespace, pod) (rate(container_cpu_cfs_periods_total{%(queriesSelector)s, container!=""}[$__rate_interval])), 1e-9)' },
        traffic: { title: 'CPU used', unit: 'short', expr: 'sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{%(queriesSelector)s, container!=""}[$__rate_interval]))' },
        errors: { title: 'Container restarts', unit: 'short', expr: 'sum by (namespace, pod) (increase(kube_pod_container_status_restarts_total{%(queriesSelector)s}[$__rate_interval]))' },
        saturation: { title: 'Memory against limit', unit: 'percentunit', expr: 'sum by (namespace, pod) (container_memory_working_set_bytes{%(queriesSelector)s, container!=""}) / clamp_min(sum by (namespace, pod) (kube_pod_container_resource_limits{%(queriesSelector)s, resource="memory"}), 1)' },
      },
    },
  },

  // A capacity source names one quantity that shrinks and what it is called.
  capacity: {
    filesystem: {
      title: 'Filesystems',
      // nsfs is the big one on a Kubernetes node: every container namespace
      // shows up as a zero-byte "filesystem" and would otherwise fill the
      // board with mounts that cannot run out of anything
      remaining: 'node_filesystem_avail_bytes{%(queriesSelector)s, fstype!~"tmpfs|ramfs|overlay|squashfs|nsfs|autofs|iso9660|fuse.*"}',
      remainingTitle: 'Free space',
      unit: 'bytes',
      groupBy: ['instance', 'mountpoint'],
      description: 'Free bytes per mounted filesystem, minus the ones that live in memory and cannot fill up the way a disk does.',
    },
    memory: {
      title: 'Node memory',
      remaining: 'node_memory_MemAvailable_bytes{%(queriesSelector)s}',
      remainingTitle: 'Available memory',
      unit: 'bytes',
      groupBy: ['instance'],
      description: 'Memory the kernel says is available - which is not free memory, it counts what the cache would give back.',
    },
    certificates: {
      title: 'Certificates',
      remaining: 'certmanager_certificate_expiration_timestamp_seconds{%(queriesSelector)s} - time()',
      remainingTitle: 'Certificate life left',
      unit: 's',
      groupBy: ['namespace', 'name'],
      description: 'Seconds until each cert-manager certificate expires. This one shrinks by a second per second, so the prediction is exact rather than a trend.',
    },
  },

  // A USE source names the four resources and how each one is measured. The
  // node profile is the node_exporter one the node mixin uses; the container
  // profile reads the same four from cAdvisor.
  use: {
    node: {
      title: 'Nodes (node_exporter)',
      groupBy: ['instance'],
      description: "Brendan Gregg's USE method over node_exporter: for every resource, how busy it is, how much work is queued, and what is failing.",
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
