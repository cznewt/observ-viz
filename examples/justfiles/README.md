# Example justfiles

Copy-pasteable `justfile`s for the three ways to use observ-viz. Drop one into
your repo as `justfile` (rename), then `just`.

| file | use it when | needs |
|------|-------------|-------|
| [`render-with-image.justfile`](render-with-image.justfile) | quickest start — render manifests or bundled observ-libs | Docker + `just` |
| [`vendor-and-render.justfile`](vendor-and-render.justfile) | you author your own dashboards and vendor observ-viz | Docker + `just` (+ [`jsonnetfile.json`](jsonnetfile.json) + your `dashboards.jsonnet`) |
| [`observ-lib.justfile`](observ-lib.justfile) | you ship an **observ-lib** (dashboards + alerts + rules) | Docker + `just` (the Makefile_mixin analogue) |

Supporting files: [`jsonnetfile.json`](jsonnetfile.json) (the jb dependency on
observ-viz) and [`dashboards.jsonnet`](dashboards.jsonnet) (an example consumer
manifest that builds a board from signals and reuses an observ-lib dashboard).

All of them run `jb` / `jsonnet` inside a Docker image, so the only thing you
install locally is Docker + [`just`](https://github.com/casey/just).
