// common-lib annotations (onboard of grafana/jsonnet-libs common-lib/common/
// annotations). Severity-coloured, prometheus-target annotation primitives that
// observ-libs reuse (e.g. alerts-observ-lib), as v2 AnnotationQuery.
local annotation = import 'custom/annotation.libsonnet';

local promAnnotation(title, datasource, expr, color, opts={}) =
  annotation.new(title)
  + {
    spec+: {
      iconColor: color,
      enable: true,
      hide: true,
      query: {
        kind: 'DataQuery',
        group: 'prometheus',
        version: 'v0',
        datasource: { name: datasource },
        spec: { expr: expr },
      },
    } + (if std.objectHas(opts, 'textFormat') then { textFormat: opts.textFormat } else {}),
  };

{
  // base(title, datasource, expr, color) — a prometheus-target annotation.
  base(title, datasource, expr, color='blue', opts={}): promAnnotation(title, datasource, expr, color, opts),

  // severity presets (colour-coded).
  critical(title, datasource, expr, opts={}): promAnnotation(title, datasource, expr, 'red', opts),
  warning(title, datasource, expr, opts={}): promAnnotation(title, datasource, expr, 'orange', opts),
  info(title, datasource, expr, opts={}): promAnnotation(title, datasource, expr, 'blue', opts),
  fatal(title, datasource, expr, opts={}): promAnnotation(title, datasource, expr, 'dark-red', opts),

  // common event annotations.
  reboot(datasource='${datasource}', selector='', title='Reboot'):
    promAnnotation(title, datasource, 'node_boot_time_seconds{' + selector + '} * 1000', 'purple'),
  serviceFailed(datasource='${datasource}', selector='', title='Service failed'):
    promAnnotation(title, datasource, 'node_systemd_unit_state{state="failed"' + (if selector != '' then ', ' + selector else '') + '} > 0', 'red'),
}
