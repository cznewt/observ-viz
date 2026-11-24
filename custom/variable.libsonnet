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
    // range-scoped values: every value of `label` that had a sample anywhere in
    // the dashboard time range (a pod gone three days ago still shows on a 7d
    // view). label_values() only sees what the series/label API returns for the
    // query window, and a range can't go inside it; query_result() takes plain
    // PromQL, where $__range does interpolate. Refreshes on time-range change.
    // qryType 3 = "Query result" (varQuery is what the editor shows; query is
    // the classic string the datasource runs).
    withRangeValues(label, selector, datasourceVar='datasource'):
      self.withRangeQuery('count by (' + label + ') (count_over_time(' + selector + '[$__range]))', label, datasourceVar),
    // the general form: any PromQL expr (use $__range for the window) whose
    // result carries the value as label `label`.
    withRangeQuery(expr, label, datasourceVar='datasource'):
      self.withQuery(
        'prometheus',
        { qryType: 3, varQuery: expr, query: 'query_result(' + expr + ')', refId: 'A' },
        datasourceVar,
      )
      + { spec+: { regex: '/' + label + '="([^"]+)"/', refresh: 'onTimeRangeChanged' } },
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
