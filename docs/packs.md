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

Optional, on every pack built through `libs/common-lib/filters.libsonnet`:

| key | effect |
| --- | --- |
| `varLabels` | cascading filter variables, e.g. `['namespace', 'pod']`; each one is a `label_values()` query scoped by `job` and the variables before it, and each is appended to the query selector |
| `legendLabels` | series legend built from labels, e.g. `['namespace', 'pod']` -> `{{namespace}} / {{pod}}` |
| `overviewSignals` | the signals a reference board shows as columns of its instances table |
| `description`, `references` | board description and reference links, shown on the Overview tab |
| `tabbed` | lay the board out as tabs (see the board spec below) instead of one row per signal group |
| `rowLabels`, `instanceLabel` | what one row of the instances table is, e.g. `['namespace', 'pod']` |
| `folderPath` | where the board is filed, as an ancestor chain: `[{uid, title}, ...]` ending in the folder itself |

## The board

A pack renders one board, and the same board everywhere, so a reader who knows
one knows them all.

**Header.** `datasource` and `job` variables, then one cascading filter variable
per `varLabels` entry - each a `label_values()` query scoped by `job` and the
variables before it, and each appended to every query's selector.

**Tabs** (`config.tabbed`, the default for component packs):

| Tab | Holds |
| --- | --- |
| Overview | what the board is and its reference links side by side, then an instances table: one row per `rowLabels` identity, a column per `overviewSignals` entry, each an instant query joined on that identity. A signal group the pack itself calls "Overview" folds in below. |
| one per signal group | that group's signal table (name, unit, description, and the query as written, with the filter variables left as `...`), then the group's panels |
| Runbooks | the pack's alerting rules and their runbook links, when `docTabs` is on |

Without `tabbed` the same content is one `RowsLayout` row per signal group.

### Optional sections

Not every target has every exporter: a Kubernetes service has cAdvisor and
kubelet series, the same service on a host has neither, and logs only exist
where a logs datasource is wired up. Those sections are **optional tabs**, and a
pack declares them next to its groups:

```jsonnet
pack.build(cfg, signals, groups, alerts, rules, [
  {
    title: 'Containers',
    presence: { label: 'pod', query: 'container_cpu_usage_seconds_total{%(selector)s}' },
    width: 12, height: 7,
    elements: { ... },
  },
])
```

Each entry is gated one of three ways:

* **`presence`** - the pack adds a hidden `has_<tab>` variable holding
  `label_values(<query>, <label>)`, and the tab renders only when it is not
  empty. Use this when the tab's own panels would look empty rather than absent
  (a marker metric decides).
* **nothing** - the tab gets `showIfData()`, Grafana's conditional rendering:
  it appears only when its own queries return data.
* **`alwaysShow: true`** - no gate.

An entry carries either `elements` (one grid) or `groups` (rows inside the tab).
`libs/service-observ-lib` is the worked example: one board per service with
Kubernetes / Containers / Docker / systemd / Host process / Go runtime /
Windows / Logs tabs, each gated this way, so the same pack covers a service in
Kubernetes and the same service on a host.

## Analysis methods

`libs/analysis-observ-lib` holds the methods that own no metrics and read
someone else's. Each takes a *source profile*, so one board covers any
instrumentation with the right shape:

| Method | Profile says | Boards |
| --- | --- | --- |
| `analysis.red` | request counter, how failures are marked, latency histogram, the dimension to group by | OpenTelemetry HTTP, Prometheus client, ingress-nginx, Django, Grafana, API server, Tempo service graph |
| `analysis.use` | the four resources and how each is measured | node_exporter, cAdvisor |
| `analysis.anomaly` | the series to watch | process, requests |

The same idea appears inside a pack where one thing reports two ways:
`networking.kong` takes `implementation: 'prometheus' | 'prometheus2' |
'opentelemetry'`. The signals are the same either way; the ones an
implementation cannot answer (Kong's own shared dictionaries, its datastore,
the gateway-versus-upstream latency split) are left out rather than left blank.

RED and anomaly each have three entry points, because a service usually wants a
fragment rather than a board of its own:

```jsonnet
local red = g.libs.analysis.red;
local cfg = { source: g.libs.analysis.sources.red.ingressNginx, service: 'ingress',
              ruleSelector: 'job=~".*ingress.*"', errorRatio: 0.02, latency: 0.5 };

red.new(cfg)                  // a board: the three numbers, then a row per route
red.elements(cfg, 'red_')     // a fragment: rate, errors, duration
red.alerts(cfg)               // the rule group: failures, latency, traffic gone
```

The board's per-route tab is one row repeated over the source's first dimension
(`http_route`, `ingress`, `view`, ...), so selecting three routes in the
variable gives three rows of the same three panels. `perRoute: false` drops it.

The anomaly method takes the same shape:

```jsonnet
local anomaly = g.libs.analysis.anomaly;
local cfg = {
  service: 'redis',
  selector: 'namespace="global-monitor-redis"',
  ruleSelector: 'namespace="global-monitor-redis"',   // rules cannot use $vars
  baseline: '1d', z: 3, 'for': '15m',
  series: [{ key: 'clients', title: 'Connected clients', unit: 'short',
             expr: 'sum by (pod) (redis_connected_clients{%(queriesSelector)s})' }],
};

anomaly.new(cfg)                 // a board: a tab per series
anomaly.elements(cfg, 'anom_')   // a fragment: the element map for someone else's board
anomaly.alerts(cfg)              // the rule group: one alert per series
```

Each series is compared with its own past: the baseline is the rolling mean
over `baseline`, the band is that mean plus or minus `z` standard deviations,
and the alert fires when the z-score stays outside it for `for`. Nothing is
compared with a fixed threshold, so the same config works for a service doing
five requests a second and one doing five thousand.

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
