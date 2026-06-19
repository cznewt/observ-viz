// observ-viz signal namespace — lean v2-native signal abstraction.
local signal = import 'signal/signal.libsonnet';

{
  // new(name, type, datasource, expr, unit) -> a single signal.
  new(name, type, datasource, expr, unit='short'):
    signal.new(name, type, datasource, expr, unit),

  // collection helpers ------------------------------------------------------
  // addSignal(signals, name, sig) -> signals map with sig added.
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
