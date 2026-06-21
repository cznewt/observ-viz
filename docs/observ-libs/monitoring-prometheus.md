# Prometheus  (`g.libs.monitoring.prometheus`)

Dashboard uid `observ-viz-prometheus` · 7 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `headSeries` | short | `prometheus_tsdb_head_series{job=~"$job"}` |
| `queryRate` | reqps | `rate(prometheus_http_requests_total{job=~"$job",handler=~"/api/v1/query.*"}[$__rate_interval])` |
| `residentMemory` | bytes | `process_resident_memory_bytes{job=~"$job"}` |
| `ruleEvalDuration` | s | `rate(prometheus_rule_evaluation_duration_seconds_sum{job=~"$job"}[$__rate_interval]) / rate(prometheus_rule_evaluation_duration_seconds_count{job=~"$job"}[$__rate_interval])` |
| `samplesAppended` | short | `rate(prometheus_tsdb_head_samples_appended_total{job=~"$job"}[$__rate_interval])` |
| `scrapeDuration` | s | `prometheus_target_interval_length_seconds{quantile="0.99",job=~"$job"}` |
| `targetsUp` | short | `sum(up{job=~"$job"})` |

## Dashboard

- **TSDB** — `headSeries`, `samplesAppended`
- **Scraping** — `scrapeDuration`, `targetsUp`
- **Queries** — `queryRate`
- **Resources** — `residentMemory`, `ruleEvalDuration`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `PrometheusDown` | critical | 5m | — |
| `PrometheusRuleEvaluationSlow` | warning | 15m | — |
| `PrometheusHighMemory` | warning | 15m | — |
| `PrometheusHighScrapeDuration` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:prometheus_samples_appended:rate5m` | `rate(prometheus_tsdb_head_samples_appended_total[5m])` |
| `instance:prometheus_query_requests:rate5m` | `rate(prometheus_http_requests_total{handler=~"/api/v1/query.*"}[5m])` |
