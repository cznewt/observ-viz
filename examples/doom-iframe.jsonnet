// DOOM via the built-in 'text' panel in HTML mode (no plugin needed — plays now).
// Demonstrates the generic panel escape hatch: ANY viz kind works by naming it.
// Requires GF_PANELS_DISABLE_SANITIZE_HTML=true (set in docker-compose.yml).
local g = import 'g.libsonnet';

local doom =
  g.panel.base('text', "E1M1: At Doom's Gate")
  + g.panel.withDescription('Rip and tear, until it is done.')
  + {
    spec+: { vizConfig+: { spec+: { options: {
      mode: 'html',
      content: '<iframe src="https://archive.org/embed/DoomsharewareEpisode" '
               + 'width="100%" height="100%" style="border:0;min-height:640px" '
               + 'allow="autoplay; fullscreen" allowfullscreen></iframe>',
    } } } },
  };

local dash =
  g.dashboard.new('DOOM (iframe)')
  + g.dashboard.withUid('doom-iframe')
  + g.dashboard.withTags(['doom', 'fun'])
  + g.dashboard.withElements(g.element.panel('doom', doom))
  + g.dashboard.withLayout(
    g.layout.grid.new()
    + g.layout.grid.withItems([ g.layout.grid.item('doom', 0, 0, 24, 22) ]));

dash.toResource()
