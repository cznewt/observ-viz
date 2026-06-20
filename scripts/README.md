# scripts/ — observ-viz tooling

All command-line tooling for rendering, applying and cataloguing observ-viz
dashboards. Everything uses the Python `_jsonnet` binding (no jsonnet/jb needed
locally) and the Grafana v2 app-platform API.

| Script | What it does |
|--------|--------------|
| `load.py` | Render `examples/*.jsonnet` (or any `render.jsonnet`) and **push** the dashboards to Grafana via the v2 API, creating folders. Handles a single Dashboard or a `{name: resource}` map. |
| `deploy.py` | The **deployer**: render a *deployment profile* (`scenarios/<name>/`) and apply its observ-lib boards into the profile's Grafana folder; points at the profile's Alloy config. |
| `gen-catalog.py` | Render `scenarios/catalog.jsonnet` → `backstage/observ-viz-catalog.yaml` (Backstage Domain / Systems / Components). |

## Usage

```sh
# examples + reference + scenarios
python3 scripts/load.py                       # all examples
python3 scripts/load.py reference/render.jsonnet

# deploy a deployment profile (renders + applies into its folder)
python3 scripts/deploy.py --list
python3 scripts/deploy.py linux-server
python3 scripts/deploy.py all

# backstage catalog
python3 scripts/gen-catalog.py
```

Env (all scripts): `GRAFANA_URL` (default `http://localhost:3000`),
`GRAFANA_USER`/`GRAFANA_PASS` (default `admin`/`admin`), `GRAFANA_NAMESPACE`
(default `default`).

These are also wrapped by the `justfile` (`just load`, `just load-ref`,
`just load-scenarios`, `just catalog`, …).
