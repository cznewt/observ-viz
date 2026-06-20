// observ-viz entrypoint. Layers the hand-written custom veneer over the
// generated gen/ builders (grafonnet-style), and adds the higher-level modules
// (signal, library, alert, logs, packs, patterns).
local gen = import 'gen/observ-viz-v2beta1/main.libsonnet';
local cv = import 'custom/variable.libsonnet';

{
  dashboard: gen.dashboard + (import 'custom/dashboard.libsonnet'),
  annotation: gen.annotation + (import 'custom/annotation.libsonnet'),
  timeSettings: gen.timeSettings,
  // panel/query veneers are self-contained (they import & merge gen internally).
  panel: import 'custom/panel.libsonnet',
  query: import 'custom/query.libsonnet',
  variable: {
    query: gen.variable.query + cv.query,
    datasource: gen.variable.datasource + cv.datasource,
    custom: gen.variable.custom + cv.custom,
    interval: gen.variable.interval + cv.interval,
    text: gen.variable.text + cv.text,
    constant: gen.variable.constant + cv.constant,
    groupBy: gen.variable.groupBy + cv.groupBy,
    adhoc: gen.variable.adhoc + cv.adhoc,
  },
  layout: import 'custom/layout.libsonnet',
  element: import 'custom/element.libsonnet',
  util: import 'custom/util/main.libsonnet',

  // observ-libs ecosystem (stored under libs/) surfaced for convenience.
  common: import 'libs/common-lib/main.libsonnet',
  signal: import 'libs/common-lib/signal/main.libsonnet',
  library: import 'libs/common-lib/library.libsonnet',
  alert: import 'libs/common-lib/alert/main.libsonnet',
  logs: import 'libs/common-lib/logs/main.libsonnet',
  deploy: import 'libs/common-lib/deploy/main.libsonnet',
  packs: import 'libs/observ-libs.libsonnet',
  scenarios: import 'scenarios/main.libsonnet',
  patterns: import 'patterns/main.libsonnet',
  config: import 'config/config.libsonnet',
}
