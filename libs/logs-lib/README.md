# logs-lib

An observ-viz onboard of grafana/jsonnet-libs **logs-lib**. Reusable Loki **log
panels** + a logs dashboard.

```jsonnet
local l = g.libs.logs.new({ filterSelector: 'job="myapp"', levelLabel: 'detected_level' });

l.grafana.panels.logs         // the log-stream panel
l.grafana.panels.logsVolume   // stacked log-volume by level (per-level colours)
l.grafana.panels.rate         // total log-rate stat
l.grafana.dashboard           // the logs board (volume + stream)
l.asMonitoringMixin()
```

- **panels** — `logs` (stream), `logsVolume` (stacked bars by level, with
  error/warn/info/debug colour overrides), `rate`.
- **queries** — `logs`, `volumeByLevel`, `rate` (LogQL).

`config`: `{ uid, dashboardTitle, dashboardTags, datasource, filterSelector,
levelLabel, pipeline }`.
