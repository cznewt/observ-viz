# observ-viz dev tasks.
# Local steps use the Python _jsonnet binding; full render/vendor/lint use the
# monitor-tools docker image (which bundles jb, jsonnet, jrsonnet, grizzly).

IMAGE := "ghcr.io/cznewt/monitor-tools:latest"

# default: list targets
default:
    @just --list

# compile examples locally and run structural checks (no docker)
compile:
    python3 tests/compile.py

# run the python generator unit tests
gen-test:
    cd generator && python3 -m pytest -q

# (re)generate the gen/ typed builders from generator/schemas
gen *ARGS:
    cd generator && python3 -m observ_viz_gen.cli {{ARGS}}

# fail if gen/ drifts from what the generator would produce
gen-check:
    cd generator && python3 -m observ_viz_gen.cli all --check

# vendor jsonnet deps (docker: jb install)
vendor:
    docker run --rm -v "$PWD":/work -w /work {{IMAGE}} jb install

# render every example through jsonnet (docker) and diff vs golden
render:
    bash tests/render-golden.sh

# format all jsonnet (docker: jsonnetfmt)
fmt:
    docker run --rm -v "$PWD":/work -w /work {{IMAGE}} \
        bash -c "find . -name '*.libsonnet' -o -name '*.jsonnet' | grep -v vendor | xargs jsonnetfmt -i"

# lint rendered dashboards (docker: dashboard-linter) — best effort
lint:
    bash tests/render-golden.sh --lint

# start the local Grafana + Prometheus + Loki + node-exporter stack
up:
    docker compose up -d
    @echo "Grafana: http://localhost:3000 (admin/admin) — run 'just load' to push dashboards"

# stop the local stack
down:
    docker compose down

# render examples and push them to local Grafana via the v2 app-platform API
load *ARGS:
    python3 scripts/load.py {{ARGS}}

# run the full local test suite
test: compile gen-test
