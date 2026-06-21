# Alerts overview  (`g.libs.alerts`)

Dashboard uid `observ-viz-alerts` · 4 signals · 0 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `critical` | short | `ALERTS{alertstate="firing", severity="critical", }` | — |
| `firing` | short | `ALERTS{alertstate="firing", }` | — |
| `info` | short | `ALERTS{alertstate="firing", severity="info", }` | — |
| `warning` | short | `ALERTS{alertstate="firing", severity="warning", }` | — |

## Dashboard

