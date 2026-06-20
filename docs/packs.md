# Packs (mixins)

A **pack** is an observ-lib-style mixin built from signals. The `packs/` tree
mirrors the [alloy-resources](https://github.com/cznewt/alloy-resources)
module catalog — one Alloy module ≈ one observ-viz pack.

```jsonnet
g.packs.system.linux.new({ selector: 'job="node"' })
```

returns:

```
{
  signals,                                  // the signal map
  grafana: { elements, layout, dashboard, groups },
  prometheus: { alerts },
  asMonitoringMixin(),                      // { grafanaDashboards+, prometheusAlerts+ }
}
```

`new(config)` accepts `{ uid, dashboardTitle, dashboardTags, datasource,
selector, varMetric }` and produces a self-contained dashboard (with
`datasource` + `job` variables).

## Catalog

| Group | Packs |
|-------|-------|
| `databases.kv` | `etcd`, `memcached`, `redis` |
| `databases.sql` | `mysql`, `postgres` |
| `databases.timeseries` | `loki`, `mimir`, `tempo`, `pyroscope` (the LGTM stack) |
| `collector` | `alloy` |
| `system` | `linux` (node-exporter), `docker` (cAdvisor), `windows` |
| `kubernetes` | `pod`, `cadvisor` |
| `runtimes` | `golang`, `jvm`, `python`, `dotnet`, `nodejs` |
| `infra` | `prometheus` |
| _cross-cutting_ | `alerts` (alerts-observ-lib), `logs` (logs-lib) — signals + annotations + reusable panels, built on common-lib |

## Adding a pack

A pack is ~60 lines: define signals, group them, call `pack.build`:

```jsonnet
local pack = import 'packs/_pack.libsonnet';
local signal = import 'signal/main.libsonnet';
{
  new(config={}):
    local cfg = { uid: 'observ-viz-foo', dashboardTitle: 'Foo',
                  dashboardTags: ['foo'], datasource: '${datasource}',
                  selector: 'job=~"$job"', varMetric: 'foo_up' } + config;
    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);
    local signals = {
      qps: sig('Requests', 'sum(rate(foo_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps'),
    };
    pack.build(cfg, signals, [
      { title: 'Traffic', width: 12, height: 8, elements: {
        qps: signals.qps.asTimeSeries('Requests/s') } },
    ]),
}
```

Generic `g.query.base(kind, spec)` means a pack can target any datasource, and
`g.panel.base(kind, title)` any panel — no library change needed.
