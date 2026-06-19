// observ-viz variable veneer (hand-written).
// v2beta1 variable KINDS (note: the serialized kind has NO 'Kind' suffix, and v1
// 'type' is gone). Merged over gen/variable/main.libsonnet setters per kind.
{
  query: {
    new(name): { kind: 'QueryVariable', spec: { name: name } },
    // a datasource-typed query, e.g. a Prometheus query. exprObj is the
    // DataQuery.spec; datasourceVar names the datasource template variable.
    withQuery(dsType, exprObj, datasourceVar='datasource'): {
      spec+: {
        query: {
          kind: 'DataQuery',
          group: dsType,
          version: 'v0',
          datasource: { name: '${' + datasourceVar + '}' },
          spec: exprObj,
        },
      },
    },
    // convenience: a Prometheus label_values() query.
    withLabelValues(label, metric, datasourceVar='datasource'): self.withQuery(
      'prometheus',
      { qryType: 1, query: 'label_values(' + metric + ', ' + label + ')', refId: 'A' },
      datasourceVar,
    ),
  },
  datasource: {
    new(name, pluginId): { kind: 'DatasourceVariable', spec: { name: name, pluginId: pluginId } },
  },
  custom: { new(name): { kind: 'CustomVariable', spec: { name: name } } },
  interval: { new(name): { kind: 'IntervalVariable', spec: { name: name } } },
  text: { new(name): { kind: 'TextVariable', spec: { name: name } } },
  constant: { new(name, value): { kind: 'ConstantVariable', spec: { name: name, query: value } } },
  groupBy: { new(name): { kind: 'GroupByVariable', spec: { name: name } } },
  adhoc: { new(name): { kind: 'AdhocVariable', spec: { name: name } } },
}
