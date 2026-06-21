# Docker containers  (`g.libs.system.docker`)

Dashboard uid `observ-viz-docker` · 7 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `cpu` | short | `sum by (name)(rate(container_cpu_usage_seconds_total{job=~"$job",name!=""}[$__rate_interval]))` | — |
| `diskRead` | Bps | `rate(container_fs_reads_bytes_total{job=~"$job",name!=""}[$__rate_interval])` | — |
| `diskWrite` | Bps | `rate(container_fs_writes_bytes_total{job=~"$job",name!=""}[$__rate_interval])` | — |
| `memUsage` | bytes | `container_memory_usage_bytes{job=~"$job",name!=""}` | — |
| `memWorkingSet` | bytes | `container_memory_working_set_bytes{job=~"$job",name!=""}` | — |
| `netRx` | Bps | `rate(container_network_receive_bytes_total{job=~"$job",name!=""}[$__rate_interval])` | — |
| `netTx` | Bps | `rate(container_network_transmit_bytes_total{job=~"$job",name!=""}[$__rate_interval])` | — |

## Dashboard

- **CPU** — `cpu`
- **Memory** — `memUsage`, `memWorkingSet`
- **Network** — `netRx`, `netTx`
- **Disk IO** — `diskRead`, `diskWrite`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `CadvisorDown` | critical | 5m | — |
| `ContainerHighCpu` | warning | 15m | — |
| `ContainerHighMemory` | warning | 15m | — |
| `ContainerHighDiskWrite` | warning | 15m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance_name:container_cpu_usage:rate5m` | `sum by (name) (rate(container_cpu_usage_seconds_total{name!=""}[5m]))` |
| `instance_name:container_memory_working_set_bytes:sum` | `sum by (name) (container_memory_working_set_bytes{name!=""})` |
