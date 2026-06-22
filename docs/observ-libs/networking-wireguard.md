# WireGuard (wg-easy)  (`g.libs.networking.wireguard`)

Dashboard uid `observ-viz-wg-easy` · 6 signals · 1 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `configuredPeers` | short | `sum(wireguard_configured_peers{job=~"$job", instance=~"$instance"})` | — |
| `connectedPeers` | short | `sum(wireguard_connected_peers{job=~"$job", instance=~"$instance"})` | — |
| `enabledPeers` | short | `sum(wireguard_enabled_peers{job=~"$job", instance=~"$instance"})` | — |
| `handshakeAge` | s | `time() - wireguard_latest_handshake_seconds{job=~"$job", instance=~"$instance"}` | — |
| `receivedBytes` | Bps | `rate(wireguard_received_bytes{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |
| `sentBytes` | Bps | `rate(wireguard_sent_bytes{job=~"$job", instance=~"$instance"}[$__rate_interval])` | — |

## Dashboard

- **Peers** — `configuredPeers`, `connectedPeers`, `enabledPeers`
- **Traffic** — `receivedBytes`, `sentBytes`
- **Handshakes** — `handshakeAge`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `WireguardPeerHandshakeStale` | warning | 10m | — |
