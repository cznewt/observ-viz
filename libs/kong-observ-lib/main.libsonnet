// observ-viz Kong pack (hand-written).
// One board for the Kong gateway from either of the two ways it reports:
// the Prometheus plugin (kong_*) or OpenTelemetry HTTP server semantics.
// Pick with `implementation`; the signals are the same either way, and the
// ones an implementation cannot answer are left out rather than left blank.
//
//   g.libs.networking.kong.new({})                              // Prometheus plugin
//   g.libs.networking.kong.new({ implementation: 'opentelemetry' })
//   g.libs.networking.kong.new({ implementation: 'prometheus2' })  // Kong 2.x names
local alert = import 'libs/common-lib/alert/main.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local sources = import 'libs/kong-observ-lib/sources.libsonnet';

{
  // the metric profiles, so a consumer can read them without building a board
  sources:: sources,

  new(config={}):
    local cfg = {
      uid: 'observ-viz-kong',
      dashboardTitle: 'Kong',
      dashboardTags: ['kong', 'gateway', 'api-gateway'],
      datasource: '${datasource}',
      // the identity metric (varMetric) scopes the $instance dropdown, so a
      // generic signal (process_*, go_*) cannot reach another component's
      // instances where the job label does not discriminate them
      selector: 'job=~"$job", instance=~"$instance"',
      varLabels: ['instance'],
      legendLabels: [],
      tabbed: true,
      docTabs: true,
      // 'prometheus' | 'prometheus2' | 'opentelemetry'
      implementation: 'prometheus',
      // static label filter for the rules (no dashboard variables)
      ruleSelector: '',
      errorRatio: 0.05,
      latency: 1,
      folderUid: 'components-networking',
      folderTitle: 'Networking',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local src = sources[cfg.implementation];
    local sel = filters.selector(cfg);
    local by = std.join(', ', src.routeLabels);
    local legendBy = std.join(' / ', ['{{' + l + '}}' for l in src.routeLabels]);
    local has(k) = std.objectHas(src, k);
    // a metric name may carry its own matcher (Kong 2.x latency types), so the
    // selector is spliced in rather than appended
    local m(name, extra='') =
      if std.length(name) > 0 && std.endsWith(name, '}')
      then std.substr(name, 0, std.length(name) - 1) + ', %(queriesSelector)s' + extra + '}'
      else name + '{%(queriesSelector)s' + extra + '}';
    local sig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit)
      .filteringSelector(sel).withLegendFormat(legend).withDescription(desc);
    local quantile(q, bucket) =
      'histogram_quantile(' + q + ', sum by (le, ' + by + ') (rate(' + m(bucket) + '[$__rate_interval])))';

    // ---- signals every implementation answers --------------------------------
    local traffic = {
      requests: sig('Requests', 'sum by (' + by + ') (rate(' + m(src.requests) + '[$__rate_interval]))', 'reqps', legendBy,
                    'Requests per second through the gateway, by ' + std.join(' and ', src.routeLabels) + '.'),
      errors: sig('Errors', 'sum by (' + by + ') (rate(' + m(src.requests, ', ' + src.statusLabel + '=~"5.."') + '[$__rate_interval]))', 'reqps', legendBy,
                  'Responses per second the gateway returned as server errors.'),
      errorRatio: sig('Error ratio',
                      'sum by (' + by + ') (rate(' + m(src.requests, ', ' + src.statusLabel + '=~"5.."') + '[$__rate_interval]))'
                      + ' / clamp_min(sum by (' + by + ') (rate(' + m(src.requests) + '[$__rate_interval])), 1e-9)',
                      'percentunit', legendBy, 'Share of responses that are server errors.'),
      byStatus: sig('Responses by status', 'sum by (' + src.statusLabel + ') (rate(' + m(src.requests) + '[$__rate_interval]))', 'reqps',
                    '{{' + src.statusLabel + '}}', 'Responses per second by status code.'),
      p50: sig('Latency p50', quantile('0.50', src.latencyBucket), src.latencyUnit, 'p50 ' + legendBy, 'Median time the gateway took to answer.'),
      p95: sig('Latency p95', quantile('0.95', src.latencyBucket), src.latencyUnit, 'p95 ' + legendBy, 'Slowest 5 percent.'),
      p99: sig('Latency p99', quantile('0.99', src.latencyBucket), src.latencyUnit, 'p99 ' + legendBy, 'Slowest 1 percent.'),
    };

    // ---- what only one implementation answers --------------------------------
    local upstream =
      (if has('upstreamLatencyBucket') then {
         upstreamP95: sig('Upstream latency p95', quantile('0.95', src.upstreamLatencyBucket), src.latencyUnit, 'upstream p95 ' + legendBy,
                          'Time the service behind the gateway took. The gap against the total is what the gateway itself cost.'),
       } else {})
      + (if has('proxyLatencyBucket') then {
           proxyP95: sig('Gateway latency p95', quantile('0.95', src.proxyLatencyBucket), src.latencyUnit, 'gateway p95 ' + legendBy,
                         'Time spent inside Kong - plugins, routing, auth - rather than waiting for the upstream.'),
         } else {});
    local bandwidth =
      if has('bandwidth') then {
        bandwidth: sig('Bandwidth', 'sum by (' + src.directionLabel + ') (rate(' + m(src.bandwidth) + '[$__rate_interval]))', 'Bps',
                       '{{' + src.directionLabel + '}}', 'Bytes per second in and out of the gateway.'),
      } else if has('bandwidthIn') then {
        bandwidthIn: sig('Bandwidth in', 'sum by (' + by + ') (rate(' + m(src.bandwidthIn) + '[$__rate_interval]))', 'Bps', 'in ' + legendBy, 'Request bytes per second.'),
        bandwidthOut: sig('Bandwidth out', 'sum by (' + by + ') (rate(' + m(src.bandwidthOut) + '[$__rate_interval]))', 'Bps', 'out ' + legendBy, 'Response bytes per second.'),
      } else {};
    local gateway =
      (if has('connections') then {
         connections: sig('Connections', 'sum by (state) (' + m(src.connections) + ')', 'short', '{{state}}', 'nginx connections by state.'),
       } else {})
      + (if has('activeRequests') then {
           activeRequests: sig('Active requests', 'sum by (' + by + ') (' + m(src.activeRequests) + ')', 'short', legendBy, 'Requests in flight.'),
         } else {})
      + (if has('sharedDict') then {
           sharedDict: sig('Shared dictionary used', 'sum by (shared_dict) (' + m(src.sharedDict) + ')', 'bytes', '{{shared_dict}}',
                           'Lua shared dictionary in use. Kong keeps its configuration, rate-limit counters and healthchecks here; running out breaks the gateway in ways the traffic metrics do not show.'),
           sharedDictRatio: sig('Shared dictionary usage',
                                'sum by (shared_dict) (' + m(src.sharedDict) + ') / clamp_min(sum by (shared_dict) (' + m(src.sharedDictTotal) + '), 1)',
                                'percentunit', '{{shared_dict}}', 'How full each shared dictionary is.'),
           workerVms: sig('Worker Lua VMs', 'sum by (pid) (' + m(src.workerVms) + ')', 'bytes', 'pid {{pid}}', 'Memory each worker\'s Lua VM holds.'),
         } else {})
      + (if has('datastore') then {
           datastore: sig('Datastore reachable', m(src.datastore), 'short', 'datastore',
                          '1 while Kong can reach its datastore. A gateway that loses it keeps serving the configuration it has and stops learning about changes.'),
         } else {})
      + (if has('targetHealth') then {
           targetHealth: sig('Upstream targets', 'sum by (upstream, state) (' + m(src.targetHealth) + ')', 'short', '{{upstream}} / {{state}}',
                             'Targets per upstream by health state, as Kong\'s own healthchecks see them.'),
         } else {})
      + (if has('timers') then {
           timers: sig('nginx timers', 'sum by (state) (' + m(src.timers) + ')', 'short', '{{state}}', 'Pending and running nginx timers.'),
         } else {});

    local signals = traffic + upstream + bandwidth + gateway;

    // latency panel: total, and where it went, when the source can say
    local latencyPanel =
      traffic.p95.asTimeSeries('Latency p95: total' + (if has('proxyLatencyBucket') then ', gateway and upstream' else ''))
      + panel.withTargetsMixin(
        (if std.objectHas(upstream, 'proxyP95') then [upstream.proxyP95.asTarget()] else [])
        + (if std.objectHas(upstream, 'upstreamP95') then [upstream.upstreamP95.asTarget()] else [])
      );

    local gatewayGroup = {
      title: 'Gateway',
      width: 12,
      height: 7,
      elements: { [k]: signals[k].asTimeSeries(signals[k]._name) for k in std.objectFields(gateway) },
    };

    pack.build(cfg + {
      description: 'Kong as ' + std.asciiLower(src.title) + ' reports it. ' + src.description,
      references: [
        { title: 'Kong Prometheus plugin', url: 'https://docs.konghq.com/hub/kong-inc/prometheus/', description: 'which kong_* metrics exist and how to turn the per-route ones on' },
        { title: 'Kong OpenTelemetry plugin', url: 'https://docs.konghq.com/hub/kong-inc/opentelemetry/', description: 'the OTLP path' },
        { title: 'HTTP semantic conventions', url: 'https://opentelemetry.io/docs/specs/semconv/http/http-metrics/', description: 'the metric and attribute names the OpenTelemetry profile reads' },
      ],
      rowLabels: src.routeLabels,
      overviewSignals: ['requests', 'errors', 'errorRatio', 'p95', 'p99'],
    }, signals, [
      {
        title: 'Traffic',
        width: 12,
        height: 8,
        elements: {
          requests: traffic.requests.asTimeSeries('Requests'),
          byStatus: traffic.byStatus.asTimeSeries('Responses by status'),
          errorRatio: traffic.errorRatio.asTimeSeries('Error ratio')
                      + panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'red', value: cfg.errorRatio }])
                      + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } }),
          errors: traffic.errors.asTimeSeries('Errors'),
        },
      },
      {
        title: 'Latency',
        width: 12,
        height: 8,
        elements: {
          latency: latencyPanel,
          p99: traffic.p99.asTimeSeries('Latency p99'),
        } + (if std.length(bandwidth) > 0 then { [k]: signals[k].asTimeSeries(signals[k]._name) for k in std.objectFields(bandwidth) } else {}),
      },
    ] + (if std.length(gateway) > 0 then [gatewayGroup] else []), [
      alert.rule.group('kong', [
        alert.rule.new(
          'KongErrorRatioHigh',
          'sum by (' + by + ') (rate(' + src.requests + '{' + src.statusLabel + '=~"5.."' + (if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '') + '}[5m]))'
          + ' / clamp_min(sum by (' + by + ') (rate(' + src.requests + (if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '') + '[5m])), 1e-9) > ' + cfg.errorRatio,
          '10m',
          'critical',
          {},
          { summary: 'More than ' + (cfg.errorRatio * 100) + ' percent of what Kong answers for {{ $labels.' + src.routeLabels[0] + ' }} are server errors.' }
        ),
      ] + (if has('datastore') then [
             alert.rule.new(
               'KongDatastoreUnreachable',
               src.datastore + (if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '') + ' == 0',
               '5m',
               'critical',
               {},
               {
                 summary: 'Kong on {{ $labels.instance }} cannot reach its datastore.',
                 description: 'The gateway keeps serving the configuration it already has, so traffic looks fine while every change - a new route, a revoked key - silently fails to arrive.',
               }
             ),
           ] else []) + (if has('sharedDict') then [
             alert.rule.new(
               'KongSharedDictAlmostFull',
               'sum by (shared_dict) (' + src.sharedDict + (if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '') + ')'
               + ' / clamp_min(sum by (shared_dict) (' + src.sharedDictTotal + (if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '') + '), 1) > 0.9',
               '15m',
               'warning',
               {},
               {
                 summary: 'Kong shared dictionary {{ $labels.shared_dict }} is over 90 percent full.',
                 description: 'These hold the configuration cache, rate-limit counters and healthcheck state. When one fills up Kong starts evicting, and what breaks depends on which dictionary it was.',
               }
             ),
           ] else [])),
    ]),
}
