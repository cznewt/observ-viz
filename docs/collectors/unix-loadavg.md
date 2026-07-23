# unix.loadavg

- **source**: node_exporter
- **patterns**: `node_load1`, `node_load5`, `node_load15`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.linux | load1 | `node_load1` |
| system.linux | load15 | `node_load15` |
| system.linux | load5 | `node_load5` |
| system.linux | loadPerCpu | `node_cpu_seconds_total`<br>`node_load1` |

## Live metrics (3)

- `node_load1`
- `node_load15`
- `node_load5`
