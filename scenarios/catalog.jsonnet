// Backstage catalog for the observ-viz scenarios: one Domain, a System per
// scenario, and a Component per member pack. Emit with scripts/gen-catalog.py.
local scenarios = import 'scenarios/main.libsonnet';
local all = [
  scenarios.linux.new(),
  scenarios.docker.new(),
  scenarios.kubernetes.new(),
  scenarios.lgtm.new(),
];
local domain = {
  apiVersion: 'backstage.io/v1alpha1',
  kind: 'Domain',
  metadata: { name: 'observability', title: 'Observability', tags: ['observ-viz'] },
  spec: { owner: 'monitoring' },
};
[domain]
+ [s.backstage.system for s in all]
+ std.flattenArrays([s.backstage.components for s in all])
