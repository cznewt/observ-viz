# The monitoring lab (grafana.monlab.newt.cz)

The observ-viz boards run in the monitoring lab: one Kubernetes node
(`newt-mon-kube-alpha`, cluster label `monitoring-lab`), a shared Grafana that the
nightly monitor-tools job fills with every observ-viz board and rule, and per-student
Jupyter environments. Token file: `~/.config/observ-viz/monlab.env` (a Viewer
service account named `agents`).

## Datasources (2026-10)

| Name | Type | Reads |
|------|------|-------|
| `mimir-monolith` | prometheus | Mimir, tenant `anonymous` (federated header: series carry `__tenant_id__`) |
| `mimir-dev` / `mimir-prod` | prometheus | Mimir tenants `dev` / `prod` federated with `anonymous` |
| `mimir-rules` | prometheus | Mimir tenant `anonymous`, single tenant: the one for `rules` and ruler `alerts` |
| `prometheus-server` | prometheus | the cluster's own Prometheus (kube-monitor): Mimir's, Loki's and the node's internals |
| `loki-monolith` | loki | tenant `anonymous` (every pod log of the cluster) |
| `loki-dev` / `loki-prod` | loki | `dev` / `prod` with `anonymous` |
| `tempo-monolith`, `tempo-dev`, `tempo-prod` | tempo | the same split for traces |
| `pyroscope-monolith` | grafana-pyroscope-datasource | profiles (single tenant) |
| `alertmanager-server` | Alertmanager | `alertmanager-server-1`, the Alertmanager of `prometheus-server` |
| `backstage-graphql` | Infinity | the Backstage catalog |

Students' tenants (`test`, `komarek`, ...) are not behind these datasources; they
are read from the student's own Jupyter with `X-Scope-OrgID: $MIMIR_TENANT_ID`.

## Label conventions

- Cluster metrics from k8s-monitoring use `job="integrations/kubernetes/<name>"`
  (`kube-state-metrics`, `kube-dns`, `cadvisor`, `kubelet`, ...), plus `cluster`,
  `k8s_cluster_name`, `namespace`, `pod`, `container`.
- Lab services are `job="<namespace>/<app>"`, e.g. `global-monitor-alert-handler/alert-handler-server`.
- Pod logs in Loki carry `cluster`, `namespace`, `pod`, `container`, `job`,
  `service_name`, `level`.

## Boards and the datasource variable

observ-viz boards save no datasource choice, so Grafana opens them on the first
datasource of the type by name: `mimir-dev` and `loki-dev`. Because those federate
`anonymous`, the shared boards still fill. For logs of lab services, `loki-monolith`
is the one to pick.

## Caveats

- The node runs close to its memory limit; keep queries narrow.
- Mimir 2.10.3 holds the tenants' Alertmanagers. If tenant alerts stop arriving,
  compare `sum by (user) (increase(cortex_alertmanager_notifications_total{integration="webhook"}[1h]))`
  on `prometheus-server` with the alerts that should have gone out; a failure before
  the webhook is only in Mimir's log (`invalid service state`, until 2026-10-21 the
  replication-factor-1 bug).
- Grafana here has no image renderer (`rendererAvailable: false`).
