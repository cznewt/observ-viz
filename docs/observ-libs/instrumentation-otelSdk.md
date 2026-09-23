# OpenTelemetry SDK  (`g.libs.instrumentation.otelSdk`)

Dashboard uid `observ-viz-otel-sdk` · 15 signals · 3 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `exporterDuration` | s | `histogram_quantile(0.95, sum by (le) (rate(otel_sdk_exporter_operation_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `logQueueSize` | short | `sum(otel_sdk_processor_log_queue_size{job=~"$job"})` | — |
| `logsCreated` | ops | `sum(rate(otel_sdk_log_created_total{job=~"$job"}[$__rate_interval]))` | — |
| `logsExported` | ops | `sum(rate(otel_sdk_exporter_log_exported_total{job=~"$job"}[$__rate_interval]))` | — |
| `metricCollection` | s | `histogram_quantile(0.95, sum by (le) (rate(otel_sdk_metric_reader_collection_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `metricsExported` | ops | `sum(rate(otel_sdk_exporter_metric_data_point_exported_total{job=~"$job"}[$__rate_interval]))` | — |
| `spanQueueCapacity` | short | `sum(otel_sdk_processor_span_queue_capacity{job=~"$job"})` | — |
| `spanQueueSize` | short | `sum(otel_sdk_processor_span_queue_size{job=~"$job"})` | — |
| `spanQueueUtil` | percent | `100 * sum(otel_sdk_processor_span_queue_size{job=~"$job"}) / clamp_min(sum(otel_sdk_processor_span_queue_capacity{job=~"$job"}), 1)` | — |
| `spansEnded` | ops | `sum(rate(otel_sdk_span_ended_total{job=~"$job"}[$__rate_interval]))` | — |
| `spansExported` | ops | `sum(rate(otel_sdk_exporter_span_exported_total{job=~"$job"}[$__rate_interval]))` | — |
| `spansFailed` | ops | `sum(rate(otel_sdk_exporter_span_exported_total{job=~"$job", error_type!=""}[$__rate_interval]))` | — |
| `spansInflight` | short | `sum(otel_sdk_exporter_span_inflight{job=~"$job"})` | — |
| `spansLive` | short | `sum(otel_sdk_span_live{job=~"$job"})` | — |
| `spansProcessed` | ops | `sum by (error_type) (rate(otel_sdk_processor_span_processed_total{job=~"$job"}[$__rate_interval]))` | — |

## Dashboard

- **Overview** — `ov1_ended`, `ov2_failed`, `ov3_queue`, `ov4_export`
- **Traces** — `exporterDuration`, `processed`, `queue`, `spans`, `spansLive`
- **Logs and metrics** — `logQueue`, `logs`, `metricCollection`, `metrics`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `OtelSdkExportFailing` | warning | 15m | — |
| `OtelSdkQueueNearCapacity` | warning | 10m | — |
| `OtelSdkExportSlow` | info | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job:otel_sdk_spans_exported:rate5m` | `sum by (job) (rate(otel_sdk_exporter_span_exported_total[5m]))` |
| `job:otel_sdk_span_queue:ratio` | `sum by (job) (otel_sdk_processor_span_queue_size) / clamp_min(sum by (job) (otel_sdk_processor_span_queue_capacity), 1)` |
