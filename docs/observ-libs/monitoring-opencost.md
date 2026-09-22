# OpenCost  (`g.libs.monitoring.opencost`)

Dashboard uid `observ-viz-opencost` · 21 signals · 3 alerts · 3 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `clusterHourly` | currencyUSD | `sum(node_total_hourly_cost{cluster=~"$cluster"}) + sum(kubecost_cluster_management_cost{cluster=~"$cluster"} or vector(0)) + sum(pv_hourly_cost{cluster=~"$cluster"} or vector(0))` | — |
| `clusterMonthly` | currencyUSD | `(sum(node_total_hourly_cost{cluster=~"$cluster"}) + sum(kubecost_cluster_management_cost{cluster=~"$cluster"} or vector(0)) + sum(pv_hourly_cost{cluster=~"$cluster"} or vector(0))) * 730` | — |
| `cpuAllocByNode` | short | `sum by (node) (container_cpu_allocation{cluster=~"$cluster"})` | — |
| `cpuAllocated` | short | `sum(container_cpu_allocation{cluster=~"$cluster"})` | — |
| `egress` | currencyUSD | `sum(kubecost_network_internet_egress_cost{cluster=~"$cluster"}) + sum(kubecost_network_region_egress_cost{cluster=~"$cluster"}) + sum(kubecost_network_zone_egress_cost{cluster=~"$cluster"})` | — |
| `managementFee` | currencyUSD | `sum(kubecost_cluster_management_cost{cluster=~"$cluster"})` | — |
| `nodeCpu` | currencyUSD | `node_cpu_hourly_cost{cluster=~"$cluster"}` | — |
| `nodeRam` | currencyUSD | `node_ram_hourly_cost{cluster=~"$cluster"}` | — |
| `nodeTotal` | currencyUSD | `node_total_hourly_cost{cluster=~"$cluster"}` | — |
| `nodes` | short | `count(node_total_hourly_cost{cluster=~"$cluster"})` | — |
| `nsCpuCost` | currencyUSD | `sum by (namespace) (container_cpu_allocation{cluster=~"$cluster"} * on (node) group_left () node_cpu_hourly_cost{cluster=~"$cluster"})` | `namespace:opencost_cpu_cost:hourly` |
| `nsRamCost` | currencyUSD | `sum by (namespace) (container_memory_allocation_bytes{cluster=~"$cluster"} / 1024 / 1024 / 1024 * on (node) group_left () node_ram_hourly_cost{cluster=~"$cluster"})` | `namespace:opencost_memory_cost:hourly` |
| `nsTopMonthly` | currencyUSD | `topk(10, ((sum by (namespace) (container_cpu_allocation{cluster=~"$cluster"} * on (node) group_left () node_cpu_hourly_cost{cluster=~"$cluster"})) + (sum by (namespace) (container_memory_allocation_bytes{cluster=~"$cluster"} / 1024 / 1024 / 1024 * on (node) group_left () node_ram_hourly_cost{cluster=~"$cluster"}))) * 730)` | — |
| `nsTotalCost` | currencyUSD | `(sum by (namespace) (container_cpu_allocation{cluster=~"$cluster"} * on (node) group_left () node_cpu_hourly_cost{cluster=~"$cluster"})) + (sum by (namespace) (container_memory_allocation_bytes{cluster=~"$cluster"} / 1024 / 1024 / 1024 * on (node) group_left () node_ram_hourly_cost{cluster=~"$cluster"}))` | — |
| `pvCost` | currencyUSD | `sum by (persistentvolume) (pv_hourly_cost{cluster=~"$cluster"})` | — |
| `pvTotal` | currencyUSD | `sum(pv_hourly_cost{cluster=~"$cluster"})` | — |
| `pvcByNamespace` | currencyUSD | `sum by (namespace) (pod_pvc_allocation{cluster=~"$cluster"} / 1024 / 1024 / 1024 * on (persistentvolume) group_left () pv_hourly_cost{cluster=~"$cluster"})` | — |
| `ramAllocByNode` | bytes | `sum by (node) (container_memory_allocation_bytes{cluster=~"$cluster"})` | — |
| `ramAllocated` | bytes | `sum(container_memory_allocation_bytes{cluster=~"$cluster"})` | — |
| `spotNodes` | short | `sum(kubecost_node_is_spot{cluster=~"$cluster"})` | — |
| `version` | short | `max by (version) (opencost_build_info{cluster=~"$cluster"})` | — |

## Dashboard

- **Overview** — `ov01_hourly`, `ov02_monthly`, `ov03_nodes`, `ov04_spot`, `ov05_cpu`, `ov06_ram`, `ov07_pv`, `ov08_fee`, `ov09_egress`
- **Namespaces** — `nsCpuCost`, `nsRamCost`, `nsTopMonthly`, `nsTotalCost`, `pvcByNamespace`
- **Nodes** — `cpuAllocByNode`, `nodeRates`, `nodeTotal`, `pvCost`, `ramAllocByNode`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `OpencostDown` | warning | 10m | — |
| `OpencostNoNodeCostData` | warning | 30m | — |
| `OpencostClusterCostJump` | warning | 1h | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `namespace:opencost_cpu_cost:hourly` | `sum by (namespace) (container_cpu_allocation * on (node) group_left () node_cpu_hourly_cost)` |
| `namespace:opencost_memory_cost:hourly` | `sum by (namespace) (container_memory_allocation_bytes / 1024 / 1024 / 1024 * on (node) group_left () node_ram_hourly_cost)` |
| `cluster:opencost_total_cost:hourly` | `sum(node_total_hourly_cost) + sum(pv_hourly_cost or vector(0))` |
