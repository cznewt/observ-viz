// observ-viz example — common-lib base panel presets.
// Builds a small grid from the categorized common.panels presets
// (cpu/memory/network/disk/requests/generic), each fed a testdata target.
local g = import 'g.libsonnet';
local p = g.common.panels;

local td() = g.query.base('grafana-testdata-datasource', { scenarioId: 'random_walk' }) + g.query.withDatasource('testdata');
local t = [td(), td()];

local panels = {
  cpu: p.cpu.utilization('CPU usage', t),
  memory: p.memory.usagePercent('Memory usage', t),
  network: p.network.traffic('Network traffic', t),
  disk: p.disk.ioBytesPerSec('Disk reads/writes', t),
  requests: p.requests.rate('Request rate', t),
  generic: p.generic.timeSeries('Generic series', t, 'A plain base time series.'),
};

local keys = std.objectFields(panels);

g.dashboard.new('Library / Common panels')
+ g.dashboard.withUid('observ-viz-library-panels')
+ g.dashboard.withElements({ [k]: g.element.panel(k, panels[k]) for k in keys })
+ g.dashboard.withLayout(
  g.layout.grid.new()
  + g.layout.grid.withItems([
    g.layout.grid.item(keys[i], (i % 2) * 12, std.floor(i / 2) * 8, 12, 8)
    for i in std.range(0, std.length(keys) - 1)
  ])
)
