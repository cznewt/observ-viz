# Generic observ-viz observ-lib justfile — the Makefile_mixin analogue.
# Renders THIS observ-lib's monitoring mixin (dashboards + alerts + rules).
# jb + jsonnet run from the monitor-tools image, so nothing is installed locally.
# Promote to any observ-viz lib unchanged (it only assumes a mixin.libsonnet +
# an observ-viz dep in jsonnetfile.json).

IMAGE := "ghcr.io/cznewt/monitor-tools:latest"
RUN   := "docker run --rm -v \"$PWD\":/work -w /work " + IMAGE
# observ-viz is vendored at vendor/github.com/cznewt/observ-viz (provides
# common-lib + the v2 builder via its root-relative imports).
JPATH := "-J vendor/github.com/cznewt/observ-viz -J vendor -J ."
MIXIN := "mixin.libsonnet"

# list targets
default:
    @just --list

# jb init (only if there is no jsonnetfile.json yet)
init:
    test -f jsonnetfile.json || {{RUN}} jb init

# jb install — vendor observ-viz (common-lib + builder)
vendor:
    {{RUN}} jb install

# render dashboards -> dashboards_out/<uid>.json
dashboards:
    mkdir -p dashboards_out
    {{RUN}} jsonnet {{JPATH}} -m dashboards_out -e '(import "{{MIXIN}}").grafanaDashboards'

# render alerting rules -> prometheus_alerts.yaml
alerts:
    {{RUN}} jsonnet {{JPATH}} -S -e 'std.manifestYamlDoc((import "{{MIXIN}}").prometheusAlerts)' > prometheus_alerts.yaml

# render recording rules -> prometheus_rules.yaml
rules:
    {{RUN}} jsonnet {{JPATH}} -S -e 'std.manifestYamlDoc((import "{{MIXIN}}").prometheusRules)' > prometheus_rules.yaml

# dashboards + alerts + rules
build: dashboards alerts rules

# format all jsonnet (skips vendor/)
fmt:
    {{RUN}} bash -c "find . -name '*.libsonnet' -o -name '*.jsonnet' | grep -v vendor | xargs jsonnetfmt -i"

# lint the rendered rules + dashboards
lint: build
    {{RUN}} bash -c "promtool check rules prometheus_alerts.yaml prometheus_rules.yaml; for f in dashboards_out/*.json; do dashboard-linter lint \"$f\" || true; done"

# remove rendered output
clean:
    rm -rf dashboards_out prometheus_alerts.yaml prometheus_rules.yaml
