# observ-lib template (Makefile_mixin analogue)

Drop these four files next to an observ-lib's `main.libsonnet` to make it a
self-contained, renderable **container** — dashboards + alerting rules +
recording rules — driven entirely from the monitor-tools image (nothing
installed locally).

```
<lib>/
  main.libsonnet      # the observ-lib (new(config) -> grafana + prometheus)
  jsonnetfile.json    # declares the observ-viz dependency (jb)
  config.libsonnet    # your deployment config (selector, datasource, ...)
  mixin.libsonnet     # render entry point (grafanaDashboards/prometheusAlerts/prometheusRules)
  justfile            # the targets below
```

## Targets

| `just` | does |
|--------|------|
| `init` | `jb init` (only if there's no `jsonnetfile.json`) |
| `vendor` | `jb install` — vendor observ-viz (common-lib + builder) |
| `dashboards` | render → `dashboards_out/<uid>.json` |
| `alerts` | render → `prometheus_alerts.yaml` |
| `rules` | render → `prometheus_rules.yaml` |
| `build` | dashboards + alerts + rules |
| `fmt` | `jsonnetfmt -i` all jsonnet |
| `lint` | `promtool check rules` + dashboard-linter |
| `clean` | remove rendered output |

```sh
just vendor
just build      # dashboards_out/ + prometheus_alerts.yaml + prometheus_rules.yaml
```

`jb` and `jsonnet` run inside `ghcr.io/cznewt/monitor-tools:latest`, so the only
local requirement is Docker + [`just`].
