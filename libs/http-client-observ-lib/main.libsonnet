// observ-viz HTTP client instrumentation pack (hand-written).
// What a service calls out to, from OpenTelemetry semantic conventions
// (http_client_request_duration_seconds, http_client_active_requests,
// http_client_open_connections). Outbound failures usually surface here
// before they show up as errors on the service's own endpoints.
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  elements(datasource, selector, prefix='')::
    local p = $.new({ datasource: datasource, selector: selector, docTabs: false });
    { [prefix + k]: p.grafana.elements[k] for k in std.objectFields(p.grafana.elements) },

  new(config={}):
    local cfg = {
      uid: 'observ-viz-http-client',
      dashboardTitle: 'HTTP client',
      dashboardTags: ['http', 'client', 'instrumentation'],
      description: 'The calls a service makes to others: request rate and status by peer, duration percentiles, open connections and how long they live. Outbound trouble shows here first.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'http_client_request_duration_seconds_count',
      ruleSelector: '',
      legend: '{{server_address}}',
      peerLabel: 'server_address',
      statusLabel: 'http_response_status_code',
      docTabs: true,
      folderUid: 'software-instrumentation',
      folderTitle: 'Instrumentation',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      rps: sig('Calls', 'sum(rate(http_client_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'calls', desc='Outbound requests per second.'),
      byPeer: sig('Calls by peer', 'sum by (' + cfg.peerLabel + ') (rate(http_client_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', desc='Outbound requests per second by destination.'),
      errorRate: sig('Error ratio', 'sum(rate(http_client_request_duration_seconds_count{%(queriesSelector)s, ' + cfg.statusLabel + '=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(http_client_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'percentunit', 'errors', desc='Share of outbound calls the peer answered with a server error.'),
      errorsByPeer: sig('Errors by peer', 'sum by (' + cfg.peerLabel + ') (rate(http_client_request_duration_seconds_count{%(queriesSelector)s, ' + cfg.statusLabel + '=~"5.."}[$__rate_interval]))', 'reqps', desc='Failing calls per second by destination, which names the dependency that is down.'),
      p95: sig('Duration p95', 'histogram_quantile(0.95, sum by (le) (rate(http_client_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='Slowest 5 percent of outbound calls.'),
      p99: sig('Duration p99', 'histogram_quantile(0.99, sum by (le) (rate(http_client_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Slowest 1 percent of outbound calls. This is what your own tail latency inherits.'),
      p95ByPeer: sig('Duration p95 by peer', 'histogram_quantile(0.95, sum by (le, ' + cfg.peerLabel + ') (rate(http_client_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', desc='Slowest 5 percent per destination.'),
      active: sig('Active calls', 'sum(http_client_active_requests{%(queriesSelector)s})', 'short', 'in flight', desc='Outbound requests in flight.'),
      openConnections: sig('Open connections', 'sum by (' + cfg.peerLabel + ') (http_client_open_connections{%(queriesSelector)s})', 'short', desc='Connections the client pool holds open per destination.'),
      connectionDuration: sig('Connection lifetime p95', 'histogram_quantile(0.95, sum by (le) (rate(http_client_connection_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='How long pooled connections live. Very short lifetimes mean the pool is churning.'),
      requestSize: sig('Request bodies', 'sum(rate(http_client_request_body_size_bytes_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'sent', desc='Bytes sent in request bodies per second.'),
      responseSize: sig('Response bodies', 'sum(rate(http_client_response_body_size_bytes_sum{%(queriesSelector)s}[$__rate_interval]))', 'Bps', 'received', desc='Bytes received in response bodies per second.'),
      peerTable: sig('Peers', 'topk(20, sum by (' + cfg.peerLabel + ', ' + cfg.statusLabel + ') (rate(http_client_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval])))', 'reqps', desc='Destination and status breakdown.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_rps: signals.rps.asStat('Calls/s'),
          ov2_errors: signals.errorRate.asStat('Error ratio') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]),
          ov3_p95: signals.p95.asStat('Duration p95'),
          ov4_active: signals.active.asStat('Active calls'),
        },
      } + stats,
      {
        title: 'Calls',
        elements: {
          byPeer: signals.byPeer.asTimeSeries('Calls/s by peer'),
          errorsByPeer: signals.errorsByPeer.asTimeSeries('Failing calls/s by peer'),
          duration: signals.p99.asTimeSeries('Call duration')
                    + panel.withTargetsMixin([signals.p95.asTarget()]),
          p95ByPeer: signals.p95ByPeer.asTimeSeries('Duration p95 by peer'),
        },
      } + charts,
      {
        title: 'Connections',
        elements: {
          openConnections: signals.openConnections.asTimeSeries('Open connections'),
          connectionDuration: signals.connectionDuration.asTimeSeries('Connection lifetime p95'),
          payloads: signals.requestSize.asTimeSeries('Body throughput')
                    + panel.withTargetsMixin([signals.responseSize.asTarget()]),
          peerTable: signals.peerTable.asTable('Peers by status'),
        },
      } + charts,
    ], [
      alert.rule.group('http-client', [
        alert.rule.new('HttpClientErrorRateHigh',
                       'sum by (job, server_address) (rate(http_client_request_duration_seconds_count{' + cfg.statusLabel + '=~"5.."' + rsComma + '}[5m])) / clamp_min(sum by (job, server_address) (rate(http_client_request_duration_seconds_count' + rsBrace + '[5m])), 0.001) > 0.05',
                       '10m',
                       'warning',
                       {},
                       { summary: '{{ $labels.job }} is getting server errors from {{ $labels.server_address }}.' }),
        alert.rule.new('HttpClientLatencyHigh',
                       'histogram_quantile(0.95, sum by (le, job, server_address) (rate(http_client_request_duration_seconds_bucket' + rsBrace + '[5m]))) > 2',
                       '15m',
                       'warning',
                       {},
                       { summary: 'Calls from {{ $labels.job }} to {{ $labels.server_address }} take more than two seconds at p95.' }),
      ]),
    ], [
      alert.rule.group('http-client.rules', [
        alert.rule.record('job_peer:http_client_requests:rate5m', 'sum by (job, server_address) (rate(http_client_request_duration_seconds_count' + rsBrace + '[5m]))'),
        alert.rule.record('job_peer:http_client_duration_seconds:p95_5m', 'histogram_quantile(0.95, sum by (le, job, server_address) (rate(http_client_request_duration_seconds_bucket' + rsBrace + '[5m])))'),
      ]),
    ]),
}
