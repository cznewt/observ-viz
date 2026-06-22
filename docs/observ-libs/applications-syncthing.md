# Syncthing  (`g.libs.applications.syncthing`)

Dashboard uid `observ-viz-syncthing` · 7 signals · 1 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `conflicts` | short | `sum by (folder) (rate(syncthing_model_folder_conflicts_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `connectionsActive` | short | `syncthing_connections_active{job=~"$job", instance=~"$instance"}` | — |
| `filesUpdated` | ops | `sum(rate(syncthing_db_files_updated_total{job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `folderProcessed` | Bps | `rate(syncthing_model_folder_processed_bytes_total{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `folderState` | short | `syncthing_model_folder_state{job=~"$job", instance=~"$instance"}` | — |
| `recvBytes` | Bps | `rate(syncthing_protocol_recv_bytes_total{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `sentBytes` | Bps | `rate(syncthing_protocol_sent_bytes_total{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |

## Dashboard

- **Connections** — `connectionsActive`, `recvBytes`, `sentBytes`
- **Folders** — `conflicts`, `folderProcessed`, `folderState`
- **Database** — `filesUpdated`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `SyncthingFolderConflicts` | warning | 15m | — |
