// Backstage catalog for the deployment profiles: a Domain, a System per
// profile, a Component per member observ-lib. Emit with scripts/gen-catalog.py.
local scenarios = import 'scenarios/main.libsonnet';
local all = [scenarios[n] for n in std.objectFields(scenarios)];
local domain = {
  apiVersion: 'backstage.io/v1alpha1',
  kind: 'Domain',
  metadata: { name: 'observability', title: 'Observability', tags: ['observ-viz'] },
  spec: { owner: 'monitoring' },
};
[domain]
+ [s.backstage.system for s in all]
+ std.flattenArrays([s.backstage.components for s in all])
