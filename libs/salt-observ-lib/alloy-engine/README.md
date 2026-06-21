# saltext.alloy

A Salt engine that reads the Salt event bus and pushes enriched events to a
Grafana Alloy `loki.source.api` endpoint (Loki push protocol).

It replaces the Vector-based engine of the original salt-grafana project: the
event processing that used to live in Vector's VRL transforms (tag
normalization, highstate summaries, job-arg extraction) is done here in Python,
and Alloy handles labeling, metric derivation and shipping
(`states/alloy/files/config.alloy`).

## Configure (Salt master)

```yaml
engines:
  - alloy:
      url: "http://127.0.0.1:9000"   # alloy loki.source.api base url
      exclude_tags:
        - salt/auth
        - minion_start
        - minion/refresh/*
```

Install with `pip install saltext.alloy` (or via `states/alloy/engine.sls`).
