// observ-viz variable veneer (hand-written).
// v2 variable KIND constructors (note: v1 'type' field is gone, replaced by
// 'kind'). Merged over gen/variable/main.libsonnet setters per kind.
{
  query: {
    new(name): { kind: 'QueryVariableKind', spec: { name: name } },
    // convenience: a Prometheus label_values() query.
    withLabelValues(label, metric): {
      spec+: { query: { kind: 'prometheus', spec: { expr: 'label_values(' + metric + ', ' + label + ')' } } },
    },
  },
  datasource: {
    new(name, pluginId): { kind: 'DatasourceVariableKind', spec: { name: name, pluginId: pluginId } },
  },
  custom: { new(name): { kind: 'CustomVariableKind', spec: { name: name } } },
  interval: { new(name): { kind: 'IntervalVariableKind', spec: { name: name } } },
  text: { new(name): { kind: 'TextVariableKind', spec: { name: name } } },
  constant: { new(name, value): { kind: 'ConstantVariableKind', spec: { name: name, query: value } } },
  groupBy: { new(name): { kind: 'GroupByVariableKind', spec: { name: name } } },
  adhoc: { new(name): { kind: 'AdhocVariableKind', spec: { name: name } } },
}
