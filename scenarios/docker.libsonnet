// observ-viz scenario — Docker host (containers + node + collector).
local scenario = import 'scenarios/_scenario.libsonnet';
local packs = import 'libs/observ-libs.libsonnet';
{
  new(config={}):
    scenario.new({ uid: 'docker', title: 'Docker host' } + config, [
      { key: 'containers', pack: packs.system.docker },
      { key: 'host', pack: packs.system.linux },
      { key: 'collector', pack: packs.collector.alloy },
    ]),
}
