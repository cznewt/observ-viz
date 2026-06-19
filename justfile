# observ-viz dev tasks.
# Local steps use the Python _jsonnet binding; full render/vendor/lint use the
# monitor-tools docker image (jb, jsonnet, jrsonnet, grizzly, dashboard-linter).

IMAGE := "ghcr.io/cznewt/monitor-tools:latest"

# list targets
default:
    @just --list

# ── compile / test ──────────────────────────────────────────────────────────

# compile examples locally + structural checks (no docker)
compile:
    python3 tests/compile.py

# render every pack end-to-end (no docker)
packs:
    python3 tests/packs.py

# full local test suite
test: compile packs

# format all jsonnet (docker)
fmt:
    docker run --rm -v "$PWD":/work -w /work {{IMAGE}} \
        bash -c "find . -name '*.libsonnet' -o -name '*.jsonnet' | grep -v vendor | xargs jsonnetfmt -i"

# vendor jsonnet deps (docker: jb install)
vendor:
    docker run --rm -v "$PWD":/work -w /work {{IMAGE}} jb install

# ── local Grafana stack ─────────────────────────────────────────────────────

# start Grafana + Prometheus + Loki + node-exporter
up:
    docker compose up -d
    @echo "Grafana: http://localhost:3000 (admin/admin) — run 'just load-all'"

# stop the stack
down:
    docker compose down

# restart the stack
restart: down up

# ── apps stack (Alloy -> Mimir/Loki + sample Go/Python/JVM/.NET apps) ─────────

# build + start the apps stack (sample apps light up the runtime dashboards)
up-apps:
    docker compose -f docker-compose.apps.yml up -d --build
    @echo "Grafana: http://localhost:3000 (admin/admin, default DS = Mimir) — run 'just load-all'"

# stop the apps stack
down-apps:
    docker compose -f docker-compose.apps.yml down

# build the sample-app images
apps-build:
    docker compose -f docker-compose.apps.yml build app-go app-python app-jvm app-dotnet

# build + publish the sample-app images to the registry
apps-publish: apps-build
    docker compose -f docker-compose.apps.yml push app-go app-python app-jvm app-dotnet

# ── load dashboards (v2 app-platform API) ───────────────────────────────────

# load example dashboards
load:
    python3 scripts/load.py

# load the reference boards (3 folders: Panel/Language/Deployment)
load-ref:
    python3 scripts/load.py reference/render.jsonnet

# load the scenario boards (Linux/Docker/Kubernetes/LGTM folders)
load-scenarios:
    python3 scripts/load.py scenarios/render.jsonnet

# load everything
load-all: load load-ref load-scenarios

# play DOOM (iframe variant — no plugin needed)
doom:
    python3 scripts/load.py examples/doom-iframe.jsonnet

# list folders + dashboards in the local Grafana
status:
    @curl -s -u admin:admin http://localhost:3000/api/folders | python3 -c "import sys,json;[print('folder:',f['title']) for f in json.load(sys.stdin)]"
    @curl -s -u admin:admin 'http://localhost:3000/api/search?type=dash-db' | python3 -c "import sys,json;print(len(json.load(sys.stdin)),'dashboards')"

# ── backstage catalog ───────────────────────────────────────────────────────

# generate the Backstage catalog (Domain/Systems/Components)
catalog:
    python3 scripts/gen-catalog.py

# ── docs ────────────────────────────────────────────────────────────────────

# build the docs site
docs:
    python3 -m mkdocs build

# serve the docs site at http://localhost:8000
docs-serve:
    python3 -m mkdocs serve -a 0.0.0.0:8000

# ── housekeeping ────────────────────────────────────────────────────────────

# stop stack + remove build artifacts
clean: down
    rm -rf site build
