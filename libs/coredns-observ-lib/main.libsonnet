// observ-viz CoreDNS pack (hand-written).
// Built for CoreDNS's Prometheus plugin (coredns_*), as the k8s-monitoring
// integration scrapes the cluster DNS (job integrations/kubernetes/kube-dns).
// Alerts ported from the service catalog's coredns-mixin (the upstream
// coredns-mixin set), keeping the ones whose series CoreDNS exports here: the
// forward-latency / forward-error alerts need coredns_forward_requests_* which
// this deployment does not expose.
// Usage:
//   g.libs.kubernetes.coredns.new({ selector: 'job=~".*kube-dns.*"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-coredns',
      dashboardTitle: 'CoreDNS',
      // Platform / Kubernetes
      folderPath: (import 'libs/common-lib/folders.libsonnet').kubernetes,
      dashboardTags: ['coredns', 'dns', 'kubernetes', 'app-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      selector: 'job=~"$job", cluster=~"$cluster", pod=~"$pod"',
      varMetric: 'coredns_build_info',
      varLabels: ['cluster', 'pod'],
      ruleSelector: '',
      latencyCriticalSeconds: 4,
      errorsWarningRatio: 0.01,
      errorsCriticalRatio: 0.03,
    } + config;

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, legend='{{pod}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      // overview
      pods: sig('Pods', 'count(coredns_build_info{%(queriesSelector)s})', 'short', 'pods'),
      rps: sig('Requests', 'sum(rate(coredns_dns_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'requests'),
      servfailRatio: sig('SERVFAIL', 'sum(rate(coredns_dns_responses_total{rcode="SERVFAIL", %(queriesSelector)s}[$__rate_interval])) / sum(rate(coredns_dns_responses_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', 'SERVFAIL'),
      nxdomainRatio: sig('NXDOMAIN', 'sum(rate(coredns_dns_responses_total{rcode="NXDOMAIN", %(queriesSelector)s}[$__rate_interval])) / sum(rate(coredns_dns_responses_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', 'NXDOMAIN'),
      p99: sig('Latency p99', 'histogram_quantile(0.99, sum by (le) (rate(coredns_dns_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99'),
      cacheHitRatio: sig('Cache hit ratio', 'sum(rate(coredns_cache_hits_total{%(queriesSelector)s}[$__rate_interval])) / sum(rate(coredns_cache_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'percentunit', 'hit ratio'),
      // requests
      requestsByType: sig('Requests by type', 'sum by (type) (rate(coredns_dns_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{type}}'),
      requestsByProto: sig('Requests by protocol', 'sum by (proto) (rate(coredns_dns_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{proto}}'),
      requestsByZone: sig('Requests by zone', 'sum by (zone) (rate(coredns_dns_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{zone}}'),
      requestsByPod: sig('Requests by pod', 'sum by (pod) (rate(coredns_dns_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps'),
      // responses
      responsesByRcode: sig('Responses by rcode', 'sum by (rcode) (rate(coredns_dns_responses_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{rcode}}'),
      latencyP50: sig('Latency p50', 'histogram_quantile(0.50, sum by (le) (rate(coredns_dns_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p50'),
      latencyP90: sig('Latency p90', 'histogram_quantile(0.90, sum by (le) (rate(coredns_dns_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p90'),
      latencyP99: sig('Latency p99', 'histogram_quantile(0.99, sum by (le) (rate(coredns_dns_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99'),
      responseSize: sig('Response size p90', 'histogram_quantile(0.90, sum by (le, proto) (rate(coredns_dns_response_size_bytes_bucket{%(queriesSelector)s}[$__rate_interval])))', 'bytes', '{{proto}}'),
      // cache
      cacheHits: sig('Cache hits', 'sum by (type) (rate(coredns_cache_hits_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'hits {{type}}'),
      cacheMisses: sig('Cache misses', 'sum(rate(coredns_cache_misses_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'misses'),
      cacheEntries: sig('Cache entries', 'sum by (type) (coredns_cache_entries{%(queriesSelector)s})', 'short', '{{type}}'),
      // health of the server itself
      forwardBroken: sig('Forward healthcheck broken', 'sum by (pod) (increase(coredns_forward_healthcheck_broken_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      maxConcurrentRejects: sig('Forward max-concurrent rejects', 'sum by (pod) (rate(coredns_forward_max_concurrent_rejects_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      panics: sig('Panics', 'sum by (pod) (increase(coredns_panics_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      reloadFailed: sig('Reload failures', 'sum by (pod) (increase(coredns_reload_failed_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      healthLatency: sig('Health check latency p99', 'histogram_quantile(0.99, sum by (le, pod) (rate(coredns_health_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's'),
      programming: sig('DNS programming latency p99', 'histogram_quantile(0.99, sum by (le) (rate(coredns_kubernetes_dns_programming_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'service change → DNS'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 5,
        elements: {
          a_pods: signals.pods.asStat('Pods'),
          b_rps: signals.rps.asStat('Requests'),
          c_servfail: signals.servfailRatio.asStat('SERVFAIL ratio'),
          d_nxdomain: signals.nxdomainRatio.asStat('NXDOMAIN ratio'),
          e_p99: signals.p99.asStat('Latency p99'),
          f_cache: signals.cacheHitRatio.asStat('Cache hit ratio'),
        },
      },
      {
        title: 'Requests',
        width: 12,
        height: 7,
        elements: {
          a_type: signals.requestsByType.asTimeSeries('Requests by record type'),
          b_zone: signals.requestsByZone.asTimeSeries('Requests by zone'),
          c_proto: signals.requestsByProto.asTimeSeries('Requests by protocol'),
          d_pod: signals.requestsByPod.asTimeSeries('Requests by pod'),
        },
      },
      {
        title: 'Responses',
        width: 12,
        height: 7,
        elements: {
          a_rcode: signals.responsesByRcode.asTimeSeries('Responses by rcode'),
          b_latency: signals.latencyP50.asTimeSeries('Latency')
                     + panel.withTargetsMixin([signals.latencyP90.asTarget(), signals.latencyP99.asTarget()]),
          c_size: signals.responseSize.asTimeSeries('Response size (p90)'),
        },
      },
      {
        title: 'Cache',
        width: 8,
        height: 7,
        elements: {
          a_hits: signals.cacheHits.asTimeSeries('Cache hits / misses')
                  + panel.withTargetsMixin([signals.cacheMisses.asTarget()]),
          b_ratio: signals.cacheHitRatio.asTimeSeries('Cache hit ratio'),
          c_entries: signals.cacheEntries.asTimeSeries('Cache entries'),
        },
      },
      {
        title: 'Server health',
        width: 8,
        height: 7,
        elements: {
          a_forward: signals.forwardBroken.asTimeSeries('Forward healthcheck broken')
                     + panel.withTargetsMixin([signals.maxConcurrentRejects.asTarget()]),
          b_panics: signals.panics.asTimeSeries('Panics / reload failures')
                    + panel.withTargetsMixin([signals.reloadFailed.asTarget()]),
          c_health: signals.healthLatency.asTimeSeries('Health check latency (p99)'),
          d_programming: signals.programming.asTimeSeries('DNS programming latency (p99)'),
        },
      },
    ], [
      alert.rule.group('coredns', [
        alert.rule.new(
          'CoreDNSDown',
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('coredns_build_info', cfg.ruleSelector),
          '15m',
          'critical',
          {},
          { summary: 'CoreDNS has disappeared from Prometheus target discovery.', description: 'CoreDNS {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'CoreDNSLatencyHigh',
          'histogram_quantile(0.99, sum without (instance, pod) (rate(coredns_dns_request_duration_seconds_bucket' + rs + '[5m]))) > ' + cfg.latencyCriticalSeconds,
          '10m',
          'critical',
          {},
          { summary: 'CoreDNS is experiencing high latency.', description: 'CoreDNS has 99th percentile latency of {{ $value }} seconds for server {{ $labels.server }} zone {{ $labels.zone }}.' }
        ),
        alert.rule.new(
          'CoreDNSErrorsHigh',
          'sum without (pod, instance, server, zone, view, rcode, plugin) (rate(coredns_dns_responses_total{rcode="SERVFAIL"' + rsComma + '}[5m])) / sum without (pod, instance, server, zone, view, rcode, plugin) (rate(coredns_dns_responses_total' + rs + '[5m])) > ' + cfg.errorsCriticalRatio,
          '10m',
          'critical',
          {},
          { summary: 'CoreDNS is returning SERVFAIL.', description: 'CoreDNS is returning SERVFAIL for {{ $value | humanizePercentage }} of requests.' }
        ),
        alert.rule.new(
          'CoreDNSErrorsElevated',
          'sum without (pod, instance, server, zone, view, rcode, plugin) (rate(coredns_dns_responses_total{rcode="SERVFAIL"' + rsComma + '}[5m])) / sum without (pod, instance, server, zone, view, rcode, plugin) (rate(coredns_dns_responses_total' + rs + '[5m])) > ' + cfg.errorsWarningRatio,
          '10m',
          'warning',
          {},
          { summary: 'CoreDNS is returning SERVFAIL.', description: 'CoreDNS is returning SERVFAIL for {{ $value | humanizePercentage }} of requests.' }
        ),
        alert.rule.new(
          'CoreDNSForwardHealthcheckBrokenCount',
          'sum without (pod, instance) (rate(coredns_forward_healthcheck_broken_total' + rs + '[5m])) > 0',
          '10m',
          'warning',
          {},
          { summary: 'CoreDNS health checks have failed for all upstream servers.', description: '{{ $value }} health checks have failed for all upstream servers.' }
        ),
      ]),
    ]),
}
