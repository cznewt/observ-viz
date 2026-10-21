---
name: observ-viz-catalog
description: Find where something lives in observ-viz - which library (pack), board uid, Grafana folder, tab, signal, alerting rule or recording rule covers a metric, exporter, alert name or topic, and which exporter or collector produces a metric. Use it before writing or changing observ-viz Jsonnet, when an alert name or board uid needs explaining, when choosing which board to open for a problem, or when someone asks "do we have a dashboard / an alert for X" - including questions about the monlab boards, observ-libs, packs or mixins that never say "observ-viz".
allowed-tools: Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/catalog.py *)
---

# observ-viz catalog

observ-viz has over a hundred libraries; reading their Jsonnet to answer "which board
shows container throttling" is slow and easy to get wrong. `docs/boards.json` already
holds the answer for every library and mixin board - uid, folder, tabs, signals with
their PromQL, alerting rules, recording rules - and `docs/exporters/` maps metrics to
the exporter and collector that produce them. `scripts/catalog.py`
(`${CLAUDE_SKILL_DIR}/scripts/catalog.py`) searches both.

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/catalog.py search throttl                      # anything matching, grouped by library
python3 ${CLAUDE_SKILL_DIR}/scripts/catalog.py metric container_cpu_cfs_throttled_periods_total   # who uses it, who exports it
python3 ${CLAUDE_SKILL_DIR}/scripts/catalog.py alert KubePodMemoryNearLimit        # rule, library, board, runbook pointers
python3 ${CLAUDE_SKILL_DIR}/scripts/catalog.py lib kubernetes.coredns              # one library in full (--full: no cutting)
python3 ${CLAUDE_SKILL_DIR}/scripts/catalog.py board observ-viz-coredns            # which library a board uid belongs to
python3 ${CLAUDE_SKILL_DIR}/scripts/catalog.py libs --grep postgres                # list, with signal / alert / rule counts
```

`search` takes a case-insensitive regex. `--json` on `lib` prints the raw entry.

## Where the catalog comes from

`catalog.py` reads, in order: `--boards PATH`, `$OBSERV_VIZ_BOARDS`, the observ-viz
checkout this skill sits in, and otherwise GitHub `main` (`--fetch` forces that; the
copy lands in `~/.cache/observ-viz/`).

`docs/boards.json` is generated (`just docs-boards`, scripts/gen-lib-doc.py) and
committed, so it can lag the Jsonnet by a commit or two. When the answer matters for
a change, confirm in `libs/<lib>/` and, for what is deployed, in the live system
(telemetry-query `rules`, board-verify).

## Reading an entry

- **library name** (`kubernetes.coredns`) is the path under `g.libs`; its source is
  under `libs/`.
- **uid** is the Grafana board uid; **folder** is where the monitor-tools job files it.
- **signals** carry the PromQL with board variables (`$job`, `$__rate_interval`)
  still in it - substitute them before running one (telemetry-query).
- **alerts** carry severity, `for`, summary and expression. The runbook is on the
  board's **Runbooks** tab (variable `signals` = Show): the alert's `runbook`
  annotation, or a generated meaning / impact / diagnosis / mitigation page.
- `metric` reports "seen live" when the exporter inventory recorded the metric on a
  real target, and "matches its patterns" when only a name pattern fits.

## What the catalog does not know

- Upstream mixin boards (kubernetes-mixin, alertmanager-mixin, Pyrra SLO rules) are
  not observ-viz libraries; `board` and `alert` say so.
- Whether a metric exists *in a given cluster now* - that is telemetry-query
  (`metrics --match`, `series`).
- A non-string expression (`<not a string: false>`) marks a broken rule in the source.
  Report it; it is a bug to fix in the library.
