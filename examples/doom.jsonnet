// DOOM — because why not. Also a real demonstration of the generic panel escape
// hatch: ANY viz kind works by naming it. Here the built-in 'text' panel in HTML
// mode embeds DOOM in an <iframe>. Swap 'text' for any panel plugin id and it
// just works — v2 stores the viz as vizConfig.kind + free-form options.
//
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
  g.dashboard.new('DOOM')
  + g.dashboard.withUid('doom')
  + g.dashboard.withTags(['doom', 'fun', 'extensibility-demo'])
  + g.dashboard.withElements(g.element.panel('doom', doom))
  + g.dashboard.withLayout(
    g.layout.grid.new()
    + g.layout.grid.withItems([ g.layout.grid.item('doom', 0, 0, 24, 22) ]));

dash.toResource()
