// observ-viz reusable Loki query builders (hand-written).
local query = import 'custom/query.libsonnet';

{
  // loki(datasource, selector, pipeline) -> a LogQL stream query.
  //   selector: label matchers WITHOUT braces, e.g. 'job="api", level="error"'
  //   pipeline: optional LogQL pipeline, e.g. '|= "error" | json'
  loki(datasource, selector, pipeline=''):
    query.loki.new(datasource, '{' + selector + '}' + (if pipeline != '' then ' ' + pipeline else '')),

  // rate(datasource, selector, pipeline) -> log volume (lines/s).
  rate(datasource, selector, pipeline=''):
    query.loki.new(
      datasource,
      'sum(rate({' + selector + '}' + (if pipeline != '' then ' ' + pipeline else '') + '[$__rate_interval]))'
    ),
}
