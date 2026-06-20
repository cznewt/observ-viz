// Grafana common-lib signal entrypoint, ported to observ-viz (renders via v2
// builders through ./g.libsonnet). Provides init/addSignal/unmarshallJson/
// unmarshallJsonMulti + helpers. std.get/std.member/std.objectKeysValues are
// avoided for the C++ _jsonnet binding.
local variables = import './variables.libsonnet';
local counter = import './counter.libsonnet';
local gauge = import './gauge.libsonnet';
local histogram = import './histogram.libsonnet';
local info = import './info.libsonnet';
local log = import './log.libsonnet';
local raw = import './raw.libsonnet';
local stub = import './stub.libsonnet';

// helpers replacing std.get / std.member / std.objectKeysValues.
local objGet(o, f, default=null) = if std.objectHasAll(o, f) then o[f] else default;
local arrHas(arr, v) = std.length(std.find(v, arr)) > 0;
local kv(o) = [{ key: k, value: o[k] } for k in std.objectFields(o)];

{
  // DEPRECATED. Use unmarshallJsonMulti instead.
  unmarshallJson(signalsJson):
    self.init(
      datasource=objGet(signalsJson, 'datasource', if objGet(signalsJson, 'enableLokiLogs', false) then 'prometheus_datasource' else 'datasource'),
      datasourceLabel=objGet(signalsJson, 'datasourceLabel', if objGet(signalsJson, 'enableLokiLogs', false) then 'Prometheus data source' else 'Data source'),
      filteringSelector=[signalsJson.filteringSelector],
      groupLabels=signalsJson.groupLabels,
      instanceLabels=signalsJson.instanceLabels,
      interval=objGet(signalsJson, 'interval', '$__rate_interval'),
      alertsInterval=objGet(signalsJson, 'alertsInterval', '5m'),
      varMetric=objGet(signalsJson, 'discoveryMetric', 'up'),
      aggLevel=objGet(signalsJson, 'aggLevel', 'none'),
      aggFunction=objGet(signalsJson, 'aggFunction', 'avg'),
      aggKeepLabels=objGet(signalsJson, 'aggKeepLabels', []),
      legendCustomTemplate=objGet(signalsJson, 'legendCustomTemplate', null),
      rangeFunction=objGet(signalsJson, 'rangeFunction', 'rate'),
      varAdHocEnabled=objGet(signalsJson, 'varAdHocEnabled', false),
      varAdHocLabels=objGet(signalsJson, 'varAdHocLabels', []),
      enableLokiLogs=objGet(signalsJson, 'enableLokiLogs', false),
    )
    +
    {
      [s]: super.addSignal(
        name=objGet(signalsJson.signals[s], 'name', error 'Must provide name'),
        type=objGet(signalsJson.signals[s], 'type', error 'Must provide type for signal %s' % signalsJson.signals[s].name),
        unit=objGet(signalsJson.signals[s], 'unit', ''),
        nameShort=objGet(signalsJson.signals[s], 'nameShort', signalsJson.signals[s].name),
        description=objGet(signalsJson.signals[s], 'description', ''),
        aggLevel=objGet(signalsJson.signals[s], 'aggLevel', signalsJson.aggLevel),
        aggFunction=objGet(signalsJson.signals[s], 'aggFunction', objGet(signalsJson, 'aggFunction', 'avg')),
        sourceMaps=[
          {
            expr: objGet(signalsJson.signals[s], 'expr', error 'Must provide expression "expr" for signal %s' % signalsJson.signals[s].name),
            exprWrappers: objGet(signalsJson.signals[s], 'exprWrappers', []),
            rangeFunction: objGet(signalsJson.signals[s], 'rangeFunction', objGet(signalsJson, 'rangeFunction', 'rate')),
            aggFunction: objGet(signalsJson.signals[s], 'aggFunction', objGet(signalsJson, 'aggFunction', 'avg')),
            aggKeepLabels: objGet(signalsJson.signals[s], 'aggKeepLabels', objGet(signalsJson, 'aggKeepLabels', [])),
            infoLabel: objGet(signalsJson.signals[s], 'infoLabel', null),
            type: objGet(signalsJson.signals[s], 'type', error 'Must provide type for signal %s' % signalsJson.signals[s].name),
            legendCustomTemplate: objGet(signalsJson.signals[s], 'legendCustomTemplate', objGet(signalsJson, 'legendCustomTemplate', null)),
            valueMappings: objGet(signalsJson.signals[s], 'valueMappings', []),
          },
        ],
      )
      for s in std.objectFieldsAll(signalsJson.signals)
    },

  unmarshallJsonMulti(signalsJson, type='prometheus'):

    local typeArr =
      (
        if std.type(type) == 'string' then
          [type]
        else
          type
      );
    local defaultSignalSource = objGet(signalsJson, 'defaultSignalSource', 'prometheus');

    self.init(
      datasource=objGet(signalsJson, 'datasource', if objGet(signalsJson, 'enableLokiLogs', false) then 'prometheus_datasource' else 'datasource'),
      datasourceLabel=objGet(signalsJson, 'datasourceLabel', if objGet(signalsJson, 'enableLokiLogs', false) then 'Prometheus data source' else 'Data source'),
      filteringSelector=[signalsJson.filteringSelector],
      groupLabels=signalsJson.groupLabels,
      instanceLabels=signalsJson.instanceLabels,
      interval=objGet(signalsJson, 'interval', '$__rate_interval'),
      alertsInterval=objGet(signalsJson, 'alertsInterval', '5m'),
      varMetric=self.getVarMetric(signalsJson, type, defaultSignalSource),
      aggLevel=objGet(signalsJson, 'aggLevel', 'none'),
      aggFunction=objGet(signalsJson, 'aggFunction', 'avg'),
      aggKeepLabels=objGet(signalsJson, 'aggKeepLabels', []),
      legendCustomTemplate=objGet(signalsJson, 'legendCustomTemplate', null),
      rangeFunction=objGet(signalsJson, 'rangeFunction', 'rate'),
      varAdHocEnabled=objGet(signalsJson, 'varAdHocEnabled', false),
      varAdHocLabels=objGet(signalsJson, 'varAdHocLabels', []),
      enableLokiLogs=objGet(signalsJson, 'enableLokiLogs', false),
    )
    +
    {
      [s]:
        (if !std.objectHas(signalsJson.signals[s], 'name') then error ('Must provide name') else {}) +
        if std.objectHas(signalsJson.signals[s], 'sources') && std.length(signalsJson.signals[s]) > 0 then
          local name = objGet(signalsJson.signals[s], 'name', error 'Must provide name');
          local metricType = objGet(signalsJson.signals[s], 'type', error 'Must provide type for signal %s' % s);
          local validatedArr = [
            if
              objGet(signalsJson.signals[s], 'optional', false) == false
              &&
              (
                !std.objectHas(signalsJson.signals[s].sources, sourceName)
                &&
                !std.objectHas(signalsJson.signals[s].sources, defaultSignalSource)
              )
            then error 'must provide source for signal %s of type=%s' % [s, sourceName]
            else (
              if
                std.objectHas(signalsJson.signals[s].sources, sourceName) then sourceName
              else if
                std.objectHas(signalsJson.signals[s].sources, defaultSignalSource) then defaultSignalSource
            )
            for sourceName in typeArr
          ];
          local sourceMaps =
            [
              {
                expr: objGet(source.value, 'expr', error 'Must provide expression "expr" for signal %s and type=%s' % [s, source.key]),
                exprWrappers: objGet(source.value, 'exprWrappers', []),
                rangeFunction: objGet(source.value, 'rangeFunction', objGet(signalsJson, 'rangeFunction', 'rate')),
                aggFunction: objGet(source.value, 'aggFunction', objGet(signalsJson, 'aggFunction', 'avg')),
                aggKeepLabels: objGet(source.value, 'aggKeepLabels', objGet(signalsJson, 'aggKeepLabels', [])),
                infoLabel: objGet(source.value, 'infoLabel', null),
                legendCustomTemplate: objGet(source.value, 'legendCustomTemplate', objGet(signalsJson, 'legendCustomTemplate', null)),
                valueMappings: objGet(source.value, 'valueMappings', []),
              }
              for source in kv(signalsJson.signals[s].sources)
              if arrHas(validatedArr, source.key)
            ];

          (if std.length(sourceMaps) > 0 then

             super.addSignal(
               name=name,
               type=metricType,
               unit=objGet(signalsJson.signals[s], 'unit', ''),
               nameShort=objGet(signalsJson.signals[s], 'nameShort', name),
               description=objGet(signalsJson.signals[s], 'description', ''),
               aggLevel=objGet(signalsJson.signals[s], 'aggLevel', signalsJson.aggLevel),
               aggFunction=objGet(signalsJson.signals[s], 'aggFunction', objGet(signalsJson, 'aggFunction', 'avg')),
               sourceMaps=sourceMaps
             )
           else
             super.addSignal(
               name=objGet(signalsJson.signals[s], 'name', error 'Must provide name'),
               nameShort=objGet(signalsJson.signals[s], 'nameShort', name),
               type='stub',
               description=objGet(signalsJson.signals[s], 'description', ''),
             ))

        else error 'please provide sources for %s' % s

      for s in std.objectFieldsAll(signalsJson.signals)
    },

  init(
    datasource='datasource',
    datasourceLabel='Data source',
    filteringSelector=['job!=""'],
    groupLabels=['job'],
    instanceLabels=['instance'],
    interval='$__rate_interval',
    alertsInterval='5m',
    aggLevel='none',
    aggKeepLabels=[],
    aggFunction='avg',
    varMetric='up',
    legendCustomTemplate=null,
    rangeFunction='rate',
    varAdHocEnabled=false,
    varAdHocLabels=[],
    enableLokiLogs=false,
  ): self {

    local this = self,
    // accept a string filteringSelector for ergonomics (grafana expects an array).
    local _filteringSelector = if std.isArray(filteringSelector) then filteringSelector else [filteringSelector],
    datasource:: if enableLokiLogs && datasource == 'datasource' then 'prometheus_datasource' else datasource,
    datasourceLabel:: if enableLokiLogs && datasourceLabel == 'Data source' then 'Prometheus data source' else datasourceLabel,
    aggLevel:: aggLevel,
    aggKeepLabels:: aggKeepLabels,
    aggFunction:: aggFunction,

    local grafanaVariables = variables.new(
      _filteringSelector[0],
      groupLabels,
      instanceLabels,
      varMetric=varMetric,
      prometheusDatasourceName=this.datasource,
      prometheusDatasourceLabel=this.datasourceLabel,
      adHocEnabled=varAdHocEnabled,
      adHocLabels=varAdHocLabels,
      enableLokiLogs=enableLokiLogs,
    ),
    templatingVariables: {
      filteringSelector: _filteringSelector,
      groupLabels: groupLabels,
      instanceLabels: instanceLabels,
      queriesSelector: grafanaVariables.queriesSelector,
      queriesSelectorGroupOnly: grafanaVariables.queriesSelectorGroupOnly,
      queriesSelectorFilterOnly: grafanaVariables.queriesSelectorFilterOnly,
      interval: interval,
      alertsInterval: alertsInterval,
    },
    getVariablesSingleChoice()::
      grafanaVariables.singleInstance,
    getVariablesMultiChoice()::
      grafanaVariables.multiInstance,
    getVariables()::
      grafanaVariables,
    getVariablesDatasource(type='prometheus'):
      grafanaVariables.datasources[type],

    addSignal(
      name,
      type,
      unit='short',
      nameShort=name,
      description='',
      aggLevel=self.aggLevel,
      aggFunction=self.aggFunction,
      // `expr` is an observ-viz ergonomic shorthand for a single-source signal;
      // grafana callers pass `sourceMaps` instead. If both are given, sourceMaps wins.
      expr=null,
      sourceMaps=null,
    ):
      local _sourceMaps =
        if sourceMaps != null then sourceMaps
        else if expr != null then [{ expr: expr }]
        else error 'addSignal: must provide either `expr` or `sourceMaps` for signal %s' % name;
      // validate inputs
      std.prune(
        {
          checks: [
            if (type != 'gauge' &&
                type != 'histogram' &&
                type != 'counter' &&
                type != 'raw' &&
                type != 'info' &&
                type != 'stub' &&
                type != 'log')
            then
              error "type must be one of 'gauge','histogram','counter','raw','info','log'. Got %s for %s" % [type, name],
            if (
              aggLevel != 'aggKeepLabels' &&
              aggLevel != 'none' &&
              aggLevel != 'instance' &&
              aggLevel != 'group'
            )
            then
              error "aggLevel must be one of 'aggKeepLabels', 'group','instance' or 'none'",
          ],
        }
      ) +
      // normalize sourceMaps: backfill defaults that the per-type builders require
      // (so callers may pass a partial {expr:...} map).
      (
        local _filledSourceMaps = [
          {
            exprWrappers: [],
            rangeFunction: 'rate',
            aggFunction: aggFunction,
            aggKeepLabels: this.aggKeepLabels,
            infoLabel: null,
            type: type,
            legendCustomTemplate: null,
            valueMappings: [],
          } + sm
          for sm in _sourceMaps
        ];
        if type == 'gauge' then
        gauge.new(
          name=name, type=type, unit=unit, nameShort=nameShort, description=description,
          aggLevel=aggLevel, aggFunction=aggFunction, datasource=this.datasource,
          vars=this.templatingVariables, sourceMaps=_filledSourceMaps,
        )
      else if type == 'raw' then
        raw.new(
          name=name, type=type, unit=unit, nameShort=nameShort, description=description,
          aggLevel=aggLevel, aggFunction=aggFunction, datasource=this.datasource,
          vars=this.templatingVariables, sourceMaps=_filledSourceMaps,
        )
      else if type == 'counter' then
        counter.new(
          name=name, type=type, unit=unit, nameShort=nameShort, description=description,
          aggLevel=aggLevel, aggFunction=aggFunction, datasource=this.datasource,
          vars=this.templatingVariables, sourceMaps=_filledSourceMaps,
        )
      else if type == 'histogram' then
        histogram.new(
          name=name, type=type, unit=unit, nameShort=nameShort, description=description,
          aggLevel=aggLevel, aggFunction=aggFunction, datasource=this.datasource,
          vars=this.templatingVariables, sourceMaps=_filledSourceMaps,
        )
      else if type == 'log' then
        log.new(
          name=name, type=type, unit='none', nameShort=nameShort, description=description,
          aggLevel=aggLevel, aggFunction=aggFunction, datasource='loki_datasource',
          vars=this.templatingVariables, sourceMaps=_filledSourceMaps,
        )
      else if type == 'info' then
        info.new(
          name=name, type=type, nameShort=nameShort, description=description,
          aggLevel=aggLevel, aggFunction=aggFunction, datasource=this.datasource,
          vars=this.templatingVariables, sourceMaps=_filledSourceMaps,
        )
        else if type == 'stub' then
          stub.new(
            signalName=name,
            type=type,
          )
      ),
  },

  getVarMetric(signalsJson, type, defaultSignalSource):
    if std.objectHas(signalsJson, 'discoveryMetric')
    then
      if std.type(type) == 'array' then
        std.prune(
          [objGet(signalsJson.discoveryMetric, t, objGet(signalsJson.discoveryMetric, defaultSignalSource, null)) for t in type]
        )
      else
        objGet(signalsJson.discoveryMetric, type, objGet(signalsJson.discoveryMetric, defaultSignalSource, 'up'))
    else 'up',

  // Returns the templated PromQL expr for each signal; stub signals
  // (asPanelExpression() == {}) are filtered out. No dedup here.
  collectMetricExprs(signalsObj):
    std.filter(
      function(e) std.isString(e) && e != '',
      std.flattenArrays([
        if std.isObject(signalsObj[s]) && std.objectHasAll(signalsObj[s], 'asPanelExpression') then
          [signalsObj[s].asPanelExpression()]
        else if std.isObject(signalsObj[s]) then
          self.collectMetricExprs(signalsObj[s])
        else
          []
        for s in std.objectFields(signalsObj)
      ])
    ),
}
