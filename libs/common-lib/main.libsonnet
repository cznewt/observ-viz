// observ-viz common-lib — the shared base every observ-lib builds on
// (mirrors grafana/jsonnet-libs common-lib). Built on the observ-viz v2 builder.
{
  signal: import 'libs/common-lib/signal/main.libsonnet',
  pack: import 'libs/common-lib/pack.libsonnet',
  // base panel presets + signal presets + element groups
  panels: import 'libs/common-lib/panels.libsonnet',
  signals: import 'libs/common-lib/signals.libsonnet',
  rows: import 'libs/common-lib/rows.libsonnet',
  library: import 'libs/common-lib/library.libsonnet',
  // reusable annotation / alert / log / deploy primitives
  alert: import 'libs/common-lib/alert/main.libsonnet',
  logs: import 'libs/common-lib/logs/main.libsonnet',
  deploy: import 'libs/common-lib/deploy/main.libsonnet',
}
