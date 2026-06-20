# The observ-viz image

`ghcr.io/cznewt/observ-viz` bundles the observ-viz library + tooling and renders
**any** Jsonnet manifest that imports it — **no vendoring needed**, because the
library sits at `/observ-viz` on the jpath.

```sh
docker run --rm -v "$PWD":/work ghcr.io/cznewt/observ-viz render <manifest.jsonnet>
```

## Commands

| Command | What |
|---------|------|
| `render <file> [-m <dir>] [-J <path>]` | render a manifest → Grafana v2 JSON (stdout, or one file per key with `-m`) |
| `load <file> ...` | apply rendered dashboards to Grafana (v2 app-platform API) |
| `deploy <profile>` / `deploy all` | deploy a scenario profile |
| `catalog` | emit the Backstage catalog |
| `jb ...` | jsonnet-bundler (for extra vendored deps) |
| `sh` | a shell |

## Rendering a consuming observ-lib

A repo that ships an observ-viz observ-lib (e.g. the home-assistant-exporter)
needs no `jb install` — just mount it and render:

```sh
# from the exporter repo
docker run --rm -v "$PWD/operations":/work ghcr.io/cznewt/observ-viz \
  render home-assistant-observ-lib/render.jsonnet > home-assistant.json
```

The manifest's `import 'home-assistant-observ-lib/main.libsonnet'` resolves from
`/work`, and its `import 'libs/common-lib/...'` resolves from `/observ-viz`.

## Build / publish

```sh
just image            # docker build -f docker/Dockerfile -t ghcr.io/cznewt/observ-viz:latest .
just image-publish    # build + docker push
just render-image operations/home-assistant-observ-lib/render.jsonnet
```
