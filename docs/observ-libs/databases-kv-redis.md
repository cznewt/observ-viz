# Redis  (`g.libs.databases.kv.redis`)

Dashboard uid `observ-viz-redis` · 6 signals · 4 alerts · 2 recording rules.

## Signals

| Signal | Unit | Expression |
|--------|------|------------|
| `blockedClients` | short | `redis_blocked_clients{job=~"$job"}` |
| `commands` | ops | `rate(redis_commands_processed_total{job=~"$job"}[$__rate_interval])` |
| `connectedClients` | short | `redis_connected_clients{job=~"$job"}` |
| `evictions` | short | `rate(redis_evicted_keys_total{job=~"$job"}[$__rate_interval])` |
| `hitRatio` | percentunit | `sum(rate(redis_keyspace_hits_total{job=~"$job"}[$__rate_interval])) / (sum(rate(redis_keyspace_hits_total{job=~"$job"}[$__rate_interval])) + sum(rate(redis_keyspace_misses_total{job=~"$job"}[$__rate_interval])))` |
| `memoryUsed` | bytes | `redis_memory_used_bytes{job=~"$job"}` |

## Dashboard

- **Clients** — `blockedClients`, `connectedClients`
- **Operations** — `commands`
- **Hit ratio** — `hitRatio`
- **Memory** — `evictions`, `memoryUsed`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `RedisDown` | critical | 5m | — |
| `RedisHighMemory` | warning | 15m | — |
| `RedisTooManyBlockedClients` | warning | 15m | — |
| `RedisHighEvictionRate` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:redis_keyspace_hit_ratio:ratio` | `sum without (db) (rate(redis_keyspace_hits_total[5m])) / (sum without (db) (rate(redis_keyspace_hits_total[5m])) + sum without (db) (rate(redis_keyspace_misses_total[5m])))` |
| `instance:redis_commands:rate5m` | `rate(redis_commands_processed_total[5m])` |
