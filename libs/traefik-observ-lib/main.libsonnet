// observ-viz Traefik pack (hand-written).
// Traefik v3's Prometheus metrics (traefik_*): entrypoints, routers, services
// and their backend servers, open connections, TLS certificates and config
// reloads. Router metrics need `metrics.prometheus.addRoutersLabels=true`;
// entrypoint and service metrics are on by default.
//
//   g.libs.networking.traefik.new({}).grafana.dashboard
//   g.libs.networking.traefik.new({ ruleSelector: 'job="traefik"' }).prometheus.alerts
//
// Traefik v3 dropped traefik_config_reloads_failure_total (the upstream
// grafana traefik-mixin still alerts on it); config health is read from
// traefik_config_last_reload_success instead.
local dashboard = import 'custom/dashboard.libsonnet';
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-traefik',
      dashboardTitle: 'Traefik',
      dashboardTags: ['traefik', 'ingress', 'proxy', 'cluster-level'],
      description: 'Traefik v3 from its own Prometheus metrics: traffic per entrypoint, router and service, 5xx ratio and latency, backend server health, open connections, TLS certificate expiry and configuration reloads.',
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      references: [
        { title: 'Traefik metrics', url: 'https://doc.traefik.io/traefik/reference/install-configuration/observability/metrics/', description: 'the traefik_* metric reference (v3)' },
        { title: 'grafana traefik-mixin', url: 'https://github.com/grafana/jsonnet-libs/tree/master/traefik-mixin', description: 'the upstream alerts these rules follow' },
      ],
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal (process_*, go_*) cannot reach another component's
      // instances where the job label does not discriminate them
      selector: 'cluster=~"$cluster", job=~"$job", instance=~"$instance"',
      varLabels: ['cluster', 'instance'],
      varMetric: 'traefik_config_reloads_total',
      // firing-alert annotations: the rules aggregate by cluster/job, so the
      // ALERTS series carry no instance
      alertSelector: 'cluster=~"$cluster", job=~"$job"',
      // static label filter for the alerting/recording rules (no dashboard vars)
      ruleSelector: '',
      errorRatioPercent: 5,
      tlsExpiryDaysCritical: 7,
      tlsExpiryDaysWarning: 14,
      serverDownFor: '5m',
      docTabs: true,
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      // columns of the Overview tab's instances table
      overviewSignals: ['requests', 'errorRatio', 'p95', 'openConnections', 'configReloadOk'],
      folderPath: (import 'libs/common-lib/folders.libsonnet').ingress,
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local q(metric, extra='') = metric + '{%(queriesSelector)s' + extra + '}';
    local rate(metric, extra='') = 'rate(' + q(metric, extra) + '[$__rate_interval])';
    local quantile(qq, bucket, by) = 'histogram_quantile(' + qq + ', sum by (le, ' + by + ') (' + rate(bucket) + '))';
    local ratio5xx(metric, by) =
      'sum by (' + by + ') (' + rate(metric, ', code=~"5.."') + ') / clamp_min(sum by (' + by + ') (' + rate(metric) + '), 1e-9)';

    local signals = {
      // ---- overview (per instance, so the instances table has one row each)
      requests: sig('Requests', 'sum by (instance) (' + rate('traefik_entrypoint_requests_total') + ')', 'reqps', '{{instance}}',
                    'Requests per second arriving on all entrypoints.'),
      errorRatio: sig('5xx ratio', ratio5xx('traefik_entrypoint_requests_total', 'instance'), 'percentunit', '{{instance}}',
                      'Share of entrypoint requests answered with a 5xx, whether Traefik or the backend produced it.'),
      p95: sig('Latency p95', quantile('0.95', 'traefik_entrypoint_request_duration_seconds_bucket', 'instance'), 's', '{{instance}}',
               'Slowest 5 percent of requests, measured at the entrypoint.'),
      openConnections: sig('Open connections', 'sum by (instance) (' + q('traefik_open_connections') + ')', 'short', '{{instance}}',
                           'Connections open right now across all entrypoints.'),
      configReloadOk: sig('Config reload ok', 'min by (instance) (' + q('traefik_config_last_reload_success') + ')', 'short', '{{instance}}',
                          '1 while the last configuration reload succeeded; 0 leaves Traefik routing on the previous configuration.'),
      configReloads: sig('Config reloads', 'sum by (instance) (' + 'increase(' + q('traefik_config_reloads_total') + '[$__rate_interval]))', 'short', '{{instance}}',
                         'Configuration reloads - every change a provider (Kubernetes, file, Docker) pushed.'),
      // ---- entrypoints
      epRequests: sig('Requests by entrypoint', 'sum by (entrypoint) (' + rate('traefik_entrypoint_requests_total') + ')', 'reqps', '{{entrypoint}}',
                      'Requests per second by entrypoint.'),
      epByCode: sig('Requests by status', 'sum by (code) (' + rate('traefik_entrypoint_requests_total') + ')', 'reqps', '{{code}}',
                    'Requests per second by HTTP status code, all entrypoints.'),
      epErrorRatio: sig('5xx ratio by entrypoint', ratio5xx('traefik_entrypoint_requests_total', 'entrypoint'), 'percentunit', '{{entrypoint}}',
                        'Share of requests per entrypoint answered with a 5xx.'),
      epP95: sig('Entrypoint latency p95', quantile('0.95', 'traefik_entrypoint_request_duration_seconds_bucket', 'entrypoint'), 's', '{{entrypoint}}',
                 'Slowest 5 percent of requests per entrypoint.'),
      epP99: sig('Entrypoint latency p99', quantile('0.99', 'traefik_entrypoint_request_duration_seconds_bucket', 'entrypoint'), 's', 'p99 {{entrypoint}}',
                 'Slowest 1 percent of requests per entrypoint.'),
      epConnections: sig('Open connections by entrypoint', 'sum by (entrypoint, protocol) (' + q('traefik_open_connections') + ')', 'short', '{{entrypoint}} / {{protocol}}',
                         'Open connections by entrypoint and protocol (HTTP, TCP, UDP).'),
      epBytesIn: sig('Request bytes', 'sum by (entrypoint) (' + rate('traefik_entrypoint_requests_bytes_total') + ')', 'Bps', 'in {{entrypoint}}',
                     'Request bytes received per second per entrypoint.'),
      epBytesOut: sig('Response bytes', 'sum by (entrypoint) (' + rate('traefik_entrypoint_responses_bytes_total') + ')', 'Bps', 'out {{entrypoint}}',
                      'Response bytes sent per second per entrypoint.'),
      epTls: sig('TLS requests by version', 'sum by (tls_version) (' + rate('traefik_entrypoint_requests_tls_total') + ')', 'reqps', '{{tls_version}}',
                 'TLS requests per second by protocol version; anything below TLS 1.2 is a client worth finding.'),
      // ---- routers (addRoutersLabels)
      routerRequests: sig('Requests by router', 'topk(10, sum by (router) (' + rate('traefik_router_requests_total') + '))', 'reqps', '{{router}}',
                          'The ten busiest routers. Empty unless router metrics are enabled (addRoutersLabels).'),
      routerErrors: sig('5xx by router', 'topk(10, sum by (router) (' + rate('traefik_router_requests_total', ', code=~"5.."') + '))', 'reqps', '{{router}}',
                        'Routers answering with the most server errors per second.'),
      routerP95: sig('Router latency p95', 'topk(10, ' + quantile('0.95', 'traefik_router_request_duration_seconds_bucket', 'router') + ')', 's', '{{router}}',
                     'Slowest 5 percent of requests per router, the ten slowest routers.'),
      routerTable: sig('Routers', 'sum by (router, service, code) (' + rate('traefik_router_requests_total') + ')', 'reqps', '{{router}}',
                       'Router, target service and status breakdown.'),
      // ---- services / backends
      svcRequests: sig('Requests by service', 'topk(10, sum by (service) (' + rate('traefik_service_requests_total') + '))', 'reqps', '{{service}}',
                       'The ten busiest services (backends).'),
      svcErrorRatio: sig('5xx ratio by service', 'topk(10, ' + ratio5xx('traefik_service_requests_total', 'service') + ')', 'percentunit', '{{service}}',
                         'Share of each service\'s requests answered with a 5xx - the ten worst.'),
      svcP95: sig('Service latency p95', 'topk(10, ' + quantile('0.95', 'traefik_service_request_duration_seconds_bucket', 'service') + ')', 's', '{{service}}',
                  'Slowest 5 percent of requests per service, the ten slowest services.'),
      svcRetries: sig('Retries by service', 'sum by (service) (' + rate('traefik_service_retries_total') + ')', 'ops', '{{service}}',
                      'Requests Traefik retried against another server of the service (retry middleware).'),
      serversDown: sig('Servers down', 'count(' + q('traefik_service_server_up') + ' == 0) or vector(0)', 'short', 'down',
                       'Backend servers failing their health check. Only services with a health check configured report this.'),
      serverTable: sig('Backend servers', 'max by (service, url) (' + q('traefik_service_server_up') + ')', 'short', '{{service}} {{url}}',
                       'Every health-checked backend server: 1 up, 0 down.'),
      // ---- TLS certificates
      certExpiry: sig('Certificate expiry', 'min by (cn, sans) (' + q('traefik_tls_certs_not_after') + ') - time()', 'dtdurations', '{{cn}}',
                      'Time until each certificate Traefik serves expires.'),
      certMinExpiry: sig('Soonest expiry', 'min(' + q('traefik_tls_certs_not_after') + ') - time()', 'dtdurations', 'soonest',
                         'Time until the first certificate Traefik serves expires.'),
      certs: sig('Certificates', 'count(count by (cn, sans) (' + q('traefik_tls_certs_not_after') + '))', 'short', 'certificates',
                 'Distinct certificates Traefik has loaded.'),
    };
    local okMap = panel.stat.withMappings([{ type: 'value', options: { '0': { text: 'FAILED', color: 'red', index: 0 }, '1': { text: 'ok', color: 'green', index: 1 } } }]);

    local annList =
      annotations.alert.bySeverity(cfg.datasource, cfg.alertSelector)
      + [
        annotations.restart.newAt('Traefik starts', annotations.restart.processStart(cfg.datasource, cfg.selector), ['job', 'instance'], '{{instance}} started')
        + annotations.base.asToggle(false),
      ];

    local built = pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          ov1_requests: signals.requests.asStat('Requests/s'),
          ov2_errorRatio: signals.errorRatio.asStat('5xx ratio')
                          + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: cfg.errorRatioPercent / 100 }]),
          ov3_p95: signals.p95.asStat('Latency p95'),
          ov4_openConnections: signals.openConnections.asStat('Open connections'),
          ov5_configReloadOk: signals.configReloadOk.asStat('Config reload') + okMap,
          ov6_serversDown: signals.serversDown.asStat('Servers down')
                           + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]),
        },
      },
      {
        title: 'Entrypoints',
        width: 12,
        height: 7,
        elements: {
          epRequests: signals.epRequests.asTimeSeries('Requests/s by entrypoint'),
          epByCode: signals.epByCode.asTimeSeries('Requests/s by status'),
          epErrorRatio: signals.epErrorRatio.asTimeSeries('5xx ratio by entrypoint'),
          epLatency: signals.epP95.asTimeSeries('Entrypoint latency p95 / p99')
                     + panel.withTargetsMixin([signals.epP99.asTarget()]),
          epConnections: signals.epConnections.asTimeSeries('Open connections'),
          epBytes: signals.epBytesIn.asTimeSeries('Bytes in / out')
                   + panel.withTargetsMixin([signals.epBytesOut.asTarget()]),
          epTls: signals.epTls.asTimeSeries('TLS requests by version'),
          configReloads: signals.configReloads.asTimeSeries('Config reloads'),
        },
      },
      {
        title: 'Routers',
        width: 12,
        height: 7,
        elements: {
          routerRequests: signals.routerRequests.asTimeSeries('Requests/s by router'),
          routerErrors: signals.routerErrors.asTimeSeries('5xx/s by router'),
          routerP95: signals.routerP95.asTimeSeries('Router latency p95'),
          routerTable: signals.routerTable.asTable('Routers by service and status'),
        },
      },
      {
        title: 'Services',
        width: 12,
        height: 7,
        elements: {
          svcRequests: signals.svcRequests.asTimeSeries('Requests/s by service'),
          svcErrorRatio: signals.svcErrorRatio.asTimeSeries('5xx ratio by service')
                         + panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'red', value: cfg.errorRatioPercent / 100 }])
                         + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } }),
          svcP95: signals.svcP95.asTimeSeries('Service latency p95'),
          svcRetries: signals.svcRetries.asTimeSeries('Retries/s by service'),
          serverTable: signals.serverTable.asTable('Backend servers (1 up / 0 down)'),
        },
      },
      {
        title: 'TLS certificates',
        width: 12,
        height: 7,
        elements: {
          certMinExpiry: signals.certMinExpiry.asStat('Soonest certificate expiry')
                         + panel.stat.withThresholds([{ color: 'red', value: null }, { color: 'orange', value: cfg.tlsExpiryDaysCritical * 86400 }, { color: 'green', value: cfg.tlsExpiryDaysWarning * 86400 }]),
          certs: signals.certs.asStat('Certificates loaded'),
          certExpiry: signals.certExpiry.asTable('Certificate expiry'),
        },
      },
    ], [
      alert.rule.group('traefik', [
        alert.rule.new(
          'TraefikTLSCertificatesExpiring',
          'min by (cluster, job, cn, sans) ((last_over_time(traefik_tls_certs_not_after' + rsBrace + '[5m]) - time()) / 86400) < ' + cfg.tlsExpiryDaysCritical,
          '5m',
          'critical',
          {},
          {
            summary: 'A Traefik-served TLS certificate will expire very soon.',
            description: 'Certificate {{ $labels.cn }} ({{ $labels.sans }}) served by {{ $labels.job }} expires in {{ printf "%.0f" $value }} days, below ' + cfg.tlsExpiryDaysCritical + '.',
          }
        ),
        alert.rule.new(
          'TraefikTLSCertificatesExpiringSoon',
          'min by (cluster, job, cn, sans) ((last_over_time(traefik_tls_certs_not_after' + rsBrace + '[5m]) - time()) / 86400) < ' + cfg.tlsExpiryDaysWarning + ' > ' + cfg.tlsExpiryDaysCritical,
          '5m',
          'warning',
          {},
          {
            summary: 'A Traefik-served TLS certificate will expire soon.',
            description: 'Certificate {{ $labels.cn }} ({{ $labels.sans }}) served by {{ $labels.job }} expires in {{ printf "%.0f" $value }} days, below ' + cfg.tlsExpiryDaysWarning + '. Renewal (ACME / cert-manager) should have happened by now.',
          }
        ),
        alert.rule.new(
          'TraefikHighHttp5xxErrorRate',
          'sum by (cluster, job, service) (rate(traefik_service_requests_total{code=~"5.."' + rsComma + '}[5m]))'
          + ' / sum by (cluster, job, service) (rate(traefik_service_requests_total' + rsBrace + '[5m])) * 100 > ' + cfg.errorRatioPercent,
          '5m',
          'warning',
          {},
          {
            summary: 'Traefik service is answering with many 5xx errors.',
            description: 'More than ' + cfg.errorRatioPercent + '% of requests to Traefik service {{ $labels.service }} return 5xx.',
          }
        ),
        alert.rule.new(
          'TraefikBackendServerDown',
          'max by (cluster, job, service, url) (traefik_service_server_up' + rsBrace + ') == 0',
          cfg.serverDownFor,
          'warning',
          {},
          {
            summary: 'A Traefik backend server is failing its health check.',
            description: 'Backend {{ $labels.url }} of Traefik service {{ $labels.service }} is reported down.',
          }
        ),
        alert.rule.new(
          'TraefikConfigReloadFailed',
          'min by (cluster, job, instance) (traefik_config_last_reload_success' + rsBrace + ') == 0',
          '10m',
          'warning',
          {},
          {
            summary: 'Traefik failed to apply its last configuration.',
            description: 'Traefik {{ $labels.instance }} rejected its latest configuration and keeps routing on the previous one; new or changed routes are not live.',
          }
        ),
      ]),
    ], [
      alert.rule.group('traefik.rules', [
        alert.rule.record('job:traefik_entrypoint_requests:rate5m', 'sum by (cluster, job, entrypoint) (rate(traefik_entrypoint_requests_total' + rsBrace + '[5m]))'),
        alert.rule.record('job:traefik_service_requests_5xx:ratio_rate5m',
                          'sum by (cluster, job, service) (rate(traefik_service_requests_total{code=~"5.."' + rsComma + '}[5m]))'
                          + ' / sum by (cluster, job, service) (rate(traefik_service_requests_total' + rsBrace + '[5m]))'),
        alert.rule.record('job:traefik_entrypoint_request_duration_seconds:p95_5m',
                          'histogram_quantile(0.95, sum by (le, cluster, job, entrypoint) (rate(traefik_entrypoint_request_duration_seconds_bucket' + rsBrace + '[5m])))'),
      ]),
    ]);
    built {
      grafana+: { dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList) },
    },
}
