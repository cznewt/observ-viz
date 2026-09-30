# Proxmox VE  (`g.libs.system.proxmox`)

Dashboard uid `observ-viz-proxmox` · 15 signals · 3 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `clusterCpuAlloc` | percentunit | `sum by (cluster) (proxmox_cluster_cpus_allocated{cluster=~"$cluster", instance=~"$instance"}) / sum by (cluster) (proxmox_cluster_cpus_total{cluster=~"$cluster", instance=~"$instance"})` | — |
| `clusterMemAlloc` | percentunit | `sum by (cluster) (proxmox_cluster_memory_allocated_bytes{cluster=~"$cluster", instance=~"$instance"}) / sum by (cluster) (proxmox_cluster_memory_total_bytes{cluster=~"$cluster", instance=~"$instance"})` | — |
| `cpu` | percentunit | `1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle", instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `cpuUsed` | percentunit | `1 - avg(rate(node_cpu_seconds_total{mode="idle", instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `hosts` | short | `count(node_uname_info{instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"})` | — |
| `load` | short | `max by (instance) (node_load5{instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"}) / count by (instance) (node_cpu_seconds_total{mode="idle", instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"})` | — |
| `maxTemp` | celsius | `max(node_hwmon_temp_celsius{chip=~".*coretemp.*\|.*k10temp.*\|.*zenpower.*\|.*cpu_thermal.*\|pci0000:00_0000:00:18_3", instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"})` | — |
| `mem` | percentunit | `1 - node_memory_MemAvailable_bytes{instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"} / node_memory_MemTotal_bytes{instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"}` | — |
| `memUsed` | percentunit | `1 - sum(node_memory_MemAvailable_bytes{instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"}) / sum(node_memory_MemTotal_bytes{instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"})` | — |
| `nodeCpuAlloc` | short | `proxmox_node_cpus_allocated{cluster=~"$cluster", instance=~"$instance"}` | — |
| `nodeMemAlloc` | bytes | `proxmox_node_memory_allocated_bytes{cluster=~"$cluster", instance=~"$instance"}` | — |
| `nodeUp` | short | `sum(proxmox_node_up{cluster=~"$cluster", instance=~"$instance"})` | — |
| `rootDisk` | percentunit | `1 - max by (instance) (node_filesystem_avail_bytes{mountpoint="/", instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"} / node_filesystem_size_bytes{mountpoint="/", instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"})` | — |
| `temp` | celsius | `max by (instance) (node_hwmon_temp_celsius{chip=~".*coretemp.*\|.*k10temp.*\|.*zenpower.*\|.*cpu_thermal.*\|pci0000:00_0000:00:18_3", instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"})` | — |
| `uptime` | s | `time() - node_boot_time_seconds{instance=~".*pve.*", cluster=~"$cluster", instance=~"$instance"}` | — |

## Dashboard

- **Overview** — `a_hosts`, `b_temp`, `c_cpu`, `d_mem`
- **Hosts** — `a_temp`, `b_cpu`, `c_load`, `d_mem`, `e_disk`, `f_uptime`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `ProxmoxHostCpuHot` | warning | 10m | — |
| `ProxmoxHostCpuOverheating` | critical | 5m | — |
| `ProxmoxNodeDown` | critical | 5m | — |
