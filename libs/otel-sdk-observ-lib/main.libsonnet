// observ-viz OpenTelemetry SDK pack (hand-written).
// An instrumented application's own telemetry pipeline, from the SDK
// self-metrics in the OpenTelemetry semantic conventions (otel_sdk_*): spans
// and logs created, what the exporter shipped, what is still in flight, and
// how full the processor queues are. This is where silently lost telemetry
// shows up, which no other board can tell you about.
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
      uid: 'observ-viz-otel-sdk',
      dashboardTitle: 'OpenTelemetry SDK',
      dashboardTags: ['opentelemetry', 'otel', 'instrumentation'],
      description: 'The telemetry pipeline inside an instrumented application: spans and logs produced, exported and dropped, exporter latency, and how full the batch processor queues are. Telemetry lost here never reaches any backend.',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'otel_sdk_span_live',
      ruleSelector: '',
      legend: '{{instance}}',
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
      spansLive: sig('Spans live', 'sum(otel_sdk_span_live{%(queriesSelector)s})', 'short', 'live', desc='Spans started and not yet ended.'),
      spansEnded: sig('Spans ended', 'sum(rate(otel_sdk_span_ended_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'ended', desc='Spans finished per second.'),
      spansExported: sig('Spans exported', 'sum(rate(otel_sdk_exporter_span_exported_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'exported', desc='Spans the exporter shipped per second.'),
      spansFailed: sig('Spans not exported', 'sum(rate(otel_sdk_exporter_span_exported_total{%(queriesSelector)s, error_type!=""}[$__rate_interval]))', 'ops', 'failed', desc='Spans the exporter failed to ship, by error type. Anything here is telemetry lost.'),
      spansInflight: sig('Spans in flight', 'sum(otel_sdk_exporter_span_inflight{%(queriesSelector)s})', 'short', 'in flight', desc='Spans handed to the exporter and not yet acknowledged.'),
      spanQueueSize: sig('Span queue size', 'sum(otel_sdk_processor_span_queue_size{%(queriesSelector)s})', 'short', 'queued', desc='Spans waiting in the batch processor.'),
      spanQueueCapacity: sig('Span queue capacity', 'sum(otel_sdk_processor_span_queue_capacity{%(queriesSelector)s})', 'short', 'capacity', desc='How many spans the batch processor can hold. A full queue drops spans.'),
      spanQueueUtil: sig('Span queue usage', '100 * sum(otel_sdk_processor_span_queue_size{%(queriesSelector)s}) / clamp_min(sum(otel_sdk_processor_span_queue_capacity{%(queriesSelector)s}), 1)', 'percent', 'queue usage', desc='Batch processor queue against its capacity.'),
      spansProcessed: sig('Spans processed', 'sum by (error_type) (rate(otel_sdk_processor_span_processed_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{error_type}}', desc='Spans the processor handled per second, split by error type where it failed.'),
      exporterDuration: sig('Export duration p95', 'histogram_quantile(0.95, sum by (le) (rate(otel_sdk_exporter_operation_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='Slowest 5 percent of export calls. Slow exports back the queue up.'),
      logsCreated: sig('Logs created', 'sum(rate(otel_sdk_log_created_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'created', desc='Log records the SDK produced per second.'),
      logsExported: sig('Logs exported', 'sum(rate(otel_sdk_exporter_log_exported_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'exported', desc='Log records shipped per second.'),
      logQueueSize: sig('Log queue size', 'sum(otel_sdk_processor_log_queue_size{%(queriesSelector)s})', 'short', 'queued', desc='Log records waiting in the batch processor.'),
      metricsExported: sig('Metric points exported', 'sum(rate(otel_sdk_exporter_metric_data_point_exported_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', 'exported', desc='Metric data points shipped per second.'),
      metricCollection: sig('Metric collection p95', 'histogram_quantile(0.95, sum by (le) (rate(otel_sdk_metric_reader_collection_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p95', desc='How long a metric collection cycle takes.'),
    };
    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_ended: signals.spansEnded.asStat('Spans/s'),
          ov2_failed: signals.spansFailed.asStat('Spans not exported') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.001 }]),
          ov3_queue: signals.spanQueueUtil.asStat('Span queue usage') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 50 }, { color: 'red', value: 80 }]),
          ov4_export: signals.exporterDuration.asStat('Export p95'),
        },
      } + stats,
      {
        title: 'Traces',
        elements: {
          spans: signals.spansEnded.asTimeSeries('Spans/s')
                 + panel.withTargetsMixin([signals.spansExported.asTarget(), signals.spansFailed.asTarget()]),
          spansLive: signals.spansLive.asTimeSeries('Spans live')
                     + panel.withTargetsMixin([signals.spansInflight.asTarget()]),
          queue: signals.spanQueueSize.asTimeSeries('Span queue')
                 + panel.withTargetsMixin([signals.spanQueueCapacity.asTarget()]),
          processed: signals.spansProcessed.asTimeSeries('Spans processed/s'),
          exporterDuration: signals.exporterDuration.asTimeSeries('Export duration p95'),
        },
      } + charts,
      {
        title: 'Logs and metrics',
        elements: {
          logs: signals.logsCreated.asTimeSeries('Log records/s')
                + panel.withTargetsMixin([signals.logsExported.asTarget()]),
          logQueue: signals.logQueueSize.asTimeSeries('Log queue size'),
          metrics: signals.metricsExported.asTimeSeries('Metric points/s'),
          metricCollection: signals.metricCollection.asTimeSeries('Metric collection p95'),
        },
      } + charts,
    ], [
      alert.rule.group('otel-sdk', [
        alert.rule.new('OtelSdkExportFailing',
                       'sum by (job) (rate(otel_sdk_exporter_span_exported_total{error_type!=""' + rsComma + '}[10m])) > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: '{{ $labels.job }} is failing to export spans; telemetry is being lost.' }),
        alert.rule.new('OtelSdkQueueNearCapacity',
                       '100 * sum by (job) (otel_sdk_processor_span_queue_size' + rsBrace + ') / clamp_min(sum by (job) (otel_sdk_processor_span_queue_capacity' + rsBrace + '), 1) > 80',
                       '10m',
                       'warning',
                       {},
                       { summary: 'The span batch queue on {{ $labels.job }} is over 80 percent full; spans will start being dropped.' }),
        alert.rule.new('OtelSdkExportSlow',
                       'histogram_quantile(0.95, sum by (le, job) (rate(otel_sdk_exporter_operation_duration_seconds_bucket' + rsBrace + '[5m]))) > 5',
                       '15m',
                       'info',
                       {},
                       { summary: 'Telemetry exports from {{ $labels.job }} take more than five seconds at p95.' }),
      ]),
    ], [
      alert.rule.group('otel-sdk.rules', [
        alert.rule.record('job:otel_sdk_spans_exported:rate5m', 'sum by (job) (rate(otel_sdk_exporter_span_exported_total' + rsBrace + '[5m]))'),
        alert.rule.record('job:otel_sdk_span_queue:ratio',
                          'sum by (job) (otel_sdk_processor_span_queue_size' + rsBrace + ') / clamp_min(sum by (job) (otel_sdk_processor_span_queue_capacity' + rsBrace + '), 1)'),
      ]),
    ]),
}
