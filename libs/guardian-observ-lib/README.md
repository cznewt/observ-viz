# guardian-observ-lib

Dashboards + alerts for the **`guardian`** Salt formula (device supervision /
parental control). Guardian runs on managed Windows / Debian / Batocera devices
and emits telemetry into Prometheus (Mimir) via the host's Alloy **textfile
collector** — this lib visualises it.

Registered as `g.libs.applications.guardian`.

## Signals consumed

| Metric | Half | Source | Meaning |
| :--- | :--- | :--- | :--- |
| `guardian_installed_apps{source}` | KNOW | inventory | installed-app count per source (Windows `msi`/`appx`; Debian `dpkg`/`snap`/`flatpak`; Batocera `pacman`) |
| `guardian_inventory_timestamp_seconds` | KNOW | inventory | unix time of the last inventory run (freshness) |
| `guardian_usage_minutes{user}` | CONTROL | watcher (Windows) | active-session minutes today, per user — present only when the control half is enabled |
| `guardian_user_connect_minutes{user}` | CONTROL | acct (Debian) | login/connect minutes per user — control half only |

## Dashboard — "Guardian — device supervision"

- **Overview** — reporting hosts, total installed apps, oldest inventory age (stats).
- **Installed applications** — per-host / per-source table.
- **Inventory freshness** — time since last inventory run (time series).
- **Usage (CONTROL half)** — daily active minutes / connect minutes per user; empty unless control is enabled.

## Alerts / rules

- alert `GuardianInventoryStale` — inventory older than 36h (the daily inventory timer/task stopped).
- recording `instance:guardian_installed_apps:sum` — total installed apps per host.

## Usage

```jsonnet
local g = import 'g.libsonnet';
g.libs.applications.guardian.new({ selector: 'job=~"integrations/windows_exporter"' }).grafana.dashboard
```

Config keys: `selector` (label filter), `datasource`, `uid`, `dashboardTitle`,
`ruleSelector` (static filter for alerting/recording rules). Render with the
generic observ-lib justfile (`just build`) or `render-lib applications.guardian`.
