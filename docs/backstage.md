# Backstage

observ-viz is registered as a Backstage **library** component
(`catalog-info.yaml`) with TechDocs (this site).

The **scenarios** also generate a Backstage catalog modelling the observability
estate as a Domain → Systems → Components:

```sh
python3 scripts/gen-catalog.py
# -> backstage/observ-viz-catalog.yaml
```

- one **Domain** `observability`
- a **System** per scenario (`observ-viz-linux`, `observ-viz-kubernetes`, …)
- a **Component** per member pack, `partOf` its system, annotated with the
  Grafana dashboard folder it owns.

```yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata: { name: observ-viz-linux, title: Linux host }
spec: { owner: monitoring, domain: observability }
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: observ-viz-linux-host
  annotations: { grafana.app/dashboard-folder: observ-viz-scn-linux }
spec: { type: observability-pack, owner: monitoring, system: observ-viz-linux }
```

Point a Backstage catalog location at `backstage/observ-viz-catalog.yaml` to
import the whole estate.
