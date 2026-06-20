local base = import './base.libsonnet';
base {
  new(
    name,
    type,
    unit,
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
      unit,
      nameShort,
      description,
      aggLevel,
      aggFunction,
      vars,
      datasource,
      sourceMaps=sourceMaps,
    )
    {
      local this = self,
      quantile:: 0.95,
      signalName+:: ' (p%.0f)' % (this.quantile * 100),
      nameShort+:: ' (p%.0f)' % (this.quantile * 100),
      wrapDescription()::
        this.nameShort + ': ' + this.description + '  \n',
      withQuantile(quantile=0.95):
        self
        {
          quantile:: quantile,
        },
    },
}
