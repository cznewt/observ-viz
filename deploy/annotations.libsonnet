// observ-viz reusable deployment annotations (hand-written).
// Render deploy/restart markers onto any board as v2 AnnotationQueryKind.
local annotation = import 'custom/annotation.libsonnet';

{
  // deploys: marks process restarts (a common deploy proxy).
  deploys(datasource='${datasource}', selector='', title='Deploys'):
    annotation.new(title)
    + {
      spec+: {
        datasource: { type: 'prometheus', uid: datasource },
        query: { kind: 'prometheus', spec: { expr: 'changes(process_start_time_seconds{' + selector + '}[$__interval]) > 0' } },
        iconColor: 'green',
        enable: true,
      },
    },

  // versionChanges: marks build/version label changes from a *_build_info metric.
  versionChanges(datasource='${datasource}', metric='build_info', selector='', title='Version changes'):
    annotation.new(title)
    + {
      spec+: {
        datasource: { type: 'prometheus', uid: datasource },
        query: { kind: 'prometheus', spec: { expr: 'changes(' + metric + '{' + selector + '}[$__interval]) > 0' } },
        iconColor: 'blue',
        enable: true,
      },
    },
}
