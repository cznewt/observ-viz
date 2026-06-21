# etcd  (`g.libs.databases.kv.etcd`)

Dashboard uid `observ-viz-etcd` · 6 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `dbSize` | bytes | `etcd_mvcc_db_total_size_in_bytes{job=~"$job"}` | — |
| `hasLeader` | short | `etcd_server_has_leader{job=~"$job"}` | — |
| `leaderChanges` | short | `rate(etcd_server_leader_changes_seen_total{job=~"$job"}[$__rate_interval])` | — |
| `proposalsCommitted` | ops | `rate(etcd_server_proposals_committed_total{job=~"$job"}[$__rate_interval])` | — |
| `proposalsFailed` | ops | `rate(etcd_server_proposals_failed_total{job=~"$job"}[$__rate_interval])` | `instance:etcd_proposals_failed:rate5m` |
| `walFsyncP99` | s | `histogram_quantile(0.99, sum by (le)(rate(etcd_disk_wal_fsync_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))` | — |

## Dashboard

- **Cluster** — `hasLeader`, `leaderChanges`
- **Operations** — `proposalsCommitted`, `proposalsFailed`
- **Disk** — `dbSize`, `walFsyncP99`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `EtcdNoLeader` | critical | 5m | — |
| `EtcdHighLeaderChanges` | warning | 15m | — |
| `EtcdHighProposalFailures` | warning | 15m | — |
| `EtcdHighWalFsyncDuration` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:etcd_wal_fsync_duration_seconds:p99` | `histogram_quantile(0.99, sum by (le) (rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])))` |
| `instance:etcd_proposals_failed:rate5m` | `rate(etcd_server_proposals_failed_total[5m])` |
