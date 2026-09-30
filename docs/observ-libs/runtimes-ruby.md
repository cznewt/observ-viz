# Ruby runtime  (`g.libs.runtimes.ruby`)

Dashboard uid `observ-viz-ruby` · 18 signals · 5 alerts · 1 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `backlog` | short | `puma_request_backlog{job=~"$job", instance=~"$instance"}` | — |
| `bootedWorkers` | short | `puma_booted_workers{job=~"$job", instance=~"$instance"}` | — |
| `busyThreads` | short | `puma_busy_threads{job=~"$job", instance=~"$instance"}` | — |
| `maxThreads` | short | `puma_max_threads{job=~"$job", instance=~"$instance"}` | — |
| `oldWorkers` | short | `puma_old_workers{job=~"$job", instance=~"$instance"}` | — |
| `poolCapacity` | short | `puma_thread_pool_capacity{job=~"$job", instance=~"$instance"}` | — |
| `runningThreads` | short | `puma_running_threads{job=~"$job", instance=~"$instance"}` | — |
| `sidekiqBacklog` | short | `sidekiq_queue_backlog{job=~"$job", instance=~"$instance"}` | — |
| `sidekiqBusy` | short | `sidekiq_process_busy{job=~"$job", instance=~"$instance"}` | — |
| `sidekiqConcurrency` | short | `sidekiq_process_concurrency{job=~"$job", instance=~"$instance"}` | — |
| `sidekiqDead` | short | `sidekiq_stats_dead_size{job=~"$job", instance=~"$instance"}` | — |
| `sidekiqDuration` | s | `rate(sidekiq_job_duration_seconds_sum{job=~"$job", instance=~"$instance"}[$__rate_interval]) / clamp_min(rate(sidekiq_job_duration_seconds_count{job=~"$job", instance=~"$instance"}[$__rate_interval]), 0.001)` | — |
| `sidekiqEnqueued` | short | `sidekiq_stats_enqueued{job=~"$job", instance=~"$instance"}` | — |
| `sidekiqFailed` | ops | `rate(sidekiq_failed_jobs_total{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `sidekiqJobs` | ops | `rate(sidekiq_jobs_total{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `sidekiqLatency` | s | `sidekiq_queue_latency_seconds{job=~"$job", instance=~"$instance"}` | — |
| `threadUtil` | percent | `100 * puma_busy_threads{job=~"$job", instance=~"$instance"} / clamp_min(puma_max_threads{job=~"$job", instance=~"$instance"}, 1)` | — |
| `workers` | short | `puma_workers{job=~"$job", instance=~"$instance"}` | — |

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
