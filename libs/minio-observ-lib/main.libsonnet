// observ-viz MinIO pack (hand-written).
// Built for MinIO's v2 Prometheus metrics (minio_cluster_*, minio_node_*,
// minio_bucket_*, minio_s3_*) as the catalog minio component exposes them:
// MINIO_PROMETHEUS_AUTH_TYPE=public, cluster + node + bucket endpoints merged by
// its minio-exporter-merger sidecar on :8080 (job annotation-autodiscovery/minio).
// Supersedes the catalog's minio-mixin / community-minio-mixin, whose alerts
// read v1 names (minio_disks_offline, disk_storage_used) current MinIO no
// longer exports.
// Usage:
//   g.libs.applications.minio.new({ selector: 'job="annotation-autodiscovery/minio"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-minio',
      dashboardTitle: 'MinIO',
      // Platform / Infrastructure / Storage
      folderPath: (import 'libs/common-lib/folders.libsonnet').storage,
      dashboardTags: ['minio', 's3', 'storage', 'app-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      // one MinIO deployment per namespace
      selector: 'job=~"$job", cluster=~"$cluster", namespace=~"$namespace"',
      varMetric: 'minio_cluster_health_status',
      varLabels: ['cluster', 'namespace'],
      ruleSelector: '',
      capacityWarning: 0.8,
      capacityCritical: 0.9,
      serverErrorRatio: 0.05,
    } + config;

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';

    local sig(name, expr, unit, legend='{{namespace}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      // overview
      unhealthy: sig('Unhealthy', 'count(minio_cluster_health_status{%(queriesSelector)s} == 0) or vector(0)', 'short', 'unhealthy'),
      nodesOnline: sig('Nodes online', 'sum(minio_cluster_nodes_online_total{%(queriesSelector)s})', 'short', 'online'),
      nodesOffline: sig('Nodes offline', 'sum(minio_cluster_nodes_offline_total{%(queriesSelector)s})', 'short', 'offline'),
      drivesOnline: sig('Drives online', 'sum(minio_cluster_drive_online_total{%(queriesSelector)s})', 'short', 'online'),
      drivesOffline: sig('Drives offline', 'sum(minio_cluster_drive_offline_total{%(queriesSelector)s})', 'short', 'offline'),
      capacityUsed: sig('Capacity used', '1 - sum(minio_cluster_capacity_usable_free_bytes{%(queriesSelector)s}) / sum(minio_cluster_capacity_usable_total_bytes{%(queriesSelector)s})', 'percentunit', 'used'),
      dataStored: sig('Data stored', 'sum(minio_cluster_usage_total_bytes{%(queriesSelector)s})', 'bytes', 'stored'),
      objects: sig('Objects', 'sum(minio_cluster_usage_object_total{%(queriesSelector)s})', 'short', 'objects'),
      buckets: sig('Buckets', 'sum(minio_cluster_bucket_total{%(queriesSelector)s})', 'short', 'buckets'),
      // capacity over time, per deployment
      usableUsed: sig('Usable capacity used', 'sum by (cluster, namespace) (minio_cluster_capacity_usable_total_bytes{%(queriesSelector)s} - minio_cluster_capacity_usable_free_bytes{%(queriesSelector)s})', 'bytes', '{{cluster}} / {{namespace}} used'),
      usableTotal: sig('Usable capacity', 'sum by (cluster, namespace) (minio_cluster_capacity_usable_total_bytes{%(queriesSelector)s})', 'bytes', '{{cluster}} / {{namespace}} total'),
      usageByNs: sig('Data stored', 'sum by (cluster, namespace) (minio_cluster_usage_total_bytes{%(queriesSelector)s})', 'bytes', '{{cluster}} / {{namespace}}'),
      // buckets
      bucketBytes: sig('Bucket size', 'sum by (namespace, bucket) (minio_bucket_usage_total_bytes{%(queriesSelector)s})', 'bytes', '{{namespace}} / {{bucket}}'),
      bucketObjects: sig('Bucket objects', 'sum by (namespace, bucket) (minio_bucket_usage_object_total{%(queriesSelector)s})', 'short', '{{namespace}} / {{bucket}}'),
      bucketRequests: sig('Bucket requests', 'sum by (namespace, bucket) (rate(minio_bucket_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{namespace}} / {{bucket}}'),
      bucketRx: sig('Bucket received', 'sum by (namespace, bucket) (rate(minio_bucket_traffic_received_bytes{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{namespace}} / {{bucket}}'),
      bucketTx: sig('Bucket sent', 'sum by (namespace, bucket) (rate(minio_bucket_traffic_sent_bytes{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{namespace}} / {{bucket}}'),
      // S3 API
      s3Requests: sig('S3 requests', 'sum by (api) (rate(minio_s3_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{api}}'),
      s3Errors4xx: sig('S3 4xx', 'sum by (api) (rate(minio_s3_requests_4xx_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{api}} 4xx'),
      // errors_total counts 4xx and 5xx; the 5xx series only exists once one happened
      s3Errors5xx: sig('S3 5xx', 'sum by (api) (rate(minio_s3_requests_errors_total{%(queriesSelector)s}[$__rate_interval])) - sum by (api) (rate(minio_s3_requests_4xx_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{api}} 5xx'),
      s3RejectedAuth: sig('S3 rejected (auth)', 'sum by (namespace) (rate(minio_s3_requests_rejected_auth_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{namespace}}'),
      s3Inflight: sig('S3 in flight', 'sum by (namespace) (minio_s3_requests_inflight_total{%(queriesSelector)s})', 'short', '{{namespace}} in flight'),
      s3Waiting: sig('S3 waiting', 'sum by (namespace) (minio_s3_requests_waiting_total{%(queriesSelector)s})', 'short', '{{namespace}} waiting'),
      ttfbP99: sig('TTFB p99', 'histogram_quantile(0.99, sum by (le, api) (rate(minio_s3_requests_ttfb_seconds_distribution{%(queriesSelector)s}[$__rate_interval])))', 's', '{{api}} p99'),
      s3Rx: sig('S3 received', 'sum by (namespace) (rate(minio_s3_traffic_received_bytes{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{namespace}} received'),
      s3Tx: sig('S3 sent', 'sum by (namespace) (rate(minio_s3_traffic_sent_bytes{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{namespace}} sent'),
      // drives
      driveUsed: sig('Drive used', 'minio_node_drive_used_bytes{%(queriesSelector)s} / minio_node_drive_total_bytes{%(queriesSelector)s}', 'percentunit', '{{namespace}} / {{drive}}'),
      driveFreeInodes: sig('Drive free inodes', 'minio_node_drive_free_inodes{%(queriesSelector)s}', 'short', '{{namespace}} / {{drive}}'),
      driveLatency: sig('Drive latency', 'max by (namespace, api) (minio_node_drive_latency_us{%(queriesSelector)s})', 'µs', '{{namespace}} / {{api}}'),
      driveErrors: sig('Drive errors', 'sum by (namespace, drive) (increase(minio_node_drive_errors_ioerror{%(queriesSelector)s}[$__rate_interval]) + increase(minio_node_drive_errors_timeout{%(queriesSelector)s}[$__rate_interval]) + increase(minio_node_drive_errors_availability{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{namespace}} / {{drive}}'),
      // process
      memory: sig('Resident memory', 'sum by (namespace, pod) (minio_node_process_resident_memory_bytes{%(queriesSelector)s})', 'bytes', '{{namespace}} / {{pod}}'),
      cpu: sig('CPU', 'sum by (namespace, pod) (rate(minio_node_process_cpu_total_seconds{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{namespace}} / {{pod}}'),
      fds: sig('Open file descriptors', 'sum by (namespace, pod) (minio_node_file_descriptor_open_total{%(queriesSelector)s}) / sum by (namespace, pod) (minio_node_file_descriptor_limit_total{%(queriesSelector)s})', 'percentunit', '{{namespace}} / {{pod}}'),
      goroutines: sig('Goroutines', 'sum by (namespace, pod) (minio_node_go_routine_total{%(queriesSelector)s})', 'short', '{{namespace}} / {{pod}}'),
    };

    // per-bucket inventory: identity + size from A, the other columns summed
    // by the cluster|namespace|bucket key and joined on it (as the Syncthing
    // folders table)
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local jk = '"key", "|", "cluster", "namespace", "bucket"';
    local lj(m) = 'label_join(' + m + '{' + cfg.selector + '}, ' + jk + ')';
    local bucketsTable =
      panel.table.new('Buckets')
      + panel.table.withTargets([
        tq('sum by (key, cluster, namespace, bucket) (' + lj('minio_bucket_usage_total_bytes') + ')'),  // A: identity + size
        tq('sum by (key) (' + lj('minio_bucket_usage_object_total') + ')'),  // B
        tq('sum by (key) (' + lj('minio_bucket_usage_version_total') + ')'),  // C
        tq('sum by (key) (' + lj('minio_bucket_usage_deletemarker_total') + ')'),  // D
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: [
          'key',
          'cluster',
          'namespace',
          'bucket',
          'Value #A',
          'Value #B',
          'Value #C',
          'Value #D',
        ] } } },
        { id: 'seriesToColumns', options: { byField: 'key' } },
        { id: 'organize', options: {
          excludeByName: { key: true },
          indexByName: { cluster: 0, namespace: 1, bucket: 2, 'Value #A': 3, 'Value #B': 4, 'Value #C': 5, 'Value #D': 6, key: 7 },
          renameByName: {
            cluster: 'Cluster',
            namespace: 'Namespace',
            bucket: 'Bucket',
            'Value #A': 'Size',
            'Value #B': 'Objects',
            'Value #C': 'Versions',
            'Value #D': 'Delete markers',
          },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Size', desc: true }] } },
      ])
      + panel.table.withOverrides([
        ov('^Size$', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 120 }]),
        ov('^Objects$|^Versions$|^Delete markers$', [{ id: 'custom.width', value: 130 }]),
      ]);

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 3,
        height: 5,
        elements: {
          a_unhealthy: signals.unhealthy.asStat('Unhealthy'),
          b_nodesOnline: signals.nodesOnline.asStat('Nodes online'),
          c_nodesOffline: signals.nodesOffline.asStat('Nodes offline'),
          d_drivesOnline: signals.drivesOnline.asStat('Drives online'),
          e_drivesOffline: signals.drivesOffline.asStat('Drives offline'),
          f_capacityUsed: signals.capacityUsed.asStat('Capacity used'),
          g_dataStored: signals.dataStored.asStat('Data stored'),
          h_objects: signals.objects.asStat('Objects'),
        },
      },
      {
        title: 'Capacity',
        width: 12,
        height: 7,
        elements: {
          a_usable: signals.usableUsed.asTimeSeries('Usable capacity used')
                    + panel.withTargetsMixin([signals.usableTotal.asTarget()]),
          b_usage: signals.usageByNs.asTimeSeries('Data stored'),
        },
      },
      { title: 'Buckets', width: 24, height: 9, elements: { bucketsTable: bucketsTable } },
      {
        title: 'Bucket activity',
        width: 12,
        height: 7,
        elements: {
          a_size: signals.bucketBytes.asTimeSeries('Bucket size'),
          b_objects: signals.bucketObjects.asTimeSeries('Bucket objects'),
          c_requests: signals.bucketRequests.asTimeSeries('Bucket requests'),
          d_traffic: signals.bucketRx.asTimeSeries('Bucket traffic')
                     + panel.withTargetsMixin([signals.bucketTx.asTarget()]),
        },
      },
      {
        title: 'S3 API',
        width: 12,
        height: 7,
        elements: {
          a_requests: signals.s3Requests.asTimeSeries('Requests by API'),
          b_errors: signals.s3Errors5xx.asTimeSeries('Errors by API')
                    + panel.withTargetsMixin([signals.s3Errors4xx.asTarget()]),
          c_ttfb: signals.ttfbP99.asTimeSeries('Time to first byte (p99)'),
          d_traffic: signals.s3Rx.asTimeSeries('S3 traffic')
                     + panel.withTargetsMixin([signals.s3Tx.asTarget()]),
          e_inflight: signals.s3Inflight.asTimeSeries('Requests in flight / waiting')
                      + panel.withTargetsMixin([signals.s3Waiting.asTarget()]),
          f_rejected: signals.s3RejectedAuth.asTimeSeries('Rejected (auth)'),
        },
      },
      {
        title: 'Drives',
        width: 12,
        height: 7,
        elements: {
          a_used: signals.driveUsed.asTimeSeries('Drive used'),
          b_latency: signals.driveLatency.asTimeSeries('Drive latency by storage API'),
          c_errors: signals.driveErrors.asTimeSeries('Drive errors'),
          d_inodes: signals.driveFreeInodes.asTimeSeries('Free inodes'),
        },
      },
      {
        title: 'Process',
        width: 12,
        height: 7,
        elements: {
          a_memory: signals.memory.asTimeSeries('Resident memory'),
          b_cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          c_fds: signals.fds.asTimeSeries('File descriptors used'),
          d_goroutines: signals.goroutines.asTimeSeries('Goroutines'),
        },
      },
    ], [
      alert.rule.group('minio', [
        alert.rule.new(
          'MinioDown',
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('minio_cluster_health_status', cfg.ruleSelector),
          '5m',
          'critical',
          {},
          { summary: 'MinIO metrics endpoint {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'MinioClusterUnhealthy',
          'minio_cluster_health_status' + rs + ' == 0',
          '5m',
          'critical',
          {},
          {
            summary: 'MinIO cluster is unhealthy.',
            description: 'MinIO in {{ $labels.cluster }}/{{ $labels.namespace }} reports an unhealthy cluster (write quorum lost or erasure sets degraded).',
          }
        ),
        alert.rule.new(
          'MinioNodesOffline',
          'minio_cluster_nodes_offline_total' + rs + ' > 0',
          '5m',
          'critical',
          {},
          {
            summary: 'MinIO nodes are offline.',
            description: '{{ $value }} MinIO node(s) in {{ $labels.cluster }}/{{ $labels.namespace }} are offline.',
          }
        ),
        alert.rule.new(
          'MinioDrivesOffline',
          'minio_cluster_drive_offline_total' + rs + ' > 0',
          '5m',
          'critical',
          {},
          {
            summary: 'MinIO drives are offline.',
            description: '{{ $value }} MinIO drive(s) in {{ $labels.cluster }}/{{ $labels.namespace }} are offline.',
          }
        ),
        alert.rule.new(
          'MinioCapacityHigh',
          '1 - minio_cluster_capacity_usable_free_bytes' + rs + ' / minio_cluster_capacity_usable_total_bytes' + rs + ' > ' + cfg.capacityWarning,
          '15m',
          'warning',
          {},
          {
            summary: 'MinIO usable capacity is running out.',
            description: 'MinIO in {{ $labels.cluster }}/{{ $labels.namespace }} has used {{ $value | humanizePercentage }} of its usable capacity.',
          }
        ),
        alert.rule.new(
          'MinioCapacityCritical',
          '1 - minio_cluster_capacity_usable_free_bytes' + rs + ' / minio_cluster_capacity_usable_total_bytes' + rs + ' > ' + cfg.capacityCritical,
          '15m',
          'critical',
          {},
          {
            summary: 'MinIO usable capacity is nearly exhausted.',
            description: 'MinIO in {{ $labels.cluster }}/{{ $labels.namespace }} has used {{ $value | humanizePercentage }} of its usable capacity.',
          }
        ),
        alert.rule.new(
          'MinioS3ServerErrors',
          '(sum by (cluster, namespace) (rate(minio_s3_requests_errors_total' + rs + '[5m])) - sum by (cluster, namespace) (rate(minio_s3_requests_4xx_errors_total' + rs + '[5m]))) / sum by (cluster, namespace) (rate(minio_s3_requests_total' + rs + '[5m])) > ' + cfg.serverErrorRatio,
          '15m',
          'warning',
          {},
          {
            summary: 'MinIO is answering S3 requests with server errors.',
            description: '{{ $value | humanizePercentage }} of S3 requests to MinIO in {{ $labels.cluster }}/{{ $labels.namespace }} fail with 5xx.',
          }
        ),
      ]),
    ]),
}
