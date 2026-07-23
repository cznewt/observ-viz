# alerts

- **source**: prometheus/mimir alerting state
- **patterns**: `ALERTS`, `ALERTS_FOR_STATE`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| alerts | critical | `ALERTS` |
| alerts | firing | `ALERTS` |
| alerts | info | `ALERTS` |
| alerts | warning | `ALERTS` |

## Live metrics (2)

- `ALERTS`
- `ALERTS_FOR_STATE`
