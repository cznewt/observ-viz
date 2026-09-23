# BEAM runtime  (`g.libs.runtimes.beam`)

Dashboard uid `observ-viz-beam` · 24 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `atomLimit` | short | `erlang_vm_atom_limit{job=~"$job"}` | — |
| `atomUtil` | percent | `100 * erlang_vm_atoms{job=~"$job"} / clamp_min(erlang_vm_atom_limit{job=~"$job"}, 1)` | — |
| `atoms` | short | `erlang_vm_atoms{job=~"$job"}` | — |
| `bytesIn` | Bps | `rate(erlang_vm_statistics_bytes_received_total{job=~"$job"}[$__rate_interval])` | — |
| `bytesOut` | Bps | `rate(erlang_vm_statistics_bytes_output_total{job=~"$job"}[$__rate_interval])` | — |
| `contextSwitches` | ops | `rate(erlang_vm_statistics_context_switches{job=~"$job"}[$__rate_interval])` | — |
| `etsTables` | short | `erlang_vm_ets_tables{job=~"$job"}` | — |
| `gcReclaimed` | Bps | `rate(erlang_vm_statistics_garbage_collection_bytes_reclaimed{job=~"$job"}[$__rate_interval])` | — |
| `gcs` | ops | `rate(erlang_vm_statistics_garbage_collection_number_of_gcs{job=~"$job"}[$__rate_interval])` | — |
| `memAtom` | bytes | `erlang_vm_memory_atom_bytes{job=~"$job"}` | — |
| `memEts` | bytes | `erlang_vm_memory_ets_tables{job=~"$job"}` | — |
| `memProcesses` | bytes | `erlang_vm_memory_processes_bytes{job=~"$job"}` | — |
| `memSystem` | bytes | `erlang_vm_memory_system_bytes{job=~"$job"}` | — |
| `memory` | bytes | `erlang_vm_memory_bytes_total{job=~"$job"}` | — |
| `portLimit` | short | `erlang_vm_port_limit{job=~"$job"}` | — |
| `portUtil` | percent | `100 * erlang_vm_ports{job=~"$job"} / clamp_min(erlang_vm_port_limit{job=~"$job"}, 1)` | — |
| `ports` | short | `erlang_vm_ports{job=~"$job"}` | — |
| `processLimit` | short | `erlang_vm_process_limit{job=~"$job"}` | — |
| `processUtil` | percent | `100 * erlang_vm_processes{job=~"$job"} / clamp_min(erlang_vm_process_limit{job=~"$job"}, 1)` | — |
| `processes` | short | `erlang_vm_processes{job=~"$job"}` | — |
| `reductions` | ops | `rate(erlang_vm_statistics_reductions_total{job=~"$job"}[$__rate_interval])` | — |
| `runQueueDirtyCpu` | short | `erlang_vm_statistics_dirty_cpu_run_queue_length{job=~"$job"}` | — |
| `runQueueDirtyIo` | short | `erlang_vm_statistics_dirty_io_run_queue_length{job=~"$job"}` | — |
| `schedulers` | short | `erlang_vm_logical_processors_online{job=~"$job"}` | — |

## Dashboard

- **Overview** — `ov1_processes`, `ov2_processUtil`, `ov3_portUtil`, `ov4_atomUtil`, `ov5_ets`, `ov6_schedulers`
- **Memory** — `memAtom`, `memProcesses`, `memSystem`, `memory`
- **Limits** — `atoms`, `etsTables`, `ports`, `processes`
- **Schedulers and work** — `contextSwitches`, `gcs`, `reductions`, `runQueues`, `traffic`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `BeamProcessLimitNear` | warning | 10m | — |
| `BeamPortLimitNear` | warning | 10m | — |
| `BeamAtomLimitNear` | critical | 30m | — |
| `BeamRunQueueBacklog` | warning | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:erlang_vm_process_usage:ratio` | `erlang_vm_processes / clamp_min(erlang_vm_process_limit, 1)` |
| `instance:erlang_vm_memory_bytes:sum` | `sum by (instance, job) (erlang_vm_memory_bytes_total)` |
