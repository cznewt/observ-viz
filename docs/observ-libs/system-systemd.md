# systemd units  (`g.libs.system.systemd`)

Dashboard uid `observ-viz-systemd` · 9 signals · 3 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `active` | short | `count(node_systemd_unit_state{name=~".*", state="active", cluster=~"$cluster", instance=~"$instance"} == 1) or vector(0)` | — |
| `failed` | short | `count(node_systemd_unit_state{name=~".*", state="failed", cluster=~"$cluster", instance=~"$instance"} == 1) or vector(0)` | — |
| `failedTable` | short | `node_systemd_unit_state{name=~".*", state="failed", cluster=~"$cluster", instance=~"$instance"} == 1` | — |
| `hosts` | short | `count(count by (instance) (node_systemd_unit_state{name=~".*", cluster=~"$cluster", instance=~"$instance"}))` | — |
| `inactive` | short | `count(node_systemd_unit_state{name=~".*", state="inactive", cluster=~"$cluster", instance=~"$instance"} == 1) or vector(0)` | — |
| `restarts` | short | `sum by (instance, name) (increase(node_systemd_service_restart_total{name=~".*", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `running` | short | `node_systemd_system_running{cluster=~"$cluster", instance=~"$instance"}` | — |
| `state` | short | `max by (instance, name) ((node_systemd_unit_state{name=~".*", state="active", cluster=~"$cluster", instance=~"$instance"} == 1) * 1 or (node_systemd_unit_state{name=~".*", state=~"activating\|deactivating", cluster=~"$cluster", instance=~"$instance"} == 1) * 2 or (node_systemd_unit_state{name=~".*", state="inactive", cluster=~"$cluster", instance=~"$instance"} == 1) * 3 or (node_systemd_unit_state{name=~".*", state="failed", cluster=~"$cluster", instance=~"$instance"} == 1) * 4)` | — |
| `unitsByState` | short | `sum by (state) (node_systemd_units{cluster=~"$cluster", instance=~"$instance"})` | — |

## Dashboard

- **Overview** — `s01_active`, `s02_failed`, `s03_inactive`, `s04_hosts`, `s05_system`
- **Units** — `s11_state`
- **Detail** — `s21_restarts`, `s22_failedTable`, `s23_byState`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `SystemdUnitFailed` | critical | 5m | — |
| `SystemdUnitRestarting` | warning | 0m | — |
| `SystemdSystemDegraded` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:node_systemd_units_failed:count` | `count by (instance) (node_systemd_unit_state{state="failed"} == 1)` |
| `instance:node_systemd_units_active:count` | `count by (instance) (node_systemd_unit_state{state="active"} == 1)` |
