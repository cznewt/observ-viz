// Alerts overview via the encapsulated pattern (RowsLayout nesting grids).
local g = import 'g.libsonnet';

g.patterns.alertsOverview.new(
  datasource='${datasource}',
  selector='',
  uid='alerts-overview',
  title='Alerts overview',
).toResource()
