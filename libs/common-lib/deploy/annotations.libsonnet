// observ-viz reusable deployment annotations (hand-written).
// Render deploy/restart markers onto any board as v2beta1 AnnotationQuery, whose
// query is a DataQuery wrapper { kind:'DataQuery', group:<ds>, datasource:{name} }.
local annotation = import 'custom/annotation.libsonnet';

local promAnnotation(title, datasource, expr, iconColor) =
  annotation.new(title)
  + {
    spec+: {
      iconColor: iconColor,
      enable: true,
      query: {
        kind: 'DataQuery',
        group: 'prometheus',
        version: 'v0',
        datasource: { name: datasource },
        spec: { expr: expr },
      },
    },
  };

{
  // deploys: marks process restarts (a common deploy proxy).
  deploys(datasource='${datasource}', selector='', title='Deploys'):
    promAnnotation(title, datasource, 'changes(process_start_time_seconds{' + selector + '}[$__interval]) > 0', 'green'),

  // versionChanges: marks build/version label changes from a *_build_info metric.
  versionChanges(datasource='${datasource}', metric='build_info', selector='', title='Version changes'):
    promAnnotation(title, datasource, 'changes(' + metric + '{' + selector + '}[$__interval]) > 0', 'blue'),
}
