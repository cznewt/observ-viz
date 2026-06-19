// observ-viz scenario — Kubernetes (pods + container resources + collector).
local scenario = import 'scenarios/_scenario.libsonnet';
local packs = import 'packs/main.libsonnet';
{
  new(config={}):
    scenario.new({ uid: 'kubernetes', title: 'Kubernetes' } + config, [
      { key: 'pods', pack: packs.kubernetes.pod },
      { key: 'containers', pack: packs.kubernetes.cadvisor },
      { key: 'collector', pack: packs.collector.alloy },
    ]),
}
