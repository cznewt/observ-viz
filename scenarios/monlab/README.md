# Monitoring lab — deployment profile

One service board per Backstage catalog component of the monitoring-lab
cluster that has a whitebox observ-lib, built with `g.libs.services.*` and
pinned to the namespace (and pod name) each component runs in there
(`scope: { cluster, namespace, pod }`). No Alloy config: the cluster is
scraped by k8s-monitoring already.

```sh
python3 scripts/deploy.py monlab      # render + apply into "Monitoring lab — services"
```

Components without a scraped whitebox metric (argo-cd, alloy-remote-config,
jupyter, nasa-swpc-exporter, the Rust demos, kspan) are not listed: add a
scrape first, then a preset.
