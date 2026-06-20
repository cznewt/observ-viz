// observ-viz common-lib base panel presets — categorized aggregator.
// Ported from grafana/jsonnet-libs common-lib/common/panels.libsonnet.
// Each category groups pre-styled v2 panel builders that take targets directly.
local g = import 'g.libsonnet';
local generic = import 'libs/common-lib/panels/generic.libsonnet';

{
  generic: generic,
  cpu: import 'libs/common-lib/panels/cpu.libsonnet',
  memory: import 'libs/common-lib/panels/memory.libsonnet',
  disk: import 'libs/common-lib/panels/disk.libsonnet',
  network: import 'libs/common-lib/panels/network.libsonnet',
  system: import 'libs/common-lib/panels/system.libsonnet',
  requests: import 'libs/common-lib/panels/requests.libsonnet',
  hardware: import 'libs/common-lib/panels/hardware.libsonnet',

  // Back-compat helper preserved from the superseded panels.libsonnet:
  // a 'short'-unit single stat. (cpu/memory/requests equivalents now live in
  // their categories: cpu.timeSeries, memory.timeSeries, requests.rate.)
  statShort(title, targets=[]):
    g.panel.stat.new(title)
    + g.panel.stat.withTargets(targets)
    + g.panel.stat.standardOptions.withUnit('short'),
}
