# unix.systemd

- **source**: node_exporter
- **notes**: Enabled 2026-07-23 with a curated unit allowlist (salt-minion/alloy/sshd/docker/containerd/crio/kubelet/gdm/gnome-session/wg-quick/zerotier).
- **patterns**: `node_systemd_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.linux | servicesActive | `node_systemd_unit_state` |
| system.linux | servicesFailed | `node_systemd_unit_state` |

## Live metrics (4)

- `node_systemd_system_running`
- `node_systemd_unit_state`
- `node_systemd_units`
- `node_systemd_version`
