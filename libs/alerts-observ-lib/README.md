# alerts-observ-lib

An observ-viz onboard of grafana/jsonnet-libs **alerts-observ-lib**. Builds an
**Alerts overview** from the `ALERTS` metric — reusable **signals**,
**annotations** and **panels**, plus a dashboard.

```jsonnet
local a = g.libs.alerts.new({ filteringSelector: 'cluster="$cluster"', groupMode: 'custom', groupLabels: ['namespace'] });

a.grafana.dashboard          // the alerts-overview board
a.grafana.panels.alertsOverview   // reuse the alert-list panel on any board
a.grafana.annotations.critical    // reuse the firing-critical annotation
a.signals.firing                  // the ALERTS signal
a.asMonitoringMixin()             // { grafanaDashboards+:: {...} }
```

- **signals** — `firing`, `critical`, `warning`, `info` (from `common-lib/alert`).
- **annotations** — `critical`/`warning`/`info` firing-alert markers, built from
  the reusable `common.annotations` primitives.
- **panels** — `alertsOverview` (alert-list), `firingTable`, `timeline`, +
  by-severity stats.

`config`: `{ uid, dashboardTitle, dashboardTags, datasource, filteringSelector,
groupMode, groupLabels }`.
