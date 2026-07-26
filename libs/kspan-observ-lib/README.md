# kspan-observ-lib

Kubernetes object events as traces: [kspan](https://github.com/weaveworks-experiments/kspan)
runs in both clusters (`*-prg-infra-kspan` targets), emitting OTLP spans for
object lifecycle events (Deployment rollouts, Pod pulls/starts, ...) to the
site salt-master pod's Alloy (`otelcol.receiver.otlp` :4317 on the master
node) → Tempo on newt-prg-kube-bravo.

`dashboards/kspan-traces.json`: RETIRED as a standalone board — its panels
now live as the metric-gated **Cluster Events** tab on the Kubernetes cluster
board (`libs/kubernetes-observ-lib/cluster.libsonnet`). Kept as reference for
the TraceQL queries. Originally: TraceQL panels over the
`newt-tempo` datasource — kspan object events on top, the full recent trace
stream (kspan + salt jobs) below. Deploy like the salt-observ-lib JSON boards.

Known limitation: spans from both clusters share one Tempo without a cluster
resource attribute yet; the root service name is the workload/controller name.
