// observ-viz gRPC instrumentation pack (hand-written).
// Server and client gRPC from go-grpc-prometheus and its ports in other
// languages (grpc_server_*, grpc_client_*): calls by method, the status codes
// they end with, how long they take, and streaming message flow.
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
      uid: 'observ-viz-rpc',
      dashboardTitle: 'gRPC',
      dashboardTags: ['grpc', 'rpc', 'instrumentation'],
      description: 'gRPC traffic on both sides: calls per method, the status codes they finish with, handling time percentiles, calls still in flight and streaming message rates.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'grpc_server_started_total',
      ruleSelector: '',
      legend: '{{grpc_service}}/{{grpc_method}}',
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
      started: sig('Calls started', 'sum(rate(grpc_server_started_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'started', desc='Server calls started per second.'),
      handled: sig('Calls handled', 'sum(rate(grpc_server_handled_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', 'handled', desc='Server calls finished per second. A gap against started calls means calls are hanging.'),
      byMethod: sig('Calls by method', 'topk(10, sum by (grpc_service, grpc_method) (rate(grpc_server_started_total{%(queriesSelector)s}[$__rate_interval])))', 'reqps', desc='The ten busiest methods.'),
      byCode: sig('Calls by status code', 'sum by (grpc_code) (rate(grpc_server_handled_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{grpc_code}}', desc='Completed calls per second by gRPC status code.'),
      errorRate: sig('Error ratio', 'sum(rate(grpc_server_handled_total{%(queriesSelector)s, grpc_code!="OK"}[$__rate_interval])) / clamp_min(sum(rate(grpc_server_handled_total{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'percentunit', 'errors', desc='Share of calls ending in anything other than OK.'),
      inFlight: sig('Calls in flight', 'sum(rate(grpc_server_started_total{%(queriesSelector)s}[$__rate_interval])) - sum(rate(grpc_server_handled_total{%(queriesSelector)s}[$__rate_interval]))', 'short', 'in flight', desc='Started minus handled: calls still open.'),
      p95: sig('Handling p95', 'histogram_quantile(0.95, sum by (le) (rate(grpc_server_handling_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='Slowest 5 percent of server calls.'),
      p99: sig('Handling p99', 'histogram_quantile(0.99, sum by (le) (rate(grpc_server_handling_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p99', desc='Slowest 1 percent of server calls.'),
      p95ByMethod: sig('Handling p95 by method', 'topk(10, histogram_quantile(0.95, sum by (le, grpc_service, grpc_method) (rate(grpc_server_handling_seconds_bucket{%(queriesSelector)s}[$__rate_interval]))))', 's', desc='The ten slowest methods at p95.'),
      msgReceived: sig('Stream messages received', 'sum(rate(grpc_server_msg_received_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'received', desc='Streamed messages the server received per second.'),
      msgSent: sig('Stream messages sent', 'sum(rate(grpc_server_msg_sent_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'sent', desc='Streamed messages the server sent per second.'),
      clientHandled: sig('Client calls', 'sum by (grpc_code) (rate(grpc_client_handled_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{grpc_code}}', desc='Outbound gRPC calls per second by status code.'),
      clientP95: sig('Client p95', 'histogram_quantile(0.95, sum by (le) (rate(grpc_client_handling_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='Slowest 5 percent of outbound gRPC calls.'),
      codeTable: sig('Methods', 'topk(20, sum by (grpc_service, grpc_method, grpc_code) (rate(grpc_server_handled_total{%(queriesSelector)s}[$__rate_interval])))', 'reqps', desc='Method and status code breakdown.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_started: signals.started.asStat('Calls/s'),
          ov2_errors: signals.errorRate.asStat('Error ratio') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]),
          ov3_p95: signals.p95.asStat('Handling p95'),
          ov4_inFlight: signals.inFlight.asStat('Calls in flight'),
        },
      } + stats,
      {
        title: 'Server',
        elements: {
          byCode: signals.byCode.asTimeSeries('Calls/s by status code'),
          byMethod: signals.byMethod.asTimeSeries('Calls/s by method'),
          duration: signals.p99.asTimeSeries('Handling time')
                    + panel.withTargetsMixin([signals.p95.asTarget()]),
          p95ByMethod: signals.p95ByMethod.asTimeSeries('Handling p95 by method'),
          throughput: signals.started.asTimeSeries('Started vs handled')
                      + panel.withTargetsMixin([signals.handled.asTarget()]),
          codeTable: signals.codeTable.asTable('Methods by status code'),
        },
      } + charts,
      {
        title: 'Streams and clients',
        elements: {
          messages: signals.msgReceived.asTimeSeries('Stream messages/s')
                    + panel.withTargetsMixin([signals.msgSent.asTarget()]),
          clientHandled: signals.clientHandled.asTimeSeries('Client calls/s by status code'),
          clientP95: signals.clientP95.asTimeSeries('Client handling p95'),
        },
      } + charts,
    ], [
      alert.rule.group('grpc', [
        alert.rule.new('GrpcErrorRateHigh',
                       'sum by (job, grpc_service) (rate(grpc_server_handled_total{grpc_code!="OK"' + rsComma + '}[5m])) / clamp_min(sum by (job, grpc_service) (rate(grpc_server_handled_total' + rsBrace + '[5m])), 0.001) > 0.05',
                       '10m',
                       'warning',
                       {},
                       { summary: 'More than 5 percent of gRPC calls to {{ $labels.grpc_service }} on {{ $labels.job }} end in an error.' }),
        alert.rule.new('GrpcLatencyHigh',
                       'histogram_quantile(0.95, sum by (le, job, grpc_service) (rate(grpc_server_handling_seconds_bucket' + rsBrace + '[5m]))) > 1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'gRPC calls to {{ $labels.grpc_service }} on {{ $labels.job }} take more than a second at p95.' }),
        alert.rule.new('GrpcCallsUnfinished',
                       'sum by (job) (rate(grpc_server_started_total' + rsBrace + '[5m])) - sum by (job) (rate(grpc_server_handled_total' + rsBrace + '[5m])) > 1',
                       '15m',
                       'warning',
                       {},
                       { summary: 'gRPC calls on {{ $labels.job }} are being started faster than they finish; calls are hanging.' }),
      ]),
    ], [
      alert.rule.group('grpc.rules', [
        alert.rule.record('job_service:grpc_server_calls:rate5m', 'sum by (job, grpc_service) (rate(grpc_server_handled_total' + rsBrace + '[5m]))'),
        alert.rule.record('job_service:grpc_server_errors:ratio5m',
                          'sum by (job, grpc_service) (rate(grpc_server_handled_total{grpc_code!="OK"' + rsComma + '}[5m])) / clamp_min(sum by (job, grpc_service) (rate(grpc_server_handled_total' + rsBrace + '[5m])), 0.001)'),
      ]),
    ]),
}
