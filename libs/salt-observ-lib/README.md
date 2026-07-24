# salt-observ-lib

Salt job observability (port of [salt-grafana](https://gitlab.com/turtletraction-oss/salt-grafana),
Alloy edition — Vector and the flask tempo-relay are replaced by the
`saltext.vector.engines.alloy` engine baked into ghcr.io/craftama/salt-master).

## Pipeline

- **Engine** (`engines.conf` on both masters): enriches `salt/job|run/*/ret` events
  (tag genericization, arg extraction, per-state summary rollup, traceID = zero-padded jid) and
  - pushes Loki-push JSON to the in-pod **Alloy** `loki.source.api` :9911 →
    `salt_job_{duration_seconds,success,states_total,states_changed,states_failed}`
    gauges (labels cluster/id/fun/job_name) → Mimir; log lines → Loki (`{job="salt_events"}`)
  - emits **OTLP traces** to Tempo (root span per job, child span per state with real
    start/duration; failed states carry changes/comment). Highstate/apply/sls shapes
    included, not just orchestrations.
- **Job cache**: `master_job_cache: pgjsonb` (`job_cache.conf`) → postgres-server db `salt`
  (`jids`, `salt_returns`) on both masters. Gedu postgres runs hostNetwork so grafana
  reads it over wireguard (10.13.13.1:5432).
- **Tempo**: monolith on newt-prg-kube-bravo (hostNetwork; OTLP 4317/4318, query 3200),
  target `newt-prg-infra-tempo`.
- **Datasources** (newt-prg-infra-grafana): `newt-tempo`, `gedu-salt-pg`, `newt-salt-pg`,
  plus a Loki derived field linking `traceID` → Tempo.

## Dashboards

`dashboards/*.json` (classic schema, adapted from upstream: datasource UIDs pinned,
`salt_duration`→`salt_job_duration`): deploy with

    curl -X POST "$GRAFANA_URL/api/dashboards/db" -H "Authorization: Bearer $GRAFANA_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(python3 -c 'import json;print(json.dumps({"dashboard":json.load(open(F)),"overwrite":True}))' F=dashboards/salt-jobs-overview.json)"
