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

  // withRunbook(markdown) -> attach a written runbook to a rule. The pack's
  // Runbooks tab shows it verbatim; without it the tab generates one from the
  // rule itself.
  withRunbook(markdown):: { annotations+: { runbook: markdown } },

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

  // targetDown(identity, ruleSelector, window) -> the expr of a "<app> is down"
  // alert. A bare `up == 0` fires for every down target in the tenant, so the
  // down target must also have exposed one of the app's identity metrics
  // (a *_build_info-style gauge; string or list) within `window`, joined on
  // job + instance. Caveat: a target down for longer than `window` resolves.
  targetDown(identity, ruleSelector='', window='1d')::
    local ids = if std.isArray(identity) then identity else [identity];
    local sel = if ruleSelector != '' then '{' + ruleSelector + '}' else '';
    local seen = std.join(' or ', ['max_over_time(%s%s[%s])' % [m, sel, window] for m in ids]);
    '(up%s == 0) and on (job, instance) (%s)' % [sel, seen],

  // alerts(groups) -> the prometheusAlerts document.
  alerts(groups): { groups: groups },
}
