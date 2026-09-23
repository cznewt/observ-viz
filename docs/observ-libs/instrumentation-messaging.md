# Queues and background work  (`g.libs.instrumentation.messaging`)

Dashboard uid `observ-viz-messaging` · 14 signals · 5 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `activeConsumers` | short | `sum(celery_active_consumer_count{job=~"$job"})` | — |
| `activeProcesses` | short | `sum(celery_active_process_count{job=~"$job"})` | — |
| `activeWorkers` | short | `sum(celery_active_worker_count{job=~"$job"})` | — |
| `lag` | short | `sum by (consumergroup, topic) (kafka_consumergroup_lag{job=~"$job"})` | — |
| `lagSum` | short | `sum(kafka_consumergroup_lag{job=~"$job"})` | — |
| `members` | short | `sum by (consumergroup) (kafka_consumergroup_members{job=~"$job"})` | — |
| `offsetRate` | ops | `sum by (consumergroup, topic) (rate(kafka_consumergroup_current_offset{job=~"$job"}[$__rate_interval]))` | — |
| `queueLength` | short | `celery_queue_length{job=~"$job"}` | — |
| `queueWait` | s | `histogram_quantile(0.95, sum by (le, queue_name) (rate(celery_task_queue_wait_time_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `taskRuntime` | s | `histogram_quantile(0.95, sum by (le, name) (rate(celery_task_runtime_bucket{job=~"$job"}[$__rate_interval])))` | — |
| `tasksFailed` | ops | `sum by (name) (rate(celery_task_failed_total{job=~"$job"}[$__rate_interval]))` | — |
| `tasksRetried` | ops | `sum(rate(celery_task_retried_total{job=~"$job"}[$__rate_interval]))` | — |
| `tasksSucceeded` | ops | `sum(rate(celery_task_succeeded_total{job=~"$job"}[$__rate_interval]))` | — |
| `workers` | short | `sum(celery_worker_up{job=~"$job"})` | — |

## Dashboard

- **Overview** — `ov1_workers`, `ov2_active`, `ov3_failed`, `ov4_lag`
- **Celery** — `queueLength`, `queueWait`, `taskRuntime`, `tasks`, `tasksFailed`, `workers`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `CeleryWorkersDown` | critical | 10m | — |
| `CeleryQueueBacklog` | warning | 15m | — |
| `CeleryTasksFailing` | warning | 15m | — |
| `KafkaConsumerGroupLagGrowing` | warning | 15m | — |
| `KafkaConsumerGroupEmpty` | critical | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `job_queue:celery_queue_length:max` | `max by (job, queue_name) (celery_queue_length)` |
| `job_group:kafka_consumergroup_lag:sum` | `sum by (job, consumergroup) (kafka_consumergroup_lag)` |
