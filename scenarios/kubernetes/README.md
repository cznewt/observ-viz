# Kubernetes — deployment profile

An observ-viz **deployment profile** (scenario). It deploys a Grafana folder
"Kubernetes" of observ-lib dashboards and ships an Alloy config for collection.

## Files
- `config.libsonnet` — the mixin selection + params (which observ-libs + selectors), à la a monitor-tools deployment config.
- `alloy.alloy` — the Alloy config (scrapes this deployment, metrics → Mimir, logs → Loki).
- `render.jsonnet` — renders the boards to v2 resources.

## Deploy
```sh
python3 scripts/deploy.py kubernetes      # render + apply the boards into the "Kubernetes" folder
# then point your Alloy at alloy.alloy  (METRICS_URL / LOGS_URL -> your Mimir / Loki)
```
