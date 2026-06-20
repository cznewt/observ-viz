// observ-viz signal namespace.
//
// Two coexisting APIs, both rendering native observ-viz v2 elements:
//
// 1. The lean v2-native signal (unchanged, backward compatible). Used across all
//    24 observ-libs + patterns:
//      new(name, type, datasource, expr, unit) -> signal with the .withExpr/
//      .filteringSelector/.aggLevel/.asTimeSeries/.asTarget/... chain.
//    Plus collection helpers addSignal/asElements/asTargets.
//
// 2. The grafana common-lib signal engine, ported to observ-viz v2 builders:
//      init(...)               -> a signals collection with .addSignal(...)
//      addSignal(...)          -> a base signal (gauge/counter/histogram/info/
//                                 raw/log/stub) with asTimeSeries/asStat/asTable/
//                                 asGauge/asStatusHistory/asTarget/asTableTarget/
//                                 asTableColumn/asPanelMixin/asPanelExpression/
//                                 asRuleExpression + all withX modifiers.
//      unmarshallJson / unmarshallJsonMulti  -> the declarative forms.
//      getVarMetric / collectMetricExprs     -> helpers.
local signal = import 'libs/common-lib/signal/signal.libsonnet';
local engine = import 'libs/common-lib/signal/engine.libsonnet';

engine
+ {
  // --- lean v2-native signal (backward compatible) -------------------------
  // new(name, type, datasource, expr, unit) -> a single signal.
  new(name, type, datasource, expr, unit='short'):
    signal.new(name, type, datasource, expr, unit),

  // collection helpers ------------------------------------------------------
  // addSignal(signals, name, sig) -> signals map with sig added.
  // NOTE: this 3-arg lean helper shadows the engine's init-scoped addSignal,
  // which is only reachable on an init(...) collection (different receiver),
  // so both remain usable.
  addSignal(signals, name, sig): signals + { [name]: sig },

  // asElements(signals, viz) -> a ready elements map { name: PanelKind }.
  asElements(signals, viz='timeSeries'): {
    [name]:
      if viz == 'stat' then signals[name].asStat()
      else if viz == 'table' then signals[name].asTable()
      else signals[name].asTimeSeries()
    for name in std.objectFields(signals)
  },

  // asTargets(signals) -> [PanelQuery, ...] for a single multi-series panel.
  asTargets(signals): [signals[name].asTarget() for name in std.objectFields(signals)],
}
