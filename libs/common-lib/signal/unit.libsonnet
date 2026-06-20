// Unit derivation for signals (ported from grafana signalUtils.generateUnits).
// For a rate/irate counter, seconds->percent, requests->rps, packets->pps;
// otherwise the unit passes through unchanged.
{
  generateUnits(type, unit, rangeFunction)::
    if type == 'counter' && (rangeFunction == 'rate' || rangeFunction == 'irate') then
      (
        if unit == 'seconds' || unit == 's' then 'percent'
        else if unit == 'requests' then 'rps'
        else if unit == 'packets' then 'pps'
        else unit
      )
    else unit,
}
