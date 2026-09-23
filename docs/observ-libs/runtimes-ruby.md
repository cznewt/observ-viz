# Ruby runtime  (`g.libs.runtimes.ruby`)

Dashboard uid `observ-viz-ruby` · 18 signals · 5 alerts · 1 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `backlog` | short | `puma_request_backlog{job=~"$job"}` | — |
| `bootedWorkers` | short | `puma_booted_workers{job=~"$job"}` | — |
| `busyThreads` | short | `puma_busy_threads{job=~"$job"}` | — |
| `maxThreads` | short | `puma_max_threads{job=~"$job"}` | — |
| `oldWorkers` | short | `puma_old_workers{job=~"$job"}` | — |
| `poolCapacity` | short | `puma_thread_pool_capacity{job=~"$job"}` | — |
| `runningThreads` | short | `puma_running_threads{job=~"$job"}` | — |
| `sidekiqBacklog` | short | `sidekiq_queue_backlog{job=~"$job"}` | — |
| `sidekiqBusy` | short | `sidekiq_process_busy{job=~"$job"}` | — |
| `sidekiqConcurrency` | short | `sidekiq_process_concurrency{job=~"$job"}` | — |
| `sidekiqDead` | short | `sidekiq_stats_dead_size{job=~"$job"}` | — |
| `sidekiqDuration` | s | `rate(sidekiq_job_duration_seconds_sum{job=~"$job"}[$__rate_interval]) / clamp_min(rate(sidekiq_job_duration_seconds_count{job=~"$job"}[$__rate_interval]), 0.001)` | — |
| `sidekiqEnqueued` | short | `sidekiq_stats_enqueued{job=~"$job"}` | — |
| `sidekiqFailed` | ops | `rate(sidekiq_failed_jobs_total{job=~"$job"}[$__rate_interval])` | — |
| `sidekiqJobs` | ops | `rate(sidekiq_jobs_total{job=~"$job"}[$__rate_interval])` | — |
| `sidekiqLatency` | s | `sidekiq_queue_latency_seconds{job=~"$job"}` | — |
| `threadUtil` | percent | `100 * puma_busy_threads{job=~"$job"} / clamp_min(puma_max_threads{job=~"$job"}, 1)` | — |
| `workers` | short | `puma_workers{job=~"$job"}` | — |

## Dashboard

- **Puma** — `backlog`, `threadUtil`, `threads`, `workers`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `PumaThreadPoolSaturated` | warning | 10m | — |
| `PumaRequestBacklog` | warning | 10m | — |
| `SidekiqQueueLatencyHigh` | warning | 15m | — |
| `SidekiqJobsFailing` | warning | 15m | — |
| `SidekiqDeadJobsGrowing` | info | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:puma_thread_usage:ratio` | `puma_busy_threads / clamp_min(puma_max_threads, 1)` |
