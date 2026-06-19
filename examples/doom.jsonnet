// DOOM — the real thing. Targets the grafana-doom-datasource hackathon plugin
// (https://github.com/grafana-cold-storage/doom-datasource), which runs WASM
// DOOM and streams the screen into a timeseries panel.
//
// THE POINT: observ-viz targets this third-party plugin with ZERO library
// changes — the generic escape hatch. A datasource plugin id is just a string
// in `group`; query fields are free-form `spec`. No grafana-doom builder needed.
//
// To actually play: build + install the plugin (see scripts/build-doom-plugin.sh
// or the plugin README), then `just up && just load`. The palette/options below
// are imported from the plugin's own dashboard so the screen renders correctly.
local g = import 'g.libsonnet';
local render = import 'doom_render.json';

local doomDs = 'doom';  // uid of the provisioned Doom datasource

local screen =
  g.panel.timeSeries.new('DOOM')
  + g.panel.withTargets([
    // <-- the entire integration: any datasource id + any free-form query spec
    g.query.base('grafana-doom-datasource', { queryType: 'screen', halfResolution: true })
    + g.query.withDatasource(doomDs),
  ])
  + { spec+: { vizConfig+: { spec+: { options: render.options, fieldConfig: render.fieldConfig } } } };

local dash =
  g.dashboard.new('DOOM')
  + g.dashboard.withUid('doom')
  + g.dashboard.withTags(['doom', 'fun', 'extensibility-demo'])
  + g.dashboard.withElements(g.element.panel('doom', screen))
  + g.dashboard.withLayout(
    g.layout.grid.new()
    + g.layout.grid.withItems([ g.layout.grid.item('doom', 0, 0, 12, 14) ]));

dash.toResource()
