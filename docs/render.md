# The observ-lib container

Each observ-lib is a **container** that handles both the Grafana **viz** and the
Prometheus **rules**. One entry point renders it to **three dirs**:

```
build/<lib>/dashboards/<uid>.json    Grafana v2 dashboard resources
build/<lib>/alerts/<group>.yaml      alerting rule groups   (one file per group)
build/<lib>/rules/<group>.yaml       recording rule groups  (one file per group)
```

## Entry points

| command | does |
|---------|------|
| `just render-lib <lib>` | render to the 3 dirs |
| `just validate-lib <lib>` | render + structural checks (+ `promtool check rules` if installed) |
| `just deploy-lib <lib>` | render + validate + deploy: dashboards → Grafana (v2 API), rule groups → Mimir ruler (if `MIMIR_RULER_URL` set) |

```sh
just render-lib   system.linux
just validate-lib system.linux
just deploy-lib   system.linux
# or directly / in the image:
python3 scripts/render-lib.py system.linux --validate --deploy
docker run --rm -v "$PWD/build":/work/build ghcr.io/cznewt/observ-lib render-lib system.linux --validate
```

## Contract

```jsonnet
g.libs.<group>.<name>.new(config) -> {
  signals,
  grafana:    { dashboard, dashboards, elements, layout, groups },
  prometheus: { alerts: [ruleGroup], rules: [ruleGroup] },   // alerting + recording
  asMonitoringMixin(),                                       // grafanaDashboards + prometheusAlerts + prometheusRules
}
```

Rules are authored with the common-lib alert builder and passed to `pack.build`:

```jsonnet
local alert = g.common.alert;
pack.build(cfg, signals, groups,
  [ alert.rule.group('node', [
      alert.rule.new('NodeDown', 'up == 0', '5m', 'critical', {},
                     { summary: 'Node {{ $labels.instance }} is down.' }),
    ]) ],
  [ alert.rule.group('node.rules', [
      alert.rule.record('instance:node_cpu_utilisation:rate5m',
                        '1 - avg without (cpu, mode) (rate(node_cpu_seconds_total{mode="idle"}[5m]))'),
    ]) ])
```

## Publishing to a Grafana

`--deploy` pushes the rendered dashboards to a Grafana via the v2 app-platform
API (folders are created as needed). Target **any** Grafana with env vars:

| env | default | for |
|-----|---------|-----|
| `GRAFANA_URL` | `http://localhost:3000` | the Grafana base URL |
| `GRAFANA_TOKEN` | — | service-account / API token (preferred for remote / Grafana Cloud) |
| `GRAFANA_USER` / `GRAFANA_PASS` | `admin`/`admin` | basic auth (local) |
| `GRAFANA_NAMESPACE` | `default` | org / stack namespace (Grafana Cloud) |
| `MIMIR_RULER_URL` | — | also push rule groups to a Mimir ruler |

```sh
# local Grafana (basic auth)
just deploy-lib system.linux

# any remote Grafana, through the image (token auth)
docker run --rm -e GRAFANA_URL=https://grafana.example.com -e GRAFANA_TOKEN="$TOKEN" \
  -v "$PWD":/work ghcr.io/cznewt/observ-lib render-lib system.linux --deploy

# local Grafana, through the image (host network so the container can reach it)
docker run --rm --network host -v "$PWD":/work \
  ghcr.io/cznewt/observ-lib render-lib system.linux --deploy
```

## Example — system.linux

`system.linux` is the worked example: a node dashboard (CPU/load, memory,
disk/filesystem, network), a `node` alerting group (down / high CPU / high memory
/ filesystem almost full) and a `node.rules` recording group (CPU + memory
utilisation) — rendered, validated and deployed by the commands above.

## The base boards

`base.home`, `base.cluster` and `base.clusterDetail` are a site's base layer
rather than one service's pack: the fleet overview (`Home dashboard`), the
env-wide server and workload tables (`Base clusters`) and the per-cluster
compute / network / storage / alerts view (`Base cluster`). They render like
any lib and name the `Base` folder themselves:

```bash
python3 scripts/render-lib.py base.home --config '{"appLabel": "namespace", "selector": ""}' --deploy
python3 scripts/render-lib.py base.clusterDetail --deploy   # + the base-node-count recording rule
```

Config worth setting per site: `clusterLabel` / `nodeLabel` / `appLabel` (the
workload grouping label — `app_part_of` by default, `namespace` where that is
unset), `selector` (a baseline matcher added to every query), the three titles
and `folder`. `base.clusterDetail` needs its `base:cluster_nodes:n` recording
rule in the ruler, which is what its `$nodecount` variable reads to stretch the
tables. In monitor-tools the whole set comes from one mixin entry with
`config.scenario: base`.
