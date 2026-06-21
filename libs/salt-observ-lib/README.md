# salt-observ-lib

Salt observability — observe **Salt itself** (the event bus: highstate/orchestrate
jobs, returns, minion lifecycle) and ship it to the Grafana stack using **Grafana
Alloy** as the collector.

Part of the [observ-viz](../../) ecosystem; the bundled dashboards visualize Salt
job activity, success/failure and duration.

## Architecture

```
Salt event bus ──> saltext.alloy engine (master) ──http/loki-push──> Alloy
                       (Python: tag normalization,                    │
                        highstate summary, job args)        loki.process (labels,
                                                            salt_duration / salt_success)
                                                                       │
                                                          ┌────────────┴───────────┐
                                                       Loki (logs)        Prometheus (metrics)
                                                                       │
                                                                  Grafana dashboards
```

This is an **Alloy** rewrite of the Vector-based original (see *Credits*): the
heavy event processing that lived in Vector's VRL transforms now runs in the
Python salt engine (where it's simpler), and Alloy handles labeling, metric
derivation and shipping.

## Layout

| Path | Purpose |
|------|---------|
| `alloy-engine/` | `saltext.alloy` — Salt engine: event bus → enrich → push to Alloy `loki.source.api` |
| `states/alloy/` | salt states: `agent.sls` (install Alloy + `files/config.alloy`), `engine.sls` (install the saltext + configure the master) |
| `states/tempo/`, `states/postgresql/` | optional backend pieces inherited from the base (traces relay, cache) |
| `dashboards/default/` | Overview + Job-View dashboards (`{job="salt_events"}`, `salt_duration`, `salt_success`) |
| `docs/` | Sphinx docs |

## Quick start

```yaml
# pillar
salt_observ:
  loki_url: http://loki:3100/loki/api/v1/push
  loki_tenant: gedu
  prom_url: http://mimir:9009/api/v1/push
  prom_tenant: gedu
```

```sh
salt 'salt-master' state.apply salt-observ-lib.states.alloy   # installs alloy + engine
```

## Credits

This project is based on **[salt-grafana](https://gitlab.com/turtletraction-oss/salt-grafana)**
by Max Arnold and contributors (turtletraction.com / idaaas.com) — see the
[AUTHORS](AUTHORS) file. The original ships a Vector + grafana-agent collector;
this fork replaces them with Grafana Alloy.
