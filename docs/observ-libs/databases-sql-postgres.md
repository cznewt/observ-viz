# PostgreSQL  (`g.libs.databases.sql.postgres`)

Dashboard uid `observ-viz-postgres` · 6 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `backends` | short | `sum by (datname)(pg_stat_database_numbackends{job=~"$job"})` | — |
| `cacheHitRatio` | percentunit | `sum(rate(pg_stat_database_blks_hit{job=~"$job"}[$__rate_interval])) / (sum(rate(pg_stat_database_blks_hit{job=~"$job"}[$__rate_interval])) + sum(rate(pg_stat_database_blks_read{job=~"$job"}[$__rate_interval])))` | — |
| `commits` | ops | `sum(rate(pg_stat_database_xact_commit{job=~"$job"}[$__rate_interval]))` | — |
| `databaseSize` | bytes | `pg_database_size_bytes{job=~"$job"}` | — |
| `deadlocks` | ops | `sum(rate(pg_stat_database_deadlocks{job=~"$job"}[$__rate_interval]))` | — |
| `rollbacks` | ops | `sum(rate(pg_stat_database_xact_rollback{job=~"$job"}[$__rate_interval]))` | — |

## Dashboard

- **Connections** — `backends`
- **Throughput** — `commits`, `rollbacks`
- **Cache** — `cacheHitRatio`
- **Size** — `databaseSize`, `deadlocks`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `PostgresDown` | critical | 5m | — |
| `PostgresHighRollbackRate` | warning | 15m | — |
| `PostgresLowCacheHitRatio` | warning | 15m | — |
| `PostgresDeadlocks` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:pg_cache_hit_ratio:ratio5m` | `sum without (datname) (rate(pg_stat_database_blks_hit[5m])) / (sum without (datname) (rate(pg_stat_database_blks_hit[5m])) + sum without (datname) (rate(pg_stat_database_blks_read[5m])))` |
| `instance:pg_commits:rate5m` | `sum without (datname) (rate(pg_stat_database_xact_commit[5m]))` |
