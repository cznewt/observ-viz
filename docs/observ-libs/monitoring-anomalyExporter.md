# Anomaly exporter  (`g.libs.monitoring.anomalyExporter`)

Dashboard uid `observ-viz-anomaly-exporter` · 18 signals · 3 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `durationAvg` | s | `sum by (module) (rate(anomaly_exporter_probe_duration_seconds_sum{job=~"$job", instance=~"$instance"}[$__rate_interval])) / sum by (module) (rate(anomaly_exporter_probe_duration_seconds_count{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `durationP50` | s | `histogram_quantile(0.50, sum by (le, module) (rate(anomaly_exporter_probe_duration_seconds_bucket{job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `durationP99` | s | `histogram_quantile(0.99, sum by (le, module) (rate(anomaly_exporter_probe_duration_seconds_bucket{job=~"$job", instance=~"$instance"}[$__rate_interval])))` | `module:anomaly_exporter_probe_duration_seconds:p99_5m` |
| `failureRatio` | percentunit | `sum(rate(anomaly_exporter_probes_total{job=~"$job", instance=~"$instance", result!="success"}[$__rate_interval])) / sum(rate(anomaly_exporter_probes_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `failures` | short | `sum by (module) (rate(anomaly_exporter_probes_total{job=~"$job", instance=~"$instance", result!="success"}[$__rate_interval]))` | — |
| `modules` | short | `count(count by (module) (anomaly_exporter_probes_total{job=~"$job", instance=~"$instance"}))` | — |
| `probeLatency` | s | `max by (probe, module) (anomaly_probe_duration_seconds{job=~"$job", instance=~"$instance"})` | — |
| `probeSuccess` | short | `min by (probe, module) (anomaly_probe_success{job=~"$job", instance=~"$instance"})` | — |
| `probes` | short | `sum by (module, result) (rate(anomaly_exporter_probes_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | `module:anomaly_exporter_probes:rate5m` |
| `probesTotal` | short | `sum(rate(anomaly_exporter_probes_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job", instance=~"$instance"}` | — |
| `score` | short | `max by (probe, module) (anomaly_score{job=~"$job", instance=~"$instance"})` | — |
| `scoreBySeries` | short | `anomaly_score{job=~"$job", instance=~"$instance"}` | — |
| `scoreHigh` | short | `count(anomaly_score{job=~"$job", instance=~"$instance"} > 0.8) or vector(0)` | — |
| `seriesScored` | short | `sum by (probe) (anomaly_series_scored{job=~"$job", instance=~"$instance"})` | — |
| `seriesSkipped` | short | `sum by (probe) (anomaly_series_total{job=~"$job", instance=~"$instance"} - anomaly_series_scored{job=~"$job", instance=~"$instance"})` | — |
| `version` | short | `max by (version) (anomaly_exporter_build_info{job=~"$job", instance=~"$instance"})` | — |

## Dashboard

- **Overview** — `ov01_rate`, `ov02_failureRatio`, `ov03_modules`
- **Scores** — `sc01_score`, `sc02_scoreBySeries`, `sc03_probeSuccess`, `sc04_probeLatency`, `sc05_seriesScored`, `sc06_scoreHigh`
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
