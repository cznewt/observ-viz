// observ-viz reference mixin — composes the reference categories.
// Exposes grafanaDashboards+:: { '<name>.json': <board> }, monitoring-mixin style.
(import 'libs/reference-lib/panels/boards.libsonnet') +
(import 'libs/reference-lib/languages/boards.libsonnet') +
(import 'libs/reference-lib/deployments/boards.libsonnet') +
(import 'libs/reference-lib/config.libsonnet')
