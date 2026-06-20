// common-lib annotations — onboard of grafana/jsonnet-libs
// common-lib/common/annotations. base + severity/event presets that build v2
// AnnotationQuery objects from a signal target (signal.asTarget()) or a plain
// annotations.base.target(datasource, expr).
{
  base: import 'libs/common-lib/annotations/base.libsonnet',
  critical: import 'libs/common-lib/annotations/critical.libsonnet',
  warning: import 'libs/common-lib/annotations/warning.libsonnet',
  info: import 'libs/common-lib/annotations/info.libsonnet',
  fatal: import 'libs/common-lib/annotations/fatal.libsonnet',
  reboot: import 'libs/common-lib/annotations/reboot.libsonnet',
  serviceFailed: import 'libs/common-lib/annotations/service_failed.libsonnet',
}
