---
name: observ-lib-authoring
description: Add or change observ-viz libraries (packs) - signals, panels, tabs, alerting and recording rules - with the live checks that keep them honest - confirm metric and label names against real telemetry first, follow the pack contract and the pure-Jsonnet rules, render and validate, push one board to a test Grafana, verify it with board-verify, then regenerate the catalog and say how the change reaches the monitoring lab. Use for any edit under libs/, scenarios/ or custom/ in observ-viz, for requests like "add a dashboard / an alert / a panel for X" in observ-viz or the monitoring lab, for fixing a broken observ-viz board or rule, and before proposing an observ-viz commit.
---

# observ-lib authoring

Monitoring code fails quietly: a panel built on an invented metric renders, shows
"No data" and looks fine in review. The loop below makes every change meet real
telemetry before anyone relies on it. Read the repository's `AGENTS.md` first - it
documents the core API, the pack contract and the conventions this skill assumes.

## 1. Ground truth before code

With the telemetry-query skill, on the stack the library is for:

```bash
python3 ${CLAUDE_SKILL_DIR}/../telemetry-query/scripts/ovq.py --env monlab metrics --ds mimir-monolith --match '{job="<the job>"}'      # the names that exist
python3 ${CLAUDE_SKILL_DIR}/../telemetry-query/scripts/ovq.py --env monlab series  --ds mimir-monolith --match '<metric>' --limit 5     # their labels
python3 ${CLAUDE_SKILL_DIR}/../telemetry-query/scripts/ovq.py --env monlab meta    --ds mimir-monolith <metric>                         # type and unit, if kept
```

With observ-viz-catalog, check what already exists
(`python3 ${CLAUDE_SKILL_DIR}/../observ-viz-catalog/scripts/catalog.py search <topic>`, `... metric <name>`): extend the library that owns the metrics instead of
adding a second one, and reuse its signal names.

Write down the metric names, label names, types (counter / gauge / histogram) and
units you will use. Every name in the change must come from that list.

## 2. Edit

- Library source: `libs/<name>-observ-lib/` (`main.libsonnet`, `config.libsonnet`, ...);
  domain logic lives there, not in `custom/`.
- Signals: `g.common.signal` - counters get `rate`, histograms `histogram_quantile`
  through the signal type rather than hand-written PromQL; keep `$job`-style
  selectors through `filteringSelector` so the board's variables apply.
- Alerts: `g.common.alert.rule.new(name, expr, for, severity, labels, annotations)` in a
  `group`. Give each a `summary` and a `description`, a `for` of at least 5m unless a
  faster page is justified, and a `runbook` annotation when you know more than the
  generated runbook would say.
- Ratios: make numerator and denominator cover the same set (same `by`, same
  containers). A pod-level sum over containers divided by limits that only some
  containers have is the classic false positive.
- Pure Jsonnet for the C++ binding: no `std.get`, `std.member`, `std.objectKeysValues`,
  `std.floorToInt`.
- Never leave a placeholder that evaluates (`'expr' == ''` is `false`, and the rule
  ships with `expr: false`).

## 3. Local checks

In the observ-viz checkout:

```bash
just test                       # compile, packs, panels, schema, vars, gen-check
just validate-lib <lib>         # render + structural and promtool validation of one library
just render-lib <lib>           # build/<lib>/{dashboards,alerts,rules}/ to read the output
```

`just vars` (part of `just test`) fails when a query reads a variable the board does
not declare - fix it, do not work around it.

## 4. Live check on a test Grafana

Push the one library you changed, not the whole set, and only to a Grafana meant
for testing (in the lab: `grafana-test`); the shared lab Grafana and anything
production need the user's go-ahead. Writing to a Grafana needs an Editor token -
a different one from the Viewer token the read-only skills use.

```bash
# in the observ-viz checkout; GRAFANA_URL / GRAFANA_TOKEN = the TEST Grafana, MIMIR_RULER_URL unset
python3 scripts/render-lib.py <lib> --validate --deploy     # dashboards only
```

- The recipes (`just deploy-lib`, `just load*`) read the checkout's `.env`, which may
  name another Grafana. Check where it points before running one.
- `--deploy` also loads the rule groups into the Mimir ruler when `MIMIR_RULER_URL`
  is set: only ever a test tenant.
- A standalone deploy may file the board in a different folder than the lab job
  does; that is fine on a test Grafana.

Then run board-verify on the pushed board and explain every `EMPTY` (its five causes).
For a new alert, evaluate its expression and threshold side with telemetry-query
over a day: it should be quiet on a healthy system and fire on the condition you
mean.

## 5. Finish

- `just docs-boards` regenerates `docs/boards.json` (a few minutes); include it in the
  same change so the catalog matches the code.
- Summarise: what changed, the metric list you relied on, the board-verify result,
  anything left empty and why.
- Commit or push only when the user asks.

## How a change reaches the monitoring lab

A board pushed by hand is overwritten by the nightly monitor-tools job. A change
becomes permanent in four steps: observ-viz `main` -> a monitor-tools release that
vendors it (`2026.9-rNN`) -> the lab job's version in monitor-lab-model
(`monitor_tools_job_version`, compiled and applied) -> the next job run. Name these
steps when you report, so nobody expects the lab to change on push.
