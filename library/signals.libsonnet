// observ-viz common signal presets (hand-written).
// Reusable logical metrics expressed as signals; consumers set the
// filteringSelector to scope them. expr uses %(queriesSelector)s.
local signal = import 'signal/main.libsonnet';

{
  requestRate(datasource, selector=''):
    signal.new('Request rate', 'prometheus', datasource,
               'sum(rate(http_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps')
    .filteringSelector(selector),

  errorRatio(datasource, selector=''):
    signal.new('Error ratio', 'prometheus', datasource,
               'sum(rate(http_requests_total{%(queriesSelector)s,status=~"5.."}[$__rate_interval])) / sum(rate(http_requests_total{%(queriesSelector)s}[$__rate_interval]))',
               'percentunit')
    .filteringSelector(selector),

  latencyP95(datasource, selector=''):
    signal.new('p95 latency', 'prometheus', datasource,
               'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))',
               's')
    .filteringSelector(selector),

  up(datasource, selector=''):
    signal.new('Up', 'prometheus', datasource, 'up{%(queriesSelector)s}', 'short')
    .filteringSelector(selector),

  cpuUsage(datasource, selector=''):
    signal.new('CPU usage', 'prometheus', datasource,
               'sum(rate(process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval]))', 'short')
    .filteringSelector(selector),

  memoryUsage(datasource, selector=''):
    signal.new('Memory usage', 'prometheus', datasource,
               'process_resident_memory_bytes{%(queriesSelector)s}', 'bytes')
    .filteringSelector(selector),
}
