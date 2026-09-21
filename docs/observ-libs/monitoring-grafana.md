# Grafana  (`g.libs.monitoring.grafana`)

Dashboard uid `observ-viz-grafana` · 44 signals · 5 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `activeUsers` | short | `max(grafana_stat_active_users{job=~"$job"})` | — |
| `alertRules` | short | `sum(grafana_alerting_schedule_alert_rules{job=~"$job"})` | — |
| `alertsActive` | short | `sum(grafana_alerting_active_alerts{job=~"$job"})` | — |
| `alertsReceived` | short | `sum(rate(grafana_alerting_alerts_received_total{job=~"$job"}[$__rate_interval]))` | — |
| `apiStatus` | reqps | `sum by (code) (rate(grafana_api_response_status_total{job=~"$job"}[$__rate_interval]))` | — |
| `cpu` | short | `rate(process_cpu_seconds_total{job=~"$job"}[$__rate_interval])` | — |
| `dbIdle` | short | `grafana_database_conn_idle{job=~"$job"}` | — |
| `dbInUse` | short | `grafana_database_conn_in_use{job=~"$job"}` | — |
| `dbMaxOpen` | short | `grafana_database_conn_max_open{job=~"$job"}` | — |
| `dbOpen` | short | `grafana_database_conn_open{job=~"$job"}` | — |
| `dbWaitRate` | short | `rate(grafana_database_conn_wait_count_total{job=~"$job"}[$__rate_interval])` | — |
| `dbWaitTime` | s | `rate(grafana_database_conn_wait_duration_seconds{job=~"$job"}[$__rate_interval])` | — |
| `dsErrors` | reqps | `sum by (datasource) (rate(grafana_datasource_request_total{job=~"$job", code=~"5.."}[$__rate_interval]))` | — |
| `dsInFlight` | short | `sum(grafana_datasource_request_in_flight{job=~"$job"})` | — |
| `dsP99` | s | `histogram_quantile(0.99, sum by (le, datasource) (rate(grafana_datasource_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `dsRequests` | reqps | `sum by (datasource) (rate(grafana_datasource_request_total{job=~"$job"}[$__rate_interval]))` | — |
| `emailsFailed` | short | `sum(rate(grafana_emails_sent_failed{job=~"$job"}[$__rate_interval]))` | — |
| `evalTime` | ms | `sum(rate(grafana_alerting_execution_time_milliseconds_sum{job=~"$job"}[$__rate_interval])) / sum(rate(grafana_alerting_execution_time_milliseconds_count{job=~"$job"}[$__rate_interval]))` | — |
| `goroutines` | short | `go_goroutines{job=~"$job"}` | — |
| `httpByHandler` | reqps | `topk(10, sum by (handler) (rate(grafana_http_request_duration_seconds_count{job=~"$job"}[$__rate_interval])))` | — |
| `httpErrorRatio` | percentunit | `sum(rate(grafana_http_request_duration_seconds_count{job=~"$job", status_code=~"5.."}[$__rate_interval])) / sum(rate(grafana_http_request_duration_seconds_count{job=~"$job"}[$__rate_interval]))` | — |
| `httpInFlight` | short | `sum(grafana_http_request_in_flight{job=~"$job"})` | — |
| `httpP50` | s | `histogram_quantile(0.50, sum by (le) (rate(grafana_http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `httpP99` | s | `histogram_quantile(0.99, sum by (le) (rate(grafana_http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `httpRate` | reqps | `sum by (status_code) (rate(grafana_http_request_duration_seconds_count{job=~"$job"}[$__rate_interval]))` | — |
| `liveChannels` | short | `sum(grafana_live_node_num_channels{job=~"$job"})` | — |
| `liveClients` | short | `sum(grafana_live_node_num_clients{job=~"$job"})` | — |
| `liveSent` | short | `sum(rate(grafana_live_node_messages_sent_count{job=~"$job"}[$__rate_interval]))` | — |
| `notifLatencyP99` | s | `histogram_quantile(0.99, sum by (le) (rate(grafana_alerting_notification_latency_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `pageStatus` | reqps | `sum by (code) (rate(grafana_page_response_status_total{job=~"$job"}[$__rate_interval]))` | — |
| `pluginP99` | s | `histogram_quantile(0.99, sum by (le) (rate(grafana_plugin_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `pluginRequests` | reqps | `sum by (plugin_id) (rate(grafana_plugin_request_total{job=~"$job"}[$__rate_interval]))` | — |
| `proxyStatus` | reqps | `sum by (code) (rate(grafana_proxy_response_status_total{job=~"$job"}[$__rate_interval]))` | — |
| `renderingQueue` | short | `sum(grafana_rendering_queue_size{job=~"$job"})` | — |
| `restarts` | short | `sum(increase(grafana_instance_start_total{job=~"$job"}[1h]))` | — |
| `rss` | bytes | `process_resident_memory_bytes{job=~"$job"}` | — |
| `schedulerBehind` | s | `max(grafana_alerting_scheduler_behind_seconds{job=~"$job"})` | — |
| `totalAlertRules` | short | `max(grafana_stat_totals_alert_rules{job=~"$job"})` | — |
| `totalDashboards` | short | `max(grafana_stat_totals_dashboard{job=~"$job"})` | — |
| `totalDatasources` | short | `max(grafana_stat_totals_datasource{job=~"$job"})` | — |
| `totalFolders` | short | `max(grafana_stat_totals_folder{job=~"$job"})` | — |
| `totalOrgs` | short | `max(grafana_stat_total_orgs{job=~"$job"})` | — |
| `totalUsers` | short | `max(grafana_stat_total_users{job=~"$job"})` | — |
| `uptime` | s | `time() - process_start_time_seconds{job=~"$job"}` | — |

## Dashboard

- **Requests** — `apiStatus`, `httpByHandler`, `httpErrorRatio`, `httpInFlight`, `httpP50`, `httpP99`, `httpRate`, `pageStatus`
- **Datasources & plugins** — `dsErrors`, `dsInFlight`, `dsP99`, `dsRequests`, `pluginP99`, `pluginRequests`, `proxyStatus`
- **Alerting** — `alertRules`, `alertsActive`, `alertsReceived`, `evalTime`, `notifLatencyP99`, `schedulerBehind`
- **Database** — `dbIdle`, `dbInUse`, `dbMaxOpen`, `dbOpen`, `dbWaitRate`, `dbWaitTime`
- **Live & rendering** — `emailsFailed`, `liveChannels`, `liveClients`, `liveSent`, `renderingQueue`
- **Totals** — `activeUsers`, `totalAlertRules`, `totalDashboards`, `totalDatasources`, `totalFolders`, `totalOrgs`, `totalUsers`
- **Resources** — `cpu`, `goroutines`, `restarts`, `rss`, `uptime`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `GrafanaDown` | critical | 5m | — |
| `GrafanaHttpErrorRatioHigh` | warning | 15m | — |
| `GrafanaHttpLatencyHigh` | warning | 15m | — |
| `GrafanaDatabaseConnectionWait` | warning | 15m | — |
| `GrafanaAlertingSchedulerBehind` | warning | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:grafana_http_requests:rate5m` | `sum by (instance) (rate(grafana_http_request_duration_seconds_count[5m]))` |
| `instance:grafana_http_errors:ratio_rate5m` | `sum by (instance) (rate(grafana_http_request_duration_seconds_count{status_code=~"5.."}[5m])) / sum by (instance) (rate(grafana_http_request_duration_seconds_count[5m]))` |
