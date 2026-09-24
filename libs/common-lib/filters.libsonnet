// observ-viz filter helpers (hand-written).
// A pack may take two optional config keys:
//   varLabels:    ['namespace', 'pod']  cascading dashboard filter variables
//                 (pack.build turns them into label_values() variables).
//   legendLabels: ['namespace', 'pod']  series legend, '{{namespace}} / {{pod}}'.
// These turn them into the query selector and the legend format, so every pack
// wires the two the same way.
local signal = import 'libs/common-lib/signal/main.libsonnet';

local get(cfg, key, default) = if std.objectHas(cfg, key) then cfg[key] else default;

{
  // 'job=~"$job", namespace=~"$namespace", pod=~"$pod"'. An empty base selector
  // drops out rather than leaving a leading comma inside the braces.
  selector(cfg)::
    std.join(', ', std.filter(function(p) p != '',
                              [get(cfg, 'selector', 'job=~"$job"')]
                              + [l + '=~"$' + l + '"' for l in get(cfg, 'varLabels', [])])),

  // '{{namespace}} / {{pod}}', or null for Grafana's default legend.
  legendFormat(cfg)::
    local labels = get(cfg, 'legendLabels', []);
    if std.length(labels) > 0 then std.join(' / ', ['{{' + l + '}}' for l in labels]) else null,

  // sig(cfg)(name, expr, unit, description) -> a prometheus signal wired to both.
  sig(cfg)::
    local sel = self.selector(cfg);
    local legend = self.legendFormat(cfg);
    function(name, expr, unit='short', description='')
      local s = signal.new(name, 'prometheus', cfg.datasource, expr, unit)
                .filteringSelector(sel)
                .withDescription(description);
      if legend != null then s.withLegendFormat(legend) else s,
}
