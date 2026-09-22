# Anomaly exporter  (`g.libs.monitoring.anomalyExporter`)

Dashboard uid `observ-viz-anomaly-exporter` · 11 signals · 3 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` | — |
| `durationAvg` | s | `sum by (module) (rate(anomaly_exporter_probe_duration_seconds_sum{job=~"$job"}[$__rate_interval])) / sum by (module) (rate(anomaly_exporter_probe_duration_seconds_count{job=~"$job"}[$__rate_interval]))` | — |
| `durationP50` | s | `histogram_quantile(0.50, sum by (le, module) (rate(anomaly_exporter_probe_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `durationP99` | s | `histogram_quantile(0.99, sum by (le, module) (rate(anomaly_exporter_probe_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | `module:anomaly_exporter_probe_duration_seconds:p99_5m` |
| `failureRatio` | percentunit | `sum(rate(anomaly_exporter_probes_total{job=~"$job", result!="success"}[$__rate_interval])) / sum(rate(anomaly_exporter_probes_total{job=~"$job"}[$__rate_interval]))` | — |
| `failures` | short | `sum by (module) (rate(anomaly_exporter_probes_total{job=~"$job", result!="success"}[$__rate_interval]))` | — |
| `modules` | short | `count(count by (module) (anomaly_exporter_probes_total{job=~"$job"}))` | — |
| `probes` | short | `sum by (module, result) (rate(anomaly_exporter_probes_total{job=~"$job"}[$__rate_interval]))` | `module:anomaly_exporter_probes:rate5m` |
| `probesTotal` | short | `sum(rate(anomaly_exporter_probes_total{job=~"$job"}[$__rate_interval]))` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job"}` | — |
| `version` | short | `max by (version) (anomaly_exporter_build_info{job=~"$job"})` | — |

## Dashboard

- **Overview** — `ov01_rate`, `ov02_failureRatio`, `ov03_modules`
- **Probes** — `duration`, `durationAvg`, `failures`, `probes`
- **Resources** — `cpu`, `rss`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `AnomalyExporterDown` | warning | 10m | — |
| `AnomalyExporterProbesFailing` | warning | 15m | — |
| `AnomalyExporterProbeSlow` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `module:anomaly_exporter_probes:rate5m` | `sum by (module, result) (rate(anomaly_exporter_probes_total[5m]))` |
| `module:anomaly_exporter_probe_duration_seconds:p99_5m` | `histogram_quantile(0.99, sum by (le, module) (rate(anomaly_exporter_probe_duration_seconds_bucket[5m])))` |
