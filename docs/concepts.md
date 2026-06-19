# Concepts

## Slim core, lots of mixins

The library is deliberately layered:

- **Core** (`custom/`, `gen/`, `signal/`) — the v2 builders, layouts, and the
  signal abstraction. Small and stable.
- **Mixins** (`library/`, `alert/`, `logs/`, `deploy/`, `packs/`, `scenarios/`,
  `patterns/`) — everything domain-specific. This is where breadth lives.

Adding coverage means adding a mixin, not touching the core.

## Elements vs layout

A v2 dashboard separates **what** panels exist from **where** they go:

```jsonnet
local elements =
  g.element.panel('rate', rate.asTimeSeries('Request rate'))
  + g.element.panel('errors', errors.asTimeSeries('Errors'));

local layout =
  g.layout.grid.new() + g.layout.grid.withItems([
    g.layout.grid.item('rate', 0, 0, 12, 8),     // reference by name
    g.layout.grid.item('errors', 12, 0, 12, 8),
  ]);
```

Layouts nest. `RowsLayout`, `TabsLayout`, and `AutoGridLayout` rows/tabs each
carry a nested layout, so you can build tabbed dashboards (one tab per group),
rows of grids, etc.

## Generic by default

In v2 the panel viz is `vizConfig.group` (a string) and the datasource query is
`query.group` (a string), each with free-form `spec`. So:

```jsonnet
g.panel.base('<any-plugin-id>', 'title')      // any panel plugin
g.query.base('<any-datasource-id>', { ... })  // any datasource
```

…work immediately. Typed builders (`g.panel.timeSeries`, `g.query.prometheus`,
…) are ergonomics on top. (This is how the [DOOM example](examples.md) targets a
third-party datasource plugin with zero library code.)

## Signals

A **signal** couples a logical metric (datasource + expr template + unit) to its
renderings:

```jsonnet
local rate =
  g.signal.new('rate', 'prometheus', '${datasource}',
               'rate(http_requests_total{%(queriesSelector)s}[$__rate_interval])', 'reqps')
  + g.signal.new(...).filteringSelector('job="api"')   // injects the selector
  + ... .groupLabels(['job']).aggLevel('group');        // sum by(job)(...)

rate.asTimeSeries('Request rate')   // -> a PanelKind element
rate.asStat('Now') / rate.asTable() / rate.asTarget()
```

Packs are built almost entirely out of signals.
