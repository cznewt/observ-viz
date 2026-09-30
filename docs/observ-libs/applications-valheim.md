# Valheim  (`g.libs.applications.valheim`)

Dashboard uid `observ-viz-valheim` · 10 signals · 2 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `containerReady` | short | `max by (container) (kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"$server"})` | — |
| `cpu` | short | `sum by (container) (rate(container_cpu_usage_seconds_total{job=~".*cadvisor", cluster=~"$cluster", namespace=~"$namespace", container=~"$server"}[$__rate_interval]))` | — |
| `exporterUp` | short | `max by (container) (up{cluster=~"$cluster", namespace=~"$namespace", container=~"$server"})` | — |
| `logs` | short | `{cluster=~"$cluster", namespace=~"$namespace", container=~"$server"} !~ "Failed to request server information\|Connections [0-9]+\|[Ss]hader"` | — |
| `memory` | bytes | `sum by (container) (container_memory_working_set_bytes{job=~".*cadvisor", cluster=~"$cluster", namespace=~"$namespace", container=~"$server"})` | — |
| `players` | short | `max by (container) (last_over_time(valheim:connections{cluster=~"$cluster", namespace=~"$namespace", container=~"$server"}[15m]))` | — |
| `playersTotal` | short | `sum(max by (container) (last_over_time(valheim:connections{cluster=~"$cluster", namespace=~"$namespace", container=~"$server"}[15m])))` | — |
| `restarts` | short | `sum by (container) (increase(kube_pod_container_status_restarts_total{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"$server"}[1h]))` | — |
| `restartsRange` | short | `sum(increase(kube_pod_container_status_restarts_total{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"$server"}[$__range]))` | — |
| `serversReady` | short | `sum(max by (container) (kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"$server"}))` | — |

## Dashboard

- **Status** — `s1_ready`, `s2_up`, `s3_players`, `s4_restarts`
- **Players** — `p1_players`
- **Resources** — `r1_cpu`, `r2_memory`, `r3_restarts`, `r4_ready`
- **Logs** — `l1_logs`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `ValheimServerDown` | critical | 5m | — |
| `ValheimServerCrashLooping` | warning | 5m | — |
