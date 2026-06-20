// observ-viz scenario — Linux host (node + containers + collector).
local scenario = import 'scenarios/_scenario.libsonnet';
local packs = import 'libs/observ-libs.libsonnet';
{
  new(config={}):
    scenario.new({ uid: 'linux', title: 'Linux host' } + config, [
      { key: 'host', pack: packs.system.linux },
      { key: 'containers', pack: packs.system.docker },
      { key: 'collector', pack: packs.collector.alloy },
    ]),
}
