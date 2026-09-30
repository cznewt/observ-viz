// common-lib annotations — base. Builds a v2 AnnotationQuery from a
// signal target (signal.asTarget()) or a plain { datasource, expr } target,
// reusing the observ-viz annotation builder.
//
// Prometheus' own annotation options (titleFormat, tagKeys, textFormat,
// useValueForTime) are not v2 AnnotationQuerySpec fields: Grafana drops them
// there on save. They ride in spec.legacyOptions, which the v2 -> scene
// transform spreads back onto the root of the v1 annotation the Prometheus
// datasource reads them from.
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
        legacyOptions+: { titleFormat: title },
        query: {
          kind: 'DataQuery',
          group: t.group,
          version: 'v0',
          datasource: t.ds,
          spec: { expr: t.expr },
        },
      },
    },

  withTagKeys(value):: { spec+: { legacyOptions+: { tagKeys: if std.isArray(value) then std.join(',', value) else value } } },
  withValueForTime(value=false):: { spec+: { legacyOptions+: { useValueForTime: value } } },
  withTextFormat(value=''):: { spec+: { legacyOptions+: { textFormat: value } } },
  // event title from the series labels, e.g. '{{alertname}}' (default: the annotation name)
  withTitleFormat(value):: { spec+: { legacyOptions+: { titleFormat: value } } },
  // a viewer toggle in the annotation bar: shown (hide=false), on or off by default
  asToggle(enabled=true):: { spec+: { hide: false, enable: enabled } },
}
