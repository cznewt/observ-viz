// Dashboard template variables for a signals collection (ported from grafana
// common-lib/common/variables/variables.libsonnet, re-expressed via observ-viz's
// v2beta1 variable veneer). The load-bearing outputs are the queriesSelector*
// strings consumed by expr templating; the variable lists (multiInstance/
// singleInstance/datasources) render native v2beta1 *Variable resources.
local var = (import './g.libsonnet').dashboard.variable;
local utils = import './parentUtils.libsonnet';

{
  new(
    filteringSelector,
    groupLabels,
    instanceLabels,
    varMetric='up',
    enableLokiLogs=false,
    customAllValue='.+',
    prometheusDatasourceName=if enableLokiLogs then 'prometheus_datasource' else 'datasource',
    prometheusDatasourceLabel=if enableLokiLogs then 'Prometheus data source' else 'Data source',
    adHocEnabled=false,
    adHocLabels=[],
  ): {
    local root = self,
    // strip trailing/starting comma if present.
    local _filteringSelector = std.stripChars(std.stripChars(filteringSelector, ' '), ','),

    local varMetricTemplate(varMetric, chainSelector) =
      if std.type(varMetric) == 'array' && chainSelector != ''
      then '{__name__=~"%s",%s}' % [std.join('|', std.uniq(varMetric)), chainSelector]
      else if std.type(varMetric) == 'array' && chainSelector == ''
      then '{__name__=~"%s"}' % std.join('|', std.uniq(varMetric))
      else if std.type(varMetric) == 'string'
      then '%s{%s}' % [varMetric, chainSelector]
      else error ('varMetric must be array or string'),

    local labelChain(labels) =
      // build chainSelector strings for each label (chained variables)
      local sel(prev) =
        std.join(',', std.filter(function(x) std.length(x) > 0, [
          _filteringSelector,
          utils.labelsToPromQLSelector(prev),
        ]));
      std.mapWithIndex(function(i, label) { label: label, chainSelector: sel(labels[:i]) }, labels),

    local queryVar(chainVar, multiInstance, isInstance) =
      var.query.new(chainVar.label)
      + var.query.withLabelValues(
        chainVar.label,
        varMetricTemplate(varMetric, chainVar.chainSelector),
        datasourceVar=prometheusDatasourceName,
      )
      + {
        spec+: {
          label: utils.toSentenceCase(chainVar.label),
          includeAll: if (!multiInstance && isInstance) then false else true,
          allValue: customAllValue,
          multi: if (!multiInstance && isInstance) then false else true,
        },
      },

    local instanceSet = std.set(instanceLabels),
    local variablesFromLabels(multiInstance) =
      [
        queryVar(cv, multiInstance, std.length(std.setInter([cv.label], instanceSet)) > 0)
        for cv in labelChain(groupLabels + instanceLabels)
      ],

    datasources: {
      prometheus:
        var.datasource.new(prometheusDatasourceName, 'prometheus')
        + { spec+: { label: prometheusDatasourceLabel, regex: '' } },
    } + (if enableLokiLogs then {
           loki:
             var.datasource.new('loki_datasource', 'loki')
             + { spec+: { label: 'Loki data source', regex: '' } },
         } else {}),

    adHoc:
      var.adhoc.new('adhoc')
      + { spec+: { label: 'Ad hoc filters', description: 'Add additional filters' } }
      + (if std.length(adHocLabels) > 0 then {
           spec+: { defaultKeys: [{ text: l, value: l } for l in adHocLabels] },
         } else {}),

    multiInstance:
      [root.datasources.prometheus]
      + variablesFromLabels(true)
      + (if adHocEnabled then [self.adHoc] else [])
      + (if enableLokiLogs then [root.datasources.loki] else []),
    singleInstance:
      [root.datasources.prometheus]
      + variablesFromLabels(false)
      + (if adHocEnabled then [self.adHoc] else [])
      + (if enableLokiLogs then [root.datasources.loki] else []),

    queriesSelectorAdvancedSyntax:
      std.join(',', std.filter(function(x) std.length(x) > 0, [
        _filteringSelector,
        utils.labelsToPromQLSelectorAdvanced(groupLabels + instanceLabels),
      ])),
    queriesSelector:
      std.join(',', std.filter(function(x) std.length(x) > 0, [
        _filteringSelector,
        utils.labelsToPromQLSelector(groupLabels + instanceLabels),
      ])),
    queriesSelectorGroupOnly:
      std.join(',', std.filter(function(x) std.length(x) > 0, [
        _filteringSelector,
        utils.labelsToPromQLSelector(groupLabels),
      ])),
    queriesSelectorFilterOnly:
      std.join(',', std.filter(function(x) std.length(x) > 0, [
        _filteringSelector,
        '',
      ])),
  },
}
