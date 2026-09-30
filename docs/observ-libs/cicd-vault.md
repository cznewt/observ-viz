# Vault  (`g.libs.cicd.vault`)

Dashboard uid `observ-viz-vault` · 24 signals · 3 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `active` | short | `sum(vault_core_active{job=~"$job", cluster=~"$cluster", instance=~"$instance"}) or vector(0)` | — |
| `allocBytes` | bytes | `vault_runtime_alloc_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `auditFailures` | short | `sum by (instance) (increase({__name__=~"vault_audit_log_(request\|response)_failure", job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `barrierDelete` | ms | `max by (instance) (vault_barrier_delete{quantile="0.99", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `barrierGet` | ms | `max by (instance) (vault_barrier_get{quantile="0.99", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `barrierGetOps` | ops | `sum by (instance) (rate(vault_barrier_get_count{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `barrierList` | ms | `max by (instance) (vault_barrier_list{quantile="0.99", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `barrierPut` | ms | `max by (instance) (vault_barrier_put{quantile="0.99", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `barrierPutOps` | ops | `sum by (instance) (rate(vault_barrier_put_count{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `gcPause` | ns | `max by (instance) (vault_runtime_gc_pause_ns{quantile="0.99", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `goroutines` | short | `vault_runtime_num_goroutines{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `irrevocable` | short | `sum by (instance) (vault_expire_num_irrevocable_leases{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `leases` | short | `sum by (instance) (vault_expire_num_leases{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `loginP99` | ms | `max by (instance) (vault_core_handle_login_request{quantile="0.99", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `logins` | ops | `sum by (instance) (rate(vault_core_handle_login_request_count{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `requestP99` | ms | `max by (instance) (vault_core_handle_request{quantile="0.99", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `requests` | ops | `sum by (instance) (rate(vault_core_handle_request_count{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `sealState` | short | `vault_core_unsealed{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `sealed` | short | `count(vault_core_unsealed{job=~"$job", cluster=~"$cluster", instance=~"$instance"} == 0) or vector(0)` | — |
| `sysBytes` | bytes | `vault_runtime_sys_bytes{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `tokenCreation` | ops | `sum by (instance) (rate(vault_token_creation{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `tokensByAuth` | short | `sum by (auth_method) (vault_token_count{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `unsealed` | short | `sum(vault_core_unsealed{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `uptime` | s | `time() - max(process_start_time_seconds{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |

## Dashboard

- **Overview** — `a_sealed`, `b_unsealed`, `c_active`, `d_uptime`
- **Seal state & runtime** — `a_seal`, `b_memory`, `c_goroutines`, `d_gc`
- **Barrier** — `a_latency`, `b_ops`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `VaultDown` | critical | 5m | — |
| `VaultSealed` | critical | 5m | — |
| `VaultAuditLogFailures` | critical | 1m | — |
