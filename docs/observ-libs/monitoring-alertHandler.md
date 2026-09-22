# Alert handler  (`g.libs.monitoring.alertHandler`)

Dashboard uid `observ-viz-alert-handler` · 18 signals · 5 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `actions` | short | `sum by (rule, action) (rate(alert_handler_actions_total{job=~"$job"}[$__rate_interval]))` | — |
| `actionsByResult` | short | `sum by (result) (rate(alert_handler_actions_total{job=~"$job"}[$__rate_interval]))` | — |
| `actionsFailed` | short | `sum by (rule, action) (rate(alert_handler_actions_total{job=~"$job", result!~"ok\|success"}[$__rate_interval]))` | — |
| `alerts` | short | `sum by (status) (rate(alert_handler_alerts_total{job=~"$job"}[$__rate_interval]))` | — |
| `configAge` | dtdurations | `time() - max(alert_handler_config_loaded_timestamp_seconds{job=~"$job"})` | — |
| `configRules` | short | `max(alert_handler_config_rules{job=~"$job"})` | — |
| `configValid` | short | `min(alert_handler_config_valid{job=~"$job"})` | — |
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` | — |
| `durationAvg` | s | `sum by (rule, action) (rate(alert_handler_action_duration_seconds_sum{job=~"$job"}[$__rate_interval])) / sum by (rule, action) (rate(alert_handler_action_duration_seconds_count{job=~"$job"}[$__rate_interval]))` | — |
| `durationP99` | s | `histogram_quantile(0.99, sum by (le, action) (rate(alert_handler_action_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `failureRatio` | percentunit | `sum(rate(alert_handler_actions_total{job=~"$job", result!~"ok\|success\|skipped"}[$__rate_interval])) / sum(rate(alert_handler_actions_total{job=~"$job"}[$__rate_interval]))` | — |
| `inflight` | short | `sum(alert_handler_actions_inflight{job=~"$job"})` | — |
| `matches` | short | `sum by (rule) (rate(alert_handler_rule_matches_total{job=~"$job"}[$__rate_interval]))` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job"}` | — |
| `runbooks` | short | `max(alert_handler_runbooks_available{job=~"$job"})` | — |
| `secrets` | short | `max(alert_handler_secrets_loaded{job=~"$job"})` | — |
| `webhookErrors` | short | `sum(rate(alert_handler_webhook_requests_total{job=~"$job", result!~"ok\|success\|accepted"}[$__rate_interval]))` | — |
| `webhooks` | short | `sum by (result) (rate(alert_handler_webhook_requests_total{job=~"$job"}[$__rate_interval]))` | — |

## Dashboard

- **Overview** — `ov01_configValid`, `ov02_rules`, `ov03_configAge`, `ov04_runbooks`, `ov05_secrets`, `ov06_inflight`, `ov07_failureRatio`, `ov08_webhookErrors`
- **Intake** — `alerts`, `matches`, `webhooks`
- **Actions** — `actions`, `actionsByResult`, `actionsFailed`, `durationAvg`, `durationP99`, `inflight`
- **Resources** — `cpu`, `rss`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `AlertHandlerDown` | critical | 5m | — |
| `AlertHandlerConfigInvalid` | critical | 5m | — |
| `AlertHandlerActionsFailing` | warning | 15m | — |
| `AlertHandlerWebhookErrors` | warning | 15m | — |
| `AlertHandlerActionsStuck` | warning | 30m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `rule:alert_handler_actions:rate5m` | `sum by (rule, action, result) (rate(alert_handler_actions_total[5m]))` |
| `job:alert_handler_alerts:rate5m` | `sum by (job, status) (rate(alert_handler_alerts_total[5m]))` |
