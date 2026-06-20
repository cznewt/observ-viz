# Example justfile — vendor observ-viz with jb and render your dashboards with
# jsonnet, all from the monitor-tools image (nothing installed locally).
# Needs a jsonnetfile.json declaring observ-viz (see ./jsonnetfile.json) and your
# own dashboards.jsonnet. Copy this into your repo as `justfile`.

TOOLS := "ghcr.io/cznewt/monitor-tools:latest"
RUN   := "docker run --rm -v \"$PWD\":/work -w /work " + TOOLS
# observ-viz vendors to vendor/github.com/cznewt/observ-viz; its internal imports
# are root-relative ('libs/common-lib/...', 'custom/...', 'gen/...').
JPATH := "-J vendor/github.com/cznewt/observ-viz -J vendor -J ."

# list targets
default:
    @just --list

# jb install -> vendor/
vendor:
    {{RUN}} jb install

# render dashboards.jsonnet -> dashboards_out/<key>.json (one file per top-level key)
dashboards: vendor
    mkdir -p dashboards_out
    {{RUN}} jsonnet {{JPATH}} -m dashboards_out dashboards.jsonnet

# format your jsonnet (skips vendor/)
fmt:
    {{RUN}} bash -c "find . -name '*.libsonnet' -o -name '*.jsonnet' | grep -v vendor | xargs jsonnetfmt -i"

# lint the rendered dashboards
lint: dashboards
    {{RUN}} bash -c "for f in dashboards_out/*.json; do dashboard-linter lint \"$f\" || true; done"

clean:
    rm -rf dashboards_out
