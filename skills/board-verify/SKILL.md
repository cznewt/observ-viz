---
name: board-verify
description: Verify a Grafana dashboard against live data - resolve its variables the way Grafana does, honour the show/hide conditions on tabs and rows, run every visible panel query and report empty, failing and slow panels per tab - then explain each empty panel and render images when a picture is needed. Use after changing or deploying an observ-viz library or any dashboard, when someone says a board is empty, broken or "shows no data", when checking a board against a new cluster, tenant or datasource, and before calling dashboard work done.
allowed-tools: Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/board_check.py *) Bash(python3 ${CLAUDE_SKILL_DIR}/../telemetry-query/scripts/ovq.py *)
---

# Board verify

A board that renders is not a board that works: a renamed label, a wrong tenant or
an exporter that is not deployed leaves panels empty without any error. Opening the
board in a browser and looking at every tab is slow, and an agent cannot do it.
`scripts/board_check.py` (`${CLAUDE_SKILL_DIR}/scripts/board_check.py`) does what the
browser would: it reads the board (schema v2 and v1), resolves its variables in
order (datasource, label_values / query_result, custom, constant), evaluates the
conditional-rendering rules (`$has_pods != ""`, `$signals == Show`, show-if-data),
sends each visible panel's queries through `/api/ds/query` and classifies them.

It needs the telemetry-query skill next to it (it imports its `ovq.py`) and the
same `GRAFANA_URL` / `GRAFANA_TOKEN`, preferably from `--env` (a file or a profile
name such as `monlab`).

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/board_check.py --env monlab observ-viz-coredns
python3 ${CLAUDE_SKILL_DIR}/scripts/board_check.py --env monlab observ-viz-coredns --var loki_datasource=loki-monolith --tab Overview
python3 ${CLAUDE_SKILL_DIR}/scripts/board_check.py --env monlab compute-linux-overview --var instance=newt-mon-kube-alpha --from now-6h
python3 ${CLAUDE_SKILL_DIR}/scripts/board_check.py --env monlab observ-viz-coredns --hidden --json        # also the gated sections; machine output
```

Exit status: 0 no query failed, 1 a query failed (with `--strict` also an empty
visible panel), 2 the board could not be read.

## Reading the result

The first lines show the time range and every variable's value - check them first:
a wrong variable explains a whole board of empty panels.

| Status | Meaning | What to do |
|--------|---------|------------|
| `ok` (with counts) | data came back: `A:3` = query A returned 3 series or rows | nothing |
| `EMPTY` | the queries ran and returned nothing | explain it (below) |
| `ERROR` | the backend refused the query; the message follows | a bug: fix the query or the variable |
| `hidden` | a condition hides the section (shown in brackets) | expected; `--hidden` runs them anyway |
| `hidden (no data)` | a show-if-data section with no data | expected on targets without that exporter |
| `no queries` / `skipped` | text panel, or a panel reusing another's data | nothing |
| `SLOW n s` | the panel took longer than `--slow` (5 s) | simplify, or use a recording rule |

## Explaining an empty panel

An empty panel is either correct (nothing to show) or a bug. Decide which before you
report it, with the telemetry-query skill:

1. **Datasource / tenant.** `datasource=mimir-dev (first by name: the board saves
   none)` means Grafana picks it too. Re-run with `--var datasource=<other>` - if the
   panel fills, the board needs a saved default or the data is in another tenant.
2. **Variables.** An `empty` variable (`has_pods=""`, `cluster=""`) hides or empties
   everything that reads it. Run the variable's query by hand
   (`python3 ${CLAUDE_SKILL_DIR}/../telemetry-query/scripts/ovq.py --env monlab labels --ds ... cluster --match '...'`).
3. **Labels.** The metric exists but not with these labels:
   `ovq.py series --ds ... --match '<metric>'` and compare label names and values
   with the query.
4. **The metric is not there.** `ovq.py metrics --match '{job="..."}'` and
   `catalog.py metric <name>` (which exporter or collector produces it). An exporter
   or collector that is not deployed is a deployment gap, not a board bug.
5. **Legitimately quiet.** A Logs row of a quiet service, a limits query for a pod
   without limits, an error-rate panel with no errors - say so and move on.

Report a board as a list per tab: what is empty, which of the five causes it is, the
evidence (the query you ran and its answer) and the fix you suggest.

## Pictures

When the question is visual ("does the layout work", "show me the board"):

- If Grafana has the image renderer (`/api/frontend/settings` -> `rendererAvailable`),
  `GET /render/d-solo/<uid>?panelId=<id>&width=1000&height=500&from=now-6h&to=now`
  with the token returns a PNG of one panel (`panelId` is the element's `spec.id`).
- Otherwise observ-viz screenshots every tab with Playwright in Docker:
  `SHOTS_GRAFANA_URL=... SHOTS_GRAFANA_TOKEN=... just docs-shots build/shots --uids <uid>`
  in the observ-viz checkout writes `build/shots/<uid>/NN-<tab>.webp`; read those
  images to look at them. The monitoring lab has no renderer, so use this there.

## Keep it light

`--jobs` (default 4) panels run in parallel. On a shared, small stack keep it at 4 or
below and check one board at a time; a 40-panel board takes about 5-10 seconds.
