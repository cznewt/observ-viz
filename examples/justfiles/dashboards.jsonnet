// Example consumer manifest — your own dashboards, built on observ-viz.
// Renders to a { '<name>.json': <resource> } map so `jsonnet -m` writes one
// file per dashboard. See vendor-and-render.justfile / render-with-image.justfile.
local g = import 'g.libsonnet';
local ds = '${datasource}';

// a small RED-style board from signals
local sig(name, expr, unit) = g.common.signal.new(name, 'prometheus', ds, expr, unit);
local rate = sig('Requests', 'sum(rate(http_requests_total[$__rate_interval]))', 'reqps');
local errors = sig('Errors', 'sum(rate(http_requests_total{code=~"5.."}[$__rate_interval]))', 'reqps');

local board =
  g.dashboard.new('My service')
  + g.dashboard.withUid('my-service')
  + g.dashboard.withElements(
    g.element.panel('rate', rate.asTimeSeries('Request rate'))
    + g.element.panel('errors', errors.asTimeSeries('Error rate'))
  )
  + g.dashboard.withLayout(
    g.layout.grid.new() + g.layout.grid.withItems([
      g.layout.grid.item('rate', 0, 0, 12, 8),
      g.layout.grid.item('errors', 12, 0, 12, 8),
    ])
  );

// also reuse a whole observ-lib dashboard
local golang = g.libs.runtimes.golang.new({ selector: 'job="my-go-app"' }).grafana.dashboard;

{
  'my-service.json': board.toResource(),
  'golang.json': golang.toResource(),
}
