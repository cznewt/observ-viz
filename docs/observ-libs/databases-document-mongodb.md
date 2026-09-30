# MongoDB  (`g.libs.databases.document.mongodb`)

Dashboard uid `observ-viz-mongodb` · 38 signals · 7 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `asserts` | ops | `sum by (assert_type) (rate(mongodb_ss_asserts{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `cacheDirty` | percentunit | `sum by (instance) (mongodb_ss_wt_cache_tracked_dirty_bytes_in_the_cache{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) / sum by (instance) (mongodb_ss_wt_cache_maximum_bytes_configured{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `cacheUsed` | percentunit | `sum by (instance) (mongodb_ss_wt_cache_bytes_currently_in_the_cache{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) / sum by (instance) (mongodb_ss_wt_cache_maximum_bytes_configured{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `connectionUsage` | percentunit | `sum by (instance) (mongodb_ss_connections{conn_type="current", job=~"$job", cluster=~"$cluster", instance=~"$instance"}) / (sum by (instance) (mongodb_ss_connections{conn_type="current", job=~"$job", cluster=~"$cluster", instance=~"$instance"}) + sum by (instance) (mongodb_ss_connections{conn_type="available", job=~"$job", cluster=~"$cluster", instance=~"$instance"}))` | — |
| `connections` | short | `sum(mongodb_ss_connections{conn_type="current", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `connectionsPerInstance` | short | `sum by (instance) (mongodb_ss_connections{conn_type="current", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `cursorTimeouts` | ops | `sum by (instance) (rate(mongodb_ss_metrics_cursor_timedOut{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `cursors` | short | `sum by (csr_type) (mongodb_ss_metrics_cursor_open{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `dataSize` | bytes | `mongodb_dbstats_dataSize{database!~"admin\|config\|local", job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `documents` | ops | `sum by (doc_op_type) (rate(mongodb_ss_metrics_document{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `indexSize` | bytes | `mongodb_dbstats_indexSize{database!~"admin\|config\|local", job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `lag` | s | `(max by (cluster, rs_nm) (mongodb_rs_members_optimeDate{member_state="PRIMARY", job=~"$job", cluster=~"$cluster", instance=~"$instance"}) - on (cluster, rs_nm) group_right max by (cluster, rs_nm, member_idx) (mongodb_rs_members_optimeDate{member_state="SECONDARY", job=~"$job", cluster=~"$cluster", instance=~"$instance"})) / 1000` | — |
| `latencyByType` | s | `sum by (op_type) (rate(mongodb_ss_opLatencies_latency{op_type!="transactions", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / sum by (op_type) (rate(mongodb_ss_opLatencies_ops{op_type!="transactions", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / 1e6` | — |
| `memberState` | short | `max by (instance) (mongodb_rs_myState{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `members` | short | `count(max by (cluster, rs_nm, member_idx) (mongodb_rs_members_health{job=~"$job", cluster=~"$cluster", instance=~"$instance"}))` | — |
| `netIn` | Bps | `sum by (instance) (rate(mongodb_ss_network_bytesIn{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `netOut` | Bps | `sum by (instance) (rate(mongodb_ss_network_bytesOut{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `objects` | short | `mongodb_dbstats_objects{database!~"admin\|config\|local", job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `oplogWindow` | s | `max by (instance) (mongodb_mongod_replset_oplog_head_timestamp{job=~"$job", cluster=~"$cluster", instance=~"$instance"} - mongodb_mongod_replset_oplog_tail_timestamp{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `ops` | ops | `sum(rate(mongodb_ss_opcounters{legacy_op_type!="command", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `opsByType` | ops | `sum by (legacy_op_type) (rate(mongodb_ss_opcounters{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `pageFaults` | ops | `sum by (instance) (rate(mongodb_ss_extra_info_page_faults{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `pagesRead` | ops | `sum by (instance) (rate(mongodb_ss_wt_cache_pages_read_into_cache{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `pagesWritten` | ops | `sum by (instance) (rate(mongodb_ss_wt_cache_pages_written_from_cache{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `queued` | short | `sum by (count_type) (mongodb_ss_globalLock_currentQueue{count_type!="total", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `readLatency` | s | `sum(rate(mongodb_ss_opLatencies_latency{op_type="reads", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / sum(rate(mongodb_ss_opLatencies_ops{op_type="reads", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / 1e6` | — |
| `replOps` | ops | `sum by (legacy_op_type) (rate(mongodb_ss_opcountersRepl{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `resident` | bytes | `sum by (instance) (mongodb_ss_mem_resident{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) * 1048576` | — |
| `scannedKeys` | short | `sum(rate(mongodb_ss_metrics_queryExecutor_scanned{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / sum(rate(mongodb_ss_metrics_document{doc_op_type="returned", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `scannedObjects` | short | `sum(rate(mongodb_ss_metrics_queryExecutor_scannedObjects{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / sum(rate(mongodb_ss_metrics_document{doc_op_type="returned", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `sinceElection` | s | `time() - max(mongodb_rs_members_electionDate{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) / 1000` | — |
| `storageSize` | bytes | `mongodb_dbstats_storageSize{database!~"admin\|config\|local", job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `tickets` | short | `sum by (txn_rw) (mongodb_ss_wt_concurrentTransactions_out{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `ttlDeletes` | ops | `sum by (instance) (rate(mongodb_ss_metrics_ttl_deletedDocuments{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `unhealthy` | short | `count(min by (cluster, rs_nm, member_idx) (mongodb_rs_members_health{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) == 0) or vector(0)` | — |
| `up` | short | `sum(mongodb_up{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `uptime` | s | `min(mongodb_ss_uptime{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `writeLatency` | s | `sum(rate(mongodb_ss_opLatencies_latency{op_type="writes", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / sum(rate(mongodb_ss_opLatencies_ops{op_type="writes", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])) / 1e6` | — |

## Dashboard

- **Overview** — `a_up`, `b_ops`, `c_connections`, `d_read`, `e_write`, `f_uptime`
- **Operations** — `a_ops`, `b_repl`, `c_docs`, `d_latency`, `e_efficiency`, `f_ttl`
- **Connections & cursors** — `a_connections`, `b_usage`, `c_cursors`, `d_timeouts`, `e_queued`, `f_tickets`
- **Resources** — `a_resident`, `b_cache`, `c_pages`, `d_network`, `e_asserts`, `f_faults`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `MongodbDown` | critical | 1m | — |
| `MongodbReplicaMemberUnhealthy` | critical | 1m | — |
| `MongodbReplicationLag` | critical | 2m | — |
| `MongodbReplicationHeadroom` | critical | 0m | — |
| `MongodbNumberCursorsOpen` | warning | 2m | — |
| `MongodbCursorsTimeouts` | warning | 2m | — |
| `MongodbTooManyConnections` | warning | 2m | — |
