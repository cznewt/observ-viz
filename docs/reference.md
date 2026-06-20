# Reference & scenarios

## Reference boards (`libs/reference-lib/`)

Four Grafana folders, structured as a subdir per category:

```
libs/reference-lib/
├─ common/      -> 'Common Reference'      a board per common-lib preset category + patterns
├─ panels/      -> 'Panel Reference'       one board per panel type (built from g.panel.*)
├─ languages/   -> 'Language Reference'    tabbed board per runtime pack
└─ deployments/ -> 'Deployment Reference'  tabbed board per system/kubernetes pack
```

All non-panel reference boards **come from the pack mixins** — each is a pack's
output rendered as a **tabbed board**: an *Overview* tab (a markdown panel
listing every signal's name/unit/query) followed by one tab per signal group.
The panel reference is the exception (panels aren't a mixin, so those boards are
built directly from `g.panel.*`).

Load them:

```sh
python3 scripts/load.py libs/reference-lib/render.jsonnet
```

## Scenarios (`scenarios/`)

A **scenario** aggregates several packs into one environment — the
alloy-resources *scenario* concept (a composition of modules for a deployment):

```jsonnet
g.scenarios.linux.new()      // system.linux + system.docker + collector.alloy
g.scenarios.docker.new()
g.scenarios.kubernetes.new() // kubernetes.pod + kubernetes.cadvisor + collector.alloy
g.scenarios.lgtm.new()       // databases.timeseries.{mimir,loki,tempo,pyroscope} + alloy
```

Each returns:

```
{
  grafanaDashboards,                 // a Grafana folder of pack boards
  prometheusAlerts,                  // merged alerts across members
  backstage: { system, components }, // see Backstage
  asMonitoringMixin(),
}
```

```sh
python3 scripts/load.py scenarios/render.jsonnet
```
