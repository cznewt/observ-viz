# Reference & scenarios

## Reference boards (`libs/reference-lib/`)

Three Grafana folders, structured as a subdir per category:

```
libs/reference-lib/
├─ panels/      -> 'Reference / Panels'       one board per panel type (built from g.panel.*)
├─ languages/   -> 'Reference / Runtimes'     tabbed board per runtime pack
└─ deployments/ -> 'Reference / Deployments'  tabbed board per system/kubernetes pack
```

All non-panel reference boards **come from the pack mixins** — each is a pack's
output rendered as a **tabbed board** on top of the pack's own dashboard, so its
variables (`job` plus any cascading `varLabels` filters) carry over:

* an *Overview* tab: what the board is and its reference links side by side,
  then an **Instances table** — one row per instance, joined from an instant
  query per column (`config.overviewSignals`);
* one tab per signal group, opening with that group's **signal table**
  (name / unit / description / query) above the group's panels.

The panel reference is the exception (panels aren't a mixin, so those boards are
built directly from `g.panel.*`); each panel type is one board laid out as rows:
an *Overview* row with the Grafana docs link, then a row per example.

The runtime boards pass the filter/legend options every pack accepts:

```jsonnet
g.libs.runtimes.golang.new({
  varLabels: ['namespace', 'pod'],     // cascading filter variables
  legendLabels: ['namespace', 'pod'],  // legend '{{namespace}} / {{pod}}'
  overviewSignals: ['cpu', 'rss', 'goroutines', 'heapInuse', 'gcRate'],
  description: 'The Go runtime as exposed by client_golang.',
  references: [{ title: 'Go runtime metrics', url: 'https://pkg.go.dev/runtime/metrics' }],
})
```

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
