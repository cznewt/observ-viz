# The observ-lib image

`ghcr.io/cznewt/observ-lib` bundles the observ-viz library + tooling and renders
**any** Jsonnet manifest that imports it — **no vendoring needed**, because the
library sits at `/observ-viz` on the jpath.

```sh
docker run --rm -v "$PWD":/work ghcr.io/cznewt/observ-lib render <manifest.jsonnet>
```

## Commands

| Command | What |
|---------|------|
| `render <file> [-m <dir>] [-J <path>]` | render a manifest → Grafana v2 JSON (stdout, or one file per key with `-m`) |
| `render-lib <lib> [--validate] [--deploy]` | render a **bundled** observ-lib → `build/<lib>/{dashboards,alerts,rules}/` |
| `load <file> ...` | apply rendered dashboards to Grafana (v2 app-platform API) |
| `deploy <profile>` / `deploy all` | deploy a scenario profile |
| `catalog` | emit the Backstage catalog |
| `jb ...` | jsonnet-bundler (for extra vendored deps) |
| `sh` | a shell |

## Rendering a bundled observ-lib

The image ships all 26 observ-libs, so you can render any of them straight to the
3-dir container layout with no checkout — output lands in the mounted dir:

```sh
docker run --rm -v "$PWD":/work ghcr.io/cznewt/observ-lib \
  render-lib iot.homeAssistant --validate
# -> build/iot.homeAssistant/{dashboards,alerts,rules}/
#    e.g. runtimes.golang, system.linux, databases.timeseries.mimir, alerts, logs
```

## Rendering a consuming observ-lib

A repo that ships an observ-viz observ-lib (e.g. the home-assistant-exporter)
needs no `jb install` — just mount it and render:

```sh
# from the exporter repo
docker run --rm -v "$PWD/operations":/work ghcr.io/cznewt/observ-lib \
  render home-assistant-observ-lib/render.jsonnet > home-assistant.json
```

The manifest's `import 'home-assistant-observ-lib/main.libsonnet'` resolves from
`/work`, and its `import 'libs/common-lib/...'` resolves from `/observ-viz`.

## Build / publish

```sh
just image            # docker build -f docker/Dockerfile -t ghcr.io/cznewt/observ-lib:latest .
just image-publish    # build + docker push
just render-image operations/home-assistant-observ-lib/render.jsonnet
```
