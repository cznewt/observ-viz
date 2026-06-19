// observ-viz reusable ALERTS-metric signals (hand-written).
// Built on the lean signal abstraction; reused by the alerts-overview pattern
// and any board that wants firing-alert counts. Set filteringSelector to scope.
local signal = import 'signal/main.libsonnet';

local alertsSignal(name, datasource, extra, selector) =
  signal.new(name, 'prometheus', datasource,
             'ALERTS{alertstate="firing"' + extra + ', %(queriesSelector)s}', 'short')
  .filteringSelector(selector);

{
  firing(datasource, selector=''):
    alertsSignal('Firing alerts', datasource, '', selector),
  critical(datasource, selector=''):
    alertsSignal('Critical alerts', datasource, ', severity="critical"', selector),
  warning(datasource, selector=''):
    alertsSignal('Warning alerts', datasource, ', severity="warning"', selector),
  info(datasource, selector=''):
    alertsSignal('Info alerts', datasource, ', severity="info"', selector),
}
