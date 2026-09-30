// observ-viz Envoy pack (hand-written).
// Envoy's own statistics as the admin endpoint exports them
// (/stats/prometheus, envoy_* with the well-known tags turned into labels:
// envoy_http_conn_manager_prefix, envoy_cluster_name, envoy_response_code_class,
// envoy_listener_address). Works for a standalone Envoy, Envoy Gateway, Contour
// and an Istio sidecar/gateway (:15090/stats/prometheus) alike.
//
//   g.libs.networking.envoy.new({}).grafana.dashboard
//
// Durations (downstream_rq_time, upstream_rq_time) are histograms in
// milliseconds. Envoy counts the admin listener's own traffic - the scrape
// itself - under the `admin` connection manager; `hcmFilter` leaves it out.
local dashboard = import 'custom/dashboard.libsonnet';
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-envoy',
      dashboardTitle: 'Envoy',
      dashboardTags: ['envoy', 'ingress', 'proxy', 'cluster-level'],
      description: 'Envoy from its admin statistics: downstream traffic per HTTP connection manager and listener, upstream clusters (requests, 5xx, latency, connections, retries, timeouts), cluster membership health and the server itself.',
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      references: [
        { title: 'Envoy statistics', url: 'https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/statistics', description: 'server stats (live, uptime, memory)' },
        { title: 'HTTP connection manager stats', url: 'https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/stats', description: 'downstream_rq_* / downstream_cx_*' },
        { title: 'Cluster manager stats', url: 'https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cluster_stats', description: 'upstream_rq_* / upstream_cx_* / membership_*' },
      ],
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal cannot reach another component's instances where the
      // job label does not discriminate them
      selector: 'cluster=~"$cluster", job=~"$job", instance=~"$instance"',
      varLabels: ['cluster', 'instance'],
      varMetric: 'envoy_server_live',
      // leaves the admin listener (the scrape itself) out of downstream traffic
      hcmFilter: 'envoy_http_conn_manager_prefix!="admin"',
      // firing-alert annotations: the rules aggregate by cluster/job
      alertSelector: 'cluster=~"$cluster", job=~"$job"',
      // static label filter for the alerting/recording rules (no dashboard vars)
      ruleSelector: '',
      // `up` has no envoy_* name to find Envoy by, so the down alert needs the job
      upJobMatcher: 'job=~".*envoy.*"',
      errorRatio: 0.05,
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table
      overviewSignals: ['live', 'requests', 'errorRatio', 'p95', 'activeConnections', 'uptime'],
      folderPath: (import 'libs/common-lib/folders.libsonnet').ingress,
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local hcmComma = if cfg.hcmFilter != '' then ', ' + cfg.hcmFilter else '';
    // rule matchers: the non-empty ones of the given list, in braces
    local rm(ms) = local f = std.filter(function(x) x != '', ms); if std.length(f) > 0 then '{' + std.join(', ', f) + '}' else '';
    local sig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local q(metric, extra='') = metric + '{%(queriesSelector)s' + extra + '}';
    local rate(metric, extra='') = 'rate(' + q(metric, extra) + '[$__rate_interval])';
    local quantile(qq, bucket, by, extra='') = 'histogram_quantile(' + qq + ', sum by (le, ' + by + ') (' + rate(bucket, extra) + '))';
    local dsRatio(by) =
      'sum by (' + by + ') (' + rate('envoy_http_downstream_rq_xx', hcmComma + ', envoy_response_code_class="5"') + ')'
      + ' / clamp_min(sum by (' + by + ') (' + rate('envoy_http_downstream_rq_total', hcmComma) + '), 1e-9)';
    local usRatio(by) =
      'sum by (' + by + ') (' + rate('envoy_cluster_upstream_rq_xx', ', envoy_response_code_class="5"') + ')'
      + ' / clamp_min(sum by (' + by + ') (' + rate('envoy_cluster_upstream_rq_total') + '), 1e-9)';

    local signals = {
      // ---- overview (per instance)
      live: sig('Live', 'min by (instance) (' + q('envoy_server_live') + ')', 'short', '{{instance}}',
                '1 while the server is serving; 0 while it drains (shutdown, hot restart, drain_listeners).'),
      requests: sig('Downstream requests', 'sum by (instance) (' + rate('envoy_http_downstream_rq_total', hcmComma) + ')', 'reqps', '{{instance}}',
                    'Requests per second clients sent through the HTTP connection managers.'),
      errorRatio: sig('Downstream 5xx ratio', dsRatio('instance'), 'percentunit', '{{instance}}',
                      'Share of downstream requests answered with a 5xx - an upstream error, or Envoy\'s own 503 (no healthy upstream, overflow).'),
      p95: sig('Downstream latency p95', quantile('0.95', 'envoy_http_downstream_rq_time_bucket', 'instance', hcmComma), 'ms', '{{instance}}',
               'Slowest 5 percent of requests, request start to response end.'),
      activeConnections: sig('Downstream connections', 'sum by (instance) (' + q('envoy_http_downstream_cx_active', hcmComma) + ')', 'short', '{{instance}}',
                             'Client connections open on the HTTP connection managers.'),
      uptime: sig('Uptime', 'max by (instance) (' + q('envoy_server_uptime') + ')', 's', '{{instance}}',
                  'Seconds since this Envoy process started.'),
      // ---- downstream
      dsByHcm: sig('Requests by connection manager', 'sum by (envoy_http_conn_manager_prefix) (' + rate('envoy_http_downstream_rq_total', hcmComma) + ')', 'reqps', '{{envoy_http_conn_manager_prefix}}',
                   'Downstream requests per second by HTTP connection manager (its stat_prefix).'),
      dsByClass: sig('Responses by class', 'sum by (envoy_response_code_class) (' + rate('envoy_http_downstream_rq_xx', hcmComma) + ')', 'reqps', '{{envoy_response_code_class}}xx',
                     'Downstream responses per second by status class.'),
      dsErrorRatio: sig('5xx ratio by connection manager', dsRatio('envoy_http_conn_manager_prefix'), 'percentunit', '{{envoy_http_conn_manager_prefix}}',
                        'Share of each connection manager\'s responses that are 5xx.'),
      dsP95: sig('Downstream p95 by connection manager', quantile('0.95', 'envoy_http_downstream_rq_time_bucket', 'envoy_http_conn_manager_prefix', hcmComma), 'ms', 'p95 {{envoy_http_conn_manager_prefix}}',
                 'Slowest 5 percent of requests per connection manager.'),
      dsP99: sig('Downstream p99 by connection manager', quantile('0.99', 'envoy_http_downstream_rq_time_bucket', 'envoy_http_conn_manager_prefix', hcmComma), 'ms', 'p99 {{envoy_http_conn_manager_prefix}}',
                 'Slowest 1 percent of requests per connection manager.'),
      dsActiveRq: sig('Active requests', 'sum by (envoy_http_conn_manager_prefix) (' + q('envoy_http_downstream_rq_active', hcmComma) + ')', 'short', '{{envoy_http_conn_manager_prefix}}',
                      'Requests in flight per connection manager.'),
      listenerCx: sig('Listener connections', 'sum by (envoy_listener_address) (' + q('envoy_listener_downstream_cx_active') + ')', 'short', '{{envoy_listener_address}}',
                      'Active downstream connections per listener address (HTTP and TCP proxies).'),
      // ---- upstream clusters
      usRequests: sig('Upstream requests', 'topk(10, sum by (envoy_cluster_name) (' + rate('envoy_cluster_upstream_rq_total') + '))', 'reqps', '{{envoy_cluster_name}}',
                      'Requests per second to the ten busiest upstream clusters.'),
      usErrorRatio: sig('Upstream 5xx ratio', 'topk(10, ' + usRatio('envoy_cluster_name') + ')', 'percentunit', '{{envoy_cluster_name}}',
                        'Share of each cluster\'s requests answered with a 5xx - the ten worst.'),
      usP95: sig('Upstream latency p95', 'topk(10, ' + quantile('0.95', 'envoy_cluster_upstream_rq_time_bucket', 'envoy_cluster_name') + ')', 'ms', '{{envoy_cluster_name}}',
                 'Slowest 5 percent of upstream requests per cluster, the ten slowest clusters.'),
      usCxActive: sig('Upstream connections', 'topk(10, sum by (envoy_cluster_name) (' + q('envoy_cluster_upstream_cx_active') + '))', 'short', '{{envoy_cluster_name}}',
                      'Open connections to each upstream cluster.'),
      usConnectFail: sig('Connect failures', 'sum by (envoy_cluster_name) (' + rate('envoy_cluster_upstream_cx_connect_fail') + ') > 0', 'ops', '{{envoy_cluster_name}}',
                         'Failed connection attempts per second to upstream hosts.'),
      usTimeouts: sig('Request timeouts', 'sum by (envoy_cluster_name) (' + rate('envoy_cluster_upstream_rq_timeout') + ') > 0', 'ops', '{{envoy_cluster_name}}',
                      'Upstream requests per second that timed out waiting for a response.'),
      usRetries: sig('Retries', 'sum by (envoy_cluster_name) (' + rate('envoy_cluster_upstream_rq_retry') + ') > 0', 'ops', '{{envoy_cluster_name}}',
                     'Upstream request retries per second.'),
      // ---- health
      membersHealthy: sig('Healthy members', 'sum(' + q('envoy_cluster_membership_healthy') + ')', 'short', 'healthy',
                          'Upstream hosts that pass health checks and outlier detection, all clusters.'),
      membersUnhealthy: sig('Unhealthy members', 'sum(' + q('envoy_cluster_membership_total') + ') - sum(' + q('envoy_cluster_membership_healthy') + ')', 'short', 'unhealthy',
                            'Upstream hosts that are members of a cluster but not healthy.'),
      clustersNoHealthy: sig('Clusters without healthy members', 'count(max by (envoy_cluster_name) (' + q('envoy_cluster_membership_total') + ') > 0 and max by (envoy_cluster_name) (' + q('envoy_cluster_membership_healthy') + ') == 0) or vector(0)', 'short', 'clusters',
                             'Clusters that have members but none healthy: every request to them is a 503.'),
      healthyRatio: sig('Healthy ratio by cluster', 'bottomk(10, max by (envoy_cluster_name) (' + q('envoy_cluster_membership_healthy') + ') / max by (envoy_cluster_name) (' + q('envoy_cluster_membership_total') + ' > 0))', 'percentunit', '{{envoy_cluster_name}}',
                      'Share of each cluster\'s members that are healthy - the ten lowest.'),
      membershipTable: sig('Cluster membership', 'max by (envoy_cluster_name) (' + q('envoy_cluster_membership_total') + ') - max by (envoy_cluster_name) (' + q('envoy_cluster_membership_healthy') + ')', 'short', '{{envoy_cluster_name}}',
                           'Unhealthy members per cluster (members minus healthy).'),
      // ---- server
      memoryAllocated: sig('Memory allocated', 'max by (instance) (' + q('envoy_server_memory_allocated') + ')', 'bytes', 'allocated {{instance}}',
                           'Memory the allocator has handed out.'),
      memoryHeap: sig('Heap size', 'max by (instance) (' + q('envoy_server_memory_heap_size') + ')', 'bytes', 'heap {{instance}}',
                      'Heap the allocator has reserved from the OS.'),
      totalConnections: sig('Total connections', 'max by (instance) (' + q('envoy_server_total_connections') + ')', 'short', '{{instance}}',
                            'Connections across the current and draining process.'),
      concurrency: sig('Worker threads', 'max by (instance) (' + q('envoy_server_concurrency') + ')', 'short', '{{instance}}',
                       'Worker threads (--concurrency).'),
      certExpiryDays: sig('Days until first cert expires', 'min by (instance) (' + q('envoy_server_days_until_first_cert_expiring') + ')', 'd', '{{instance}}',
                          'Days until the first certificate Envoy has loaded expires.'),
    };
    local liveMap = panel.stat.withMappings([{ type: 'value', options: { '0': { text: 'draining', color: 'red', index: 0 }, '1': { text: 'live', color: 'green', index: 1 } } }]);

    local annList =
      annotations.alert.bySeverity(cfg.datasource, cfg.alertSelector)
      + [
        // start time from uptime, as the sample saw it (rounded so the scrape
        // jitter does not split one start into many markers)
        annotations.restart.newAt('Envoy starts', annotations.base.target(cfg.datasource, '1000 * round(max by (cluster, job, instance) (timestamp(envoy_server_uptime{' + cfg.selector + '}) - envoy_server_uptime{' + cfg.selector + '}), 10)'), ['job', 'instance'], '{{instance}} started')
        + annotations.base.asToggle(false),
      ];

    local built = pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          ov1_live: signals.live.asStat('Live') + liveMap,
          ov2_requests: signals.requests.asStat('Requests/s'),
          ov3_errorRatio: signals.errorRatio.asStat('5xx ratio')
                          + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: cfg.errorRatio }]),
          ov4_p95: signals.p95.asStat('Latency p95'),
          ov5_activeConnections: signals.activeConnections.asStat('Connections'),
          ov6_clustersNoHealthy: signals.clustersNoHealthy.asStat('Clusters w/o healthy hosts')
                                 + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]),
        },
      },
      {
        title: 'Downstream',
        width: 12,
        height: 7,
        elements: {
          dsByHcm: signals.dsByHcm.asTimeSeries('Requests/s by connection manager'),
          dsByClass: signals.dsByClass.asTimeSeries('Responses/s by class'),
          dsErrorRatio: signals.dsErrorRatio.asTimeSeries('5xx ratio by connection manager')
                        + panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'red', value: cfg.errorRatio }])
                        + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } }),
          dsLatency: signals.dsP95.asTimeSeries('Downstream latency p95 / p99')
                     + panel.withTargetsMixin([signals.dsP99.asTarget()]),
          dsActiveRq: signals.dsActiveRq.asTimeSeries('Active requests'),
          listenerCx: signals.listenerCx.asTimeSeries('Listener connections'),
        },
      },
      {
        title: 'Upstream clusters',
        width: 12,
        height: 7,
        elements: {
          usRequests: signals.usRequests.asTimeSeries('Requests/s by cluster'),
          usErrorRatio: signals.usErrorRatio.asTimeSeries('5xx ratio by cluster'),
          usP95: signals.usP95.asTimeSeries('Upstream latency p95'),
          usCxActive: signals.usCxActive.asTimeSeries('Upstream connections'),
          usConnectFail: signals.usConnectFail.asTimeSeries('Connect failures/s'),
          usTimeouts: signals.usTimeouts.asTimeSeries('Timeouts/s'),
          usRetries: signals.usRetries.asTimeSeries('Retries/s'),
        },
      },
      {
        title: 'Health',
        width: 12,
        height: 7,
        elements: {
          membersHealthy: signals.membersHealthy.asStat('Healthy members'),
          membersUnhealthy: signals.membersUnhealthy.asStat('Unhealthy members')
                            + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 1 }]),
          healthyRatio: signals.healthyRatio.asTimeSeries('Healthy ratio by cluster (lowest 10)'),
          membershipTable: signals.membershipTable.asTable('Unhealthy members by cluster'),
        },
      },
      {
        title: 'Server',
        width: 12,
        height: 7,
        elements: {
          memory: signals.memoryAllocated.asTimeSeries('Memory allocated / heap')
                  + panel.withTargetsMixin([signals.memoryHeap.asTarget()]),
          uptime: signals.uptime.asTimeSeries('Uptime'),
          totalConnections: signals.totalConnections.asTimeSeries('Total connections'),
          concurrency: signals.concurrency.asTimeSeries('Worker threads'),
          certExpiryDays: signals.certExpiryDays.asTimeSeries('Days until first cert expires'),
        },
      },
    ], [
      alert.rule.group('envoy', [
        alert.rule.new(
          'EnvoyHigh5xxRatio',
          'sum by (cluster, job, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_xx' + rm(['envoy_response_code_class="5"', cfg.hcmFilter, cfg.ruleSelector]) + '[5m]))'
          + ' / clamp_min(sum by (cluster, job, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_total' + rm([cfg.hcmFilter, cfg.ruleSelector]) + '[5m])), 1e-9) > ' + cfg.errorRatio,
          '10m',
          'warning',
          {},
          {
            summary: 'Envoy answers more than ' + (cfg.errorRatio * 100) + '% of requests on {{ $labels.envoy_http_conn_manager_prefix }} with a 5xx.',
            description: 'Downstream 5xx include upstream errors and Envoy\'s own 503s (no healthy upstream, circuit breaker overflow). The Upstream clusters and Health tabs tell which it is.',
          }
        ),
        alert.rule.new(
          'EnvoyUpstreamClusterUnhealthyMembers',
          'max by (cluster, job, envoy_cluster_name) (envoy_cluster_membership_total' + rsBrace + ') - max by (cluster, job, envoy_cluster_name) (envoy_cluster_membership_healthy' + rsBrace + ') > 0',
          '15m',
          'warning',
          {},
          {
            summary: 'Envoy cluster {{ $labels.envoy_cluster_name }} has {{ $value }} unhealthy members.',
            description: 'Health checks or outlier detection took hosts of the cluster out of rotation; the rest carry the load.',
          }
        ),
        alert.rule.new(
          'EnvoyUpstreamClusterNoHealthyMembers',
          'max by (cluster, job, envoy_cluster_name) (envoy_cluster_membership_total' + rsBrace + ') > 0 and max by (cluster, job, envoy_cluster_name) (envoy_cluster_membership_healthy' + rsBrace + ') == 0',
          '5m',
          'critical',
          {},
          {
            summary: 'Envoy cluster {{ $labels.envoy_cluster_name }} has no healthy members.',
            description: 'Every request routed to this cluster is answered with 503 no healthy upstream.',
          }
        ),
        alert.rule.new(
          'EnvoyDown',
          'min by (cluster, job, instance) (envoy_server_live' + rsBrace + ') == 0 or min by (cluster, job, instance) (up' + rm([cfg.upJobMatcher, cfg.ruleSelector]) + ') == 0',
          '5m',
          'critical',
          {},
          {
            summary: 'Envoy {{ $labels.instance }} is down or draining.',
            description: 'Either the admin endpoint cannot be scraped (up == 0) or the server reports it is not live (draining listeners, shutting down).',
          }
        ),
      ]),
    ], [
      alert.rule.group('envoy.rules', [
        alert.rule.record('job:envoy_http_downstream_rq:rate5m', 'sum by (cluster, job, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_total' + rm([cfg.hcmFilter, cfg.ruleSelector]) + '[5m]))'),
        alert.rule.record('job:envoy_http_downstream_rq_5xx:ratio_rate5m',
                          'sum by (cluster, job, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_xx' + rm(['envoy_response_code_class="5"', cfg.hcmFilter, cfg.ruleSelector]) + '[5m]))'
                          + ' / sum by (cluster, job, envoy_http_conn_manager_prefix) (rate(envoy_http_downstream_rq_total' + rm([cfg.hcmFilter, cfg.ruleSelector]) + '[5m]))'),
        alert.rule.record('job:envoy_cluster_upstream_rq_time:p95_5m',
                          'histogram_quantile(0.95, sum by (le, cluster, job, envoy_cluster_name) (rate(envoy_cluster_upstream_rq_time_bucket' + rsBrace + '[5m])))'),
      ]),
    ]);
    built {
      grafana+: { dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList) },
    },
}
