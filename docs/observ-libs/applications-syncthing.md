# Syncthing  (`g.libs.applications.syncthing`)

Dashboard uid `observ-viz-syncthing` · 16 signals · 1 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `conflicts` | short | `sum by (instance, folder) (rate(syncthing_model_folder_conflicts_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `connectionsActive` | short | `syncthing_connections_active{job=~"$job", cluster=~"$cluster", instance=~"$instance"} * on (instance, device) group_left(name) syncthing_config_device_info{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `devicesKnown` | short | `count(syncthing_config_device_info{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `devicesOnline` | short | `sum(syncthing_connections_active{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `events` | ops | `sum by (instance) (rate(syncthing_events_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `folderProcessed` | Bps | `rate(syncthing_model_folder_processed_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `folderState` | short | `syncthing_model_folder_state{job=~"$job", cluster=~"$cluster", instance=~"$instance"}` | — |
| `foldersKnown` | short | `count(syncthing_config_folder_info{job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |
| `fsOps` | ops | `sum by (instance, operation) (rate(syncthing_fs_operations_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `hashedBytes` | Bps | `sum by (instance) (rate(syncthing_scanner_hashed_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `pullSeconds` | s | `rate(syncthing_model_folder_pull_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `recvBytes` | Bps | `rate(syncthing_protocol_recv_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `scanSeconds` | s | `rate(syncthing_model_folder_scan_seconds_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `scannedItems` | ops | `sum by (instance) (rate(syncthing_scanner_scanned_items_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval]))` | — |
| `sentBytes` | Bps | `rate(syncthing_protocol_sent_bytes_total{job=~"$job", cluster=~"$cluster", instance=~"$instance"}[$__rate_interval])` | — |
| `syncedBytes` | bytes | `sum(syncthing_model_folder_summary{scope="local", type="bytes", job=~"$job", cluster=~"$cluster", instance=~"$instance"})` | — |

## Dashboard

- **Overview** — `a_devicesOnline`, `b_devicesKnown`, `c_folders`, `d_synced`
- **Folders** — `foldersTable`
- **Transfer** — `a_connections`, `b_recv`, `c_sent`, `d_processed`
- **Scanner & filesystem** — `a_hashed`, `b_scanned`, `c_scan`, `d_pull`, `e_fsops`, `f_conflicts`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `SyncthingFolderConflicts` | warning | 15m | — |
