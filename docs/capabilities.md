# What observ-viz can do

A standalone Jsonnet library + tooling for **Grafana dashboard schema v2**
(`dashboard.grafana.app/v2beta1`), where panels are reusable *elements* defined
once and *layouts* reference them by name.

## 1 · Core v2 builder (`g.*`)
- Native **v2** dashboards — no grafonnet runtime; `gen/` (generated) + `custom/` (veneer) split.
- **All 25 panel types** as typed builders + generic `g.panel.base(kind)` for anything new.
- **All datasource query families** — prometheus, loki, sql, influxdb, elasticsearch, tempo, … + generic `g.query.base(kind, spec)`.
- **4 layout kinds** — Grid, Rows, AutoGrid, Tabs (nestable, reference elements by name).
- v2 **variables** (8 kinds), **annotations**, time settings, links.
- Output: **`toResource()`** (full k8s envelope) / **`toSpec()`** (bare spec).

## 2 · common-lib (rendered through our v2 viz)
- **signal engine** — `init` / `addSignal` (gauge/counter/histogram/info/raw/log/stub) + lean `signal.new()`; `asTimeSeries/asStat/asTable/asGauge/asTarget/…`; modifiers (topK/offset/quantile/agg…); auto unit gen; **variable generation** (`getVariables*`, `queriesSelector*`).
- **56 base panel presets** across 8 categories (cpu/memory/disk/network/system/requests/hardware/generic).
- **annotations** (base + critical/warning/info/fatal + reboot/service_failed), **tokens** (colours + timeSeries), **utils** (label→selector/legend, `chainLabels`).
- reusable **alert** (rule + record + group + panels), **logs**, **deploy** primitives.

## 3 · observ-libs — 26 domain packs (`g.libs.*`)
- runtimes (go/jvm/python/dotnet/nodejs) · system (linux/docker/windows) · kubernetes (pod/cadvisor) · databases (postgres/mysql/redis/memcached/etcd/mimir/loki/tempo/pyroscope) · collector (alloy) · infra (prometheus) · iot (home-assistant) · cross-cutting (alerts, logs).
- Each `new(config)` → `signals` + `grafana{dashboard,elements,layout}` + `prometheus{alerts,rules}` + `asMonitoringMixin()`.
- Each declares its dependency via **jb** (`jsonnetfile.json`).

## 4 · The observ-lib container — render to 3 dirs
- `dashboards/<uid>.json` + `alerts/<group>.yaml` + `rules/<group>.yaml` (rules **by group**).
- `just render-lib | validate-lib | deploy-lib <lib>` (or `scripts/render-lib.py`).
- **test** (compile) · **validate** (structural + promtool) · **deploy** (Grafana v2 API + Mimir ruler).
- **Generic `justfile` template** (`templates/observ-lib/`, the Makefile_mixin analogue) — drop into any lib; `init/vendor/dashboards/alerts/rules/build/fmt/lint/clean` run jb+jsonnet from the monitor-tools image (nothing local).

## 5 · Reference boards — 4 Grafana folders
- **Common Reference** (a board per common-lib preset category + RED/alerts patterns) · **Panel Reference** (25 chart types + per-option variations) · **Language Reference** (runtimes) · **Deployment Reference** (system/kube).

## 6 · Scenarios — 6 deployment profiles
- linux-server/desktop/docker/podman · kubernetes · lgtm. Each = a Grafana folder of member-pack boards **+ auto alerts + logs boards**, an Alloy config, a README, and a Backstage System.

## 7 · Patterns
- `g.patterns.red` · `g.patterns.alertsOverview` — whole-dashboard encapsulations.

## 8 · Tooling & integrations
- **justfile**: `test` (compile + packs + panels), `up`/`up-apps` stacks, `load*`/`deploy*`, `image*`, `docs*`, `catalog`.
- **Docker image** `ghcr.io/cznewt/observ-lib` — render any manifest with no vendoring (`render`, `render-lib`, `load`, `deploy`, `jb`).
- **Local stacks** — Grafana+Prometheus+Loki, and **Alloy→Mimir/Loki** + sample apps (go/python/jvm/dotnet).
- **Backstage** catalog (Domain/Systems/Components) · **docs site** (mkdocs) + **publish Action** (gh-pages) · auto-generated chart-types & observ-libs pages.
- Fits the **monitor-tools** pipeline (`grafanaDashboards` + `prometheusAlerts` + `prometheusRules`).
- Plus DOOM 🎮 (the generic escape-hatch demo).
