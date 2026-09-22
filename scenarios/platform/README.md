# Platform — deployment profile

Site-agnostic platform boards: Kubernetes clusters / cluster / pods /
containers, Linux and Windows nodes (each with a metric-gated Kubelet tab),
systemd units, process groups, ingress-nginx, OpenCost, Argo CD and the
Backstage catalog. Alerts and recording rules of every member are merged.

```sh
python3 scripts/deploy.py platform     # render + apply into "Platform (observ-viz)"
```

Through monitor-tools: the `observ-viz` mixin with `config.scenario: platform`.
