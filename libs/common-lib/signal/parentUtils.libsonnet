// Subset of grafana common-lib/utils.libsonnet used by the signal modules.
// Pure string/label helpers (datasource-agnostic). Ported verbatim, with
// std.member/std.objectKeysValues avoided for the C++ _jsonnet binding.
{
  local this = self,

  // For PromQL or LogQL
  labelsToPromQLSelector(labels):: std.join(',', ['%s=~"$%s"' % [label, label] for label in labels]),
  labelsToLogQLSelector(labels):: this.labelsToPromQLSelector(labels),
  labelsToPromQLSelectorAdvanced(labels):: std.join(',', ['%s=~"${%s:regex}"' % [label, label] for label in labels]),

  labelsToPanelLegend(labels, separator='/'):: std.join(separator, ['{{%s}}' % [label] for label in labels]),

  toSentenceCase(string)::
    std.asciiUpper(string[0]) + std.slice(string, 1, std.length(string), 1),

  // keep last n elements of an array (xtd.array.slice(arr, -1) equivalent for n=-1)
  sliceTail(arr, n)::
    if std.length(arr) == 0 then []
    else if n < 0 then arr[std.length(arr) + n:]
    else arr[n:],
}
