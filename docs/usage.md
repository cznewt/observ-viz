# Using observ-viz

Three ways to use it, from quickest to most integrated. All run `jb`/`jsonnet`
from a Docker image — the only local requirement is Docker + [`just`]. Ready-made
justfiles for each are in [`examples/justfiles/`](https://github.com/cznewt/observ-viz/tree/main/examples/justfiles).

## 1 · Render with the image (no vendoring)

The published image bundles observ-viz on the jpath, so it renders your manifests
— or any of the 26 bundled observ-libs — with nothing installed locally.

```sh
# your own manifest -> Grafana v2 JSON
docker run --rm -v "$PWD":/work ghcr.io/cznewt/observ-lib render dashboards/board.jsonnet > board.json

# a bundled observ-lib -> build/<lib>/{dashboards,alerts,rules}/
docker run --rm -v "$PWD":/work ghcr.io/cznewt/observ-lib render-lib iot.homeAssistant --validate
```

→ [`render-with-image.justfile`](https://github.com/cznewt/observ-viz/blob/main/examples/justfiles/render-with-image.justfile)

## 2 · Author your own dashboards (vendor observ-viz)

Declare the dependency, vendor it, and build with the v2 API.

```json title="jsonnetfile.json"
{ "version": 1, "legacyImports": true,
  "dependencies": [ { "source": { "git": {
      "remote": "https://github.com/cznewt/observ-viz.git", "subdir": "" } },
    "version": "main" } ] }
```

```jsonnet title="dashboards.jsonnet"
local g = import 'g.libsonnet';
local ds = '${datasource}';
local rate = g.common.signal.new('Requests', 'prometheus', ds,
  'sum(rate(http_requests_total[$__rate_interval]))', 'reqps');
{
  'my-service.json':
    (g.dashboard.new('My service')
     + g.dashboard.withUid('my-service')
     + g.dashboard.withElements(g.element.panel('rate', rate.asTimeSeries('Request rate')))
     + g.dashboard.withLayout(g.layout.grid.new()
       + g.layout.grid.withItems([g.layout.grid.item('rate', 0, 0, 24, 8)]))
    ).toResource(),
}
```

```sh
just vendor       # jb install
just dashboards   # jsonnet -m dashboards_out dashboards.jsonnet
```

→ [`vendor-and-render.justfile`](https://github.com/cznewt/observ-viz/blob/main/examples/justfiles/vendor-and-render.justfile)
· builders: [Core API](api.md) · reuse [observ-libs](libs.md) · presets [Chart types](panels.md).

## 3 · Ship an observ-lib (dashboards + alerts + rules)

An observ-lib is a **container** that emits the Grafana viz **and** the Prometheus
rules. Drop the [template](https://github.com/cznewt/observ-viz/tree/main/templates/observ-lib)
(`main.libsonnet` + `mixin.libsonnet` + `config.libsonnet` + `justfile`) next to
your lib and:

```sh
just vendor
just build      # dashboards_out/ + prometheus_alerts.yaml + prometheus_rules.yaml
```

→ [`observ-lib.justfile`](https://github.com/cznewt/observ-viz/blob/main/examples/justfiles/observ-lib.justfile)
· see [the observ-lib container](render.md) for the contract + `render-lib`.

## Deploying

```sh
# dashboards -> a local Grafana (v2 app-platform API)
docker run --rm --network host -v "$PWD":/work ghcr.io/cznewt/observ-lib load board.jsonnet
# or render + validate + deploy a bundled lib (dashboards -> Grafana, rules -> Mimir ruler)
just deploy-lib iot.homeAssistant
```

See [Examples & local Grafana](examples.md) for a one-command local stack to try it against.

[`just`]: https://github.com/casey/just
