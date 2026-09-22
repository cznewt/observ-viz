# Alertmanager  (`g.libs.monitoring.alertmanager`)

Dashboard uid `observ-viz-alertmanager` · 34 signals · 6 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `aggregationGroups` | short | `sum(alertmanager_dispatcher_aggregation_groups{job=~"$job"})` | — |
| `alertsActive` | short | `sum(alertmanager_alerts{job=~"$job", state="active"})` | — |
| `alertsByState` | short | `sum by (state) (alertmanager_alerts{job=~"$job"})` | — |
| `alertsSuppressed` | short | `sum(alertmanager_alerts{job=~"$job", state="suppressed"})` | — |
| `clusterFailedPeers` | short | `alertmanager_cluster_failed_peers{job=~"$job"}` | — |
| `clusterHealth` | short | `alertmanager_cluster_health_score{job=~"$job"}` | — |
| `clusterMembers` | short | `alertmanager_cluster_members{job=~"$job"}` | — |
| `clusterQueued` | short | `alertmanager_cluster_messages_queued{job=~"$job"}` | — |
| `clusterReconnectFailed` | short | `sum by (pod) (rate(alertmanager_cluster_reconnections_failed_total{job=~"$job"}[$__rate_interval]))` | — |
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` | — |
| `failureRatio` | percentunit | `sum by (integration) (rate(alertmanager_notifications_failed_total{job=~"$job"}[$__rate_interval])) / sum by (integration) (rate(alertmanager_notifications_total{job=~"$job"}[$__rate_interval]))` | `integration:alertmanager_notifications_failed:ratio_rate5m` |
| `failureRatioTotal` | percentunit | `sum(rate(alertmanager_notifications_failed_total{job=~"$job"}[$__rate_interval])) / sum(rate(alertmanager_notifications_total{job=~"$job"}[$__rate_interval]))` | — |
| `httpInFlight` | short | `sum(alertmanager_http_requests_in_flight{job=~"$job"})` | — |
| `httpP99` | s | `histogram_quantile(0.99, sum by (le) (rate(alertmanager_http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `httpRate` | reqps | `sum by (handler) (rate(alertmanager_http_request_duration_seconds_count{job=~"$job"}[$__rate_interval]))` | — |
| `inhibitionRules` | short | `max(alertmanager_inhibition_rules{job=~"$job"})` | — |
| `integrations` | short | `max(alertmanager_integrations{job=~"$job"})` | — |
| `invalid` | short | `sum(rate(alertmanager_alerts_invalid_total{job=~"$job"}[$__rate_interval]))` | — |
| `nflogErrors` | short | `sum(rate(alertmanager_nflog_query_errors_total{job=~"$job"}[$__rate_interval]))` | — |
| `notificationP99` | s | `histogram_quantile(0.99, sum by (le, integration) (rate(alertmanager_notification_latency_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `notifications` | short | `sum by (integration) (rate(alertmanager_notifications_total{job=~"$job"}[$__rate_interval]))` | — |
| `notificationsFailed` | short | `sum by (integration, reason) (rate(alertmanager_notifications_failed_total{job=~"$job"}[$__rate_interval]))` | — |
| `processingAvg` | s | `sum(rate(alertmanager_dispatcher_alert_processing_duration_seconds_sum{job=~"$job"}[$__rate_interval])) / sum(rate(alertmanager_dispatcher_alert_processing_duration_seconds_count{job=~"$job"}[$__rate_interval]))` | — |
| `received` | short | `sum by (status) (rate(alertmanager_alerts_received_total{job=~"$job"}[$__rate_interval]))` | — |
| `receivers` | short | `max(alertmanager_receivers{job=~"$job"})` | — |
| `reloadAge` | dtdurations | `time() - max(alertmanager_config_last_reload_success_timestamp_seconds{job=~"$job"})` | — |
| `reloadOk` | short | `min(alertmanager_config_last_reload_successful{job=~"$job"})` | — |
| `requestsFailed` | short | `sum by (integration) (rate(alertmanager_notification_requests_failed_total{job=~"$job"}[$__rate_interval]))` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job"}` | — |
| `silenceErrors` | short | `sum(rate(alertmanager_silences_query_errors_total{job=~"$job"}[$__rate_interval]))` | — |
| `silences` | short | `sum by (state) (alertmanager_silences{job=~"$job"})` | — |
| `silencesActive` | short | `sum(alertmanager_silences{job=~"$job", state="active"})` | — |
| `suppressed` | short | `sum by (reason) (rate(alertmanager_notifications_suppressed_total{job=~"$job"}[$__rate_interval]))` | — |
| `uptime` | dtdurations | `min(time() - process_start_time_seconds{job=~"$job"})` | — |

## Dashboard

- **Overview** — `ov01_active`, `ov02_suppressed`, `ov03_silences`, `ov04_failureRatio`, `ov05_reloadOk`, `ov06_reloadAge`, `ov07_receivers`, `ov08_integrations`, `ov09_inhibitions`, `ov10_groups`, `ov11_failedPeers`, `ov12_uptime`
- **Alerts** — `aggregationGroups`, `alertsByState`, `invalid`, `processingAvg`, `received`, `silences`
- **Notifications** — `failureRatio`, `notificationP99`, `notifications`, `notificationsFailed`, `requestsFailed`, `suppressed`
- **Cluster** — `clusterFailedPeers`, `clusterHealth`, `clusterMembers`, `clusterQueued`, `clusterReconnectFailed`
- **API & resources** — `cpu`, `httpInFlight`, `httpP99`, `httpRate`, `rss`, `storeErrors`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `AlertmanagerDown` | critical | 5m | — |
| `AlertmanagerFailedReload` | critical | 10m | — |
| `AlertmanagerClusterFailedPeers` | warning | 15m | — |
| `AlertmanagerFailedToSendAlerts` | warning | 5m | — |
| `AlertmanagerClusterFailedToSendAlerts` | critical | 5m | — |
| `AlertmanagerClusterCrashlooping` | critical | 0m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `integration:alertmanager_notifications_failed:ratio_rate5m` | `sum by (integration) (rate(alertmanager_notifications_failed_total[5m])) / sum by (integration) (rate(alertmanager_notifications_total[5m]))` |
| `job:alertmanager_alerts_received:rate5m` | `sum by (job, status) (rate(alertmanager_alerts_received_total[5m]))` |
