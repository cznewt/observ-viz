// observ-viz reusable Prometheus alert-rule builder (hand-written).
// Emits the rule-group shape consumed by the monitor-tools pipeline
// (prometheusAlerts+:: { groups: [...] }).
{
  // new(name, expr, ...) -> a single alerting rule.
  new(name, expr, forDuration='5m', severity='warning', labels={}, annotations={}): {
    alert: name,
    expr: expr,
    'for': forDuration,
    labels: { severity: severity } + labels,
    annotations: annotations,
  },

  // record(name, expr, labels) -> a single recording rule.
  record(name, expr, labels={}): {
    record: name,
    expr: expr,
    labels: labels,
  },

  // group(name, rules, interval) -> a rule group (alerting or recording).
  group(name, rules, interval='1m'): {
    name: name,
    interval: interval,
    rules: rules,
  },

  // alerts(groups) -> the prometheusAlerts document.
  alerts(groups): { groups: groups },
}
