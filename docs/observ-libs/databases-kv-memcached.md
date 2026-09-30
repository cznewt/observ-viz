# Memcached  (`g.libs.databases.kv.memcached`)

Dashboard uid `observ-viz-memcached` · 10 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `commands` | ops | `sum(rate(memcached_commands_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `connections` | short | `memcached_current_connections{job=~"$job", instance=~"$instance"}` | — |
| `connectionsTotal` | ops | `sum(rate(memcached_connections_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `currentItems` | short | `memcached_current_items{job=~"$job", instance=~"$instance"}` | — |
| `evictions` | ops | `sum(rate(memcached_items_evicted_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `hitRatio` | percentunit | `sum(rate(memcached_slab_lru_hits_total{job=~"$job", instance=~"$instance"}[$__rate_interval])) / (sum(rate(memcached_slab_lru_hits_total{job=~"$job", instance=~"$instance"}[$__rate_interval])) + sum(rate(memcached_slab_lru_misses_total{job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `hits` | ops | `sum(rate(memcached_slab_lru_hits_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `memoryLimit` | bytes | `memcached_limit_bytes{job=~"$job", instance=~"$instance"}` | — |
| `memoryUsed` | bytes | `memcached_current_bytes{job=~"$job", instance=~"$instance"}` | — |
| `misses` | ops | `sum(rate(memcached_slab_lru_misses_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |

## Dashboard

- **Operations** — `commands`, `evictions`
- **Hit ratio** — `hitRatio`, `hits`, `misses`
- **Memory** — `currentItems`, `memoryLimit`, `memoryUsed`
- **Connections** — `connections`, `connectionsTotal`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `MemcachedDown` | critical | 5m | — |
| `MemcachedLowHitRatio` | warning | 15m | — |
| `MemcachedHighMemory` | warning | 15m | — |
| `MemcachedHighEvictions` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:memcached_lru_hit_ratio:rate5m` | `sum without (slab) (rate(memcached_slab_lru_hits_total{}[5m])) / (sum without (slab) (rate(memcached_slab_lru_hits_total{}[5m])) + sum without (slab) (rate(memcached_slab_lru_misses_total{}[5m])))` |
| `instance:memcached_memory_utilisation:ratio` | `memcached_current_bytes / memcached_limit_bytes` |
