# MySQL  (`g.libs.databases.sql.mysql`)

Dashboard uid `observ-viz-mysql` · 7 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `bufferPool` | bytes | `mysql_global_status_innodb_buffer_pool_bytes_data{job=~"$job"}` |
| `bytesReceived` | Bps | `rate(mysql_global_status_bytes_received{job=~"$job"}[$__rate_interval])` |
| `bytesSent` | Bps | `rate(mysql_global_status_bytes_sent{job=~"$job"}[$__rate_interval])` |
| `connected` | short | `mysql_global_status_threads_connected{job=~"$job"}` |
| `qps` | ops | `rate(mysql_global_status_queries{job=~"$job"}[$__rate_interval])` |
| `running` | short | `mysql_global_status_threads_running{job=~"$job"}` |
| `slow` | ops | `rate(mysql_global_status_slow_queries{job=~"$job"}[$__rate_interval])` |

## Dashboard

- **Connections** — `connected`, `running`
- **Queries** — `qps`, `slow`
- **InnoDB** — `bufferPool`
- **Traffic** — `bytesReceived`, `bytesSent`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `MysqlDown` | critical | 5m | — |
| `MysqlHighThreadsRunning` | warning | 15m | — |
| `MysqlHighSlowQueries` | warning | 15m | — |
| `MysqlHighConnections` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:mysql_queries:rate5m` | `rate(mysql_global_status_queries[5m])` |
| `instance:mysql_slow_queries:rate5m` | `rate(mysql_global_status_slow_queries[5m])` |
