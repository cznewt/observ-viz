# Rust runtime  (`g.libs.runtimes.rust`)

Dashboard uid `observ-viz-rust` · 11 signals · 3 alerts · 1 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `busy` | percent | `100 * sum by (instance) (rate(tokio_total_busy_duration{job=~"$job", instance=~"$instance"}[$__rate_interval])) / sum by (instance) (tokio_workers_count{job=~"$job", instance=~"$instance"})` | — |
| `forcedYields` | ops | `rate(tokio_budget_forced_yield_count{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `globalQueue` | short | `tokio_global_queue_depth{job=~"$job", instance=~"$instance"}` | — |
| `ioReady` | ops | `rate(tokio_io_driver_ready_count{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `localQueue` | short | `tokio_total_local_queue_depth{job=~"$job", instance=~"$instance"}` | — |
| `overflows` | ops | `rate(tokio_total_overflow_count{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `parks` | ops | `rate(tokio_total_park_count{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `polls` | ops | `rate(tokio_total_polls_count{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `remoteSchedules` | ops | `rate(tokio_num_remote_schedules{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `steals` | ops | `rate(tokio_total_steal_count{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `workers` | short | `tokio_workers_count{job=~"$job", instance=~"$instance"}` | — |

## Dashboard

- **Tokio runtime** — `busy`, `globalQueue`, `polls`, `workers`
- **Scheduling** — `forcedYields`, `ioReady`, `overflows`, `remoteSchedules`, `steals`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `TokioRuntimeSaturated` | warning | 15m | — |
| `TokioQueueBacklog` | warning | 10m | — |
| `TokioForcedYields` | info | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:tokio_worker_busy:ratio5m` | `sum by (instance, job) (rate(tokio_total_busy_duration[5m])) / sum by (instance, job) (tokio_workers_count)` |
