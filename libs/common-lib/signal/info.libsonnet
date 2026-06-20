local g = import './g.libsonnet';
local base = import './base.libsonnet';

//_info prometheus metric: something_info{<labels>}=1
base {
  new(
    name,
    type,
    nameShort,
    description,
    aggLevel,
    aggFunction,
    vars,
    datasource,
    sourceMaps,
  ):
    base.new(
      name,
      type,
      'short',
      nameShort,
      description,
      aggLevel,
      aggFunction,
      vars,
      datasource,
      sourceMaps=sourceMaps,
    )
    {
      local prometheusQuery = g.query.prometheus,
      local infoLabel =
        std.join(
          '|',
          std.uniq(  // keep unique only
            std.sort(
              [
                source.infoLabel
                for source in sourceMaps
              ]
            )
          )
        ),

      unit:: 'short',
      //Return as grafana panel target(query+legend)
      asTarget()::
        super.asTarget()
        + prometheusQuery.withFormat('table'),

      //Return as alert/recordingRule query
      asPromRule():: {},

      //Return as timeSeriesPanel
      asTimeSeries()::
        error 'asTimeSeries() is not supported for info metrics. Use asStat() instead.',

      //Return as statPanel
      asStat()::
        super.asStat()
        // observ-viz has no panels.generic.stat.info.stylize(); restrict the
        // stat reducer to the info label fields, which is the load-bearing part.
        + { spec+: { vizConfig+: { spec+: { options+: { reduceOptions+: { fields: '/^(' + infoLabel + ')$/' } } } } } },

      //Return as gauge panel
      asGauge()::
        error 'asGauge() is not supported for info metrics. Use asStat() instead.',

    },

}
