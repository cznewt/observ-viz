// observ-viz reference mixin — composes the three reference categories.
// Exposes grafanaDashboards+:: { '<name>.json': <board> }, monitoring-mixin style.
(import 'reference/panels/boards.libsonnet') +
(import 'reference/languages/boards.libsonnet') +
(import 'reference/deployments/boards.libsonnet') +
(import 'reference/config.libsonnet')
