# unix.filesystem

- **source**: node_exporter
- **patterns**: `node_filesystem_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.linux | fsAvail | `node_filesystem_avail_bytes` |
| system.linux | fsSize | `node_filesystem_size_bytes` |
| system.linux | fsUsed | `node_filesystem_avail_bytes`<br>`node_filesystem_size_bytes` |
| system.linux | inodesUsed | `node_filesystem_files`<br>`node_filesystem_files_free` |

## Live metrics (9)

- `node_filesystem_avail_bytes`
- `node_filesystem_device_error`
- `node_filesystem_files`
- `node_filesystem_files_free`
- `node_filesystem_free_bytes`
- `node_filesystem_mount_info`
- `node_filesystem_purgeable_bytes`
- `node_filesystem_readonly`
- `node_filesystem_size_bytes`
