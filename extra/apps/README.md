# observ-viz sample apps

Minimal sample applications that expose Prometheus **runtime metrics** (and emit
logs), so the observ-viz runtime/language dashboards light up with real data in
the local "apps" stack (`docker-compose.apps.yml`).

| App | Metrics library | Runtime metrics | Pack |
|-----|-----------------|-----------------|------|
| `go/` | `client_golang` | `go_*`, `process_*` | `packs.runtimes.golang` |
| `python/` | `prometheus_client` | `python_gc_*`, `process_*` | `packs.runtimes.python` |
| `java/` | Micrometer | `jvm_*` | `packs.runtimes.jvm` |
| `dotnet/` | `prometheus-net` + `DotNetRuntime` | `dotnet_*` | `packs.runtimes.dotnet` |

Each app serves metrics on `:8080/metrics`, runs a small background work loop
(to generate GC/heap activity), and logs to stdout (tailed into Loki by Alloy).

## Run

```sh
just up-apps     # build images + start grafana/mimir/loki/alloy + the apps
just load-all    # push observ-viz dashboards
# open http://localhost:3000 (admin/admin); default datasource = Mimir
```

Alloy scrapes each app (`job=app-go|app-python|app-jvm|app-dotnet`) and
remote-writes to Mimir; it tails container logs into Loki.

## Publish

The images are tagged `ghcr.io/cznewt/observ-viz-sample-<lang>`:

```sh
just apps-build      # build all four
just apps-publish    # build + push to the registry
```
