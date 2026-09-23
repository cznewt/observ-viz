// observ-viz USE method (hand-written).
// Utilisation, Saturation and Errors per resource, the node mixin's USE boards
// generalised: a source profile (libs/analysis-observ-lib/sources.libsonnet)
// says which four resources to read and how, so the same board covers nodes
// (node_exporter) and containers (cAdvisor).
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-use',
      dashboardTitle: 'USE method',
      dashboardTags: ['observ-viz', 'analysis', 'use'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varLabels: [],
      legendLabels: [],
      tabbed: true,
    } + config;
    local src = cfg.source;
    local by = std.join(', ', src.groupBy);
    local sel = filters.selector(cfg);
    local legendBy = std.join(' / ', ['{{' + l + '}}' for l in src.groupBy]);
    // the profile's exprs are templates over the selector and the grouping
    local render(expr) = expr % { sel: '%(queriesSelector)s', by: by };
    local kinds = ['utilisation', 'saturation', 'errors'];
    local kindDesc = {
      utilisation: 'How busy the resource is - the share of time it was doing work.',
      saturation: 'How much work is waiting - queued, throttled or reclaimed.',
      errors: 'Operations the resource itself failed.',
    };
    local key(res, kind) = std.asciiLower(res) + '_' + kind;
    local cap(s) = std.asciiUpper(std.substr(s, 0, 1)) + std.substr(s, 1, std.length(s));

    local signals = {
      [key(res, kind)]:
        signal.new(cap(kind) + ' - ' + res, 'prometheus', cfg.datasource,
                   render(src.resources[res][kind].expr), src.resources[res][kind].unit)
        .filteringSelector(sel).withLegendFormat(legendBy).withDescription(kindDesc[kind])
      for res in std.objectFields(src.resources)
      for kind in kinds
      if std.objectHas(src.resources[res], kind)
    };

    pack.build(cfg + {
      description: 'The USE method over ' + std.asciiLower(src.title) + '. ' + src.description,
      references: [
        { title: 'The USE method', url: 'https://www.brendangregg.com/usemethod.html', description: 'Brendan Gregg: for every resource, check utilisation, saturation and errors' },
        { title: 'node-mixin USE boards', url: 'https://github.com/prometheus/node_exporter/tree/master/docs/node-mixin', description: 'the node_exporter boards this generalises' },
      ],
      rowLabels: src.groupBy,
      overviewSignals: [key(res, 'utilisation') for res in std.objectFields(src.resources)],
    }, signals, [
      {
        title: res,
        width: 8,
        height: 8,
        elements: {
          [key(res, kind)]: signals[key(res, kind)].asTimeSeries(cap(kind))
          for kind in kinds
          if std.objectHas(src.resources[res], kind)
        },
      }
      for res in std.objectFields(src.resources)
    ]),
}
