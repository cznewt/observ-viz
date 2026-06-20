// common-lib annotations — base (onboard of grafana/jsonnet-libs
// common-lib/common/annotations/base). Builds a v2 AnnotationQuery from a
// signal target (signal.asTarget()) or a plain { datasource, expr } target,
// reusing the observ-viz annotation builder.
local annotation = import 'custom/annotation.libsonnet';

// normalise a target to { ds, group, expr }.
local extract(target) =
  if std.objectHas(target, 'spec') && std.objectHas(target.spec, 'query') then
    // an observ-viz v2 PanelQuery, e.g. signal.asTarget()
    {
      ds: target.spec.query.datasource,
      group: target.spec.query.group,
      expr: target.spec.query.spec.expr,
    }
  else
    // a plain { datasource, expr, kind? }
    {
      ds: if std.isString(target.datasource) then { name: target.datasource } else target.datasource,
      group: if std.objectHas(target, 'kind') then target.kind else 'prometheus',
      expr: target.expr,
    };

{
  // plain target for the non-signal case: annotations.base.target('${ds}', 'up').
  target(datasource, expr, kind='prometheus'):: { datasource: datasource, expr: expr, kind: kind },

  new(title, target):
    local t = extract(target);
    annotation.new(title)
    + {
      spec+: {
        titleFormat: title,
        query: {
          kind: 'DataQuery',
          group: t.group,
          version: 'v0',
          datasource: t.ds,
          spec: { expr: t.expr },
        },
      },
    },

  withTagKeys(value):: { spec+: { tagKeys: if std.isArray(value) then std.join(',', value) else value } },
  withValueForTime(value=false):: { spec+: { useValueForTime: value } },
  withTextFormat(value=''):: { spec+: { textFormat: value } },
}
