// observ-viz reusable Loki-based signals (hand-written).
local signal = import 'signal/main.libsonnet';

{
  rate(datasource, selector):
    signal.new('Log rate', 'loki', datasource,
               'sum(rate({' + selector + '}[$__rate_interval]))', 'logs'),

  errorRate(datasource, selector):
    signal.new('Error log rate', 'loki', datasource,
               'sum(rate({' + selector + '} |~ "(?i)(error|fail|fatal)"[$__rate_interval]))', 'logs'),
}
