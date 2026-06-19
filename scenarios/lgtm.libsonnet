// observ-viz scenario — the Grafana LGTM stack (what Alloy ships telemetry to).
local scenario = import 'scenarios/_scenario.libsonnet';
local packs = import 'packs/main.libsonnet';
{
  new(config={}):
    scenario.new({ uid: 'lgtm', title: 'Grafana LGTM stack' } + config, [
      { key: 'mimir', pack: packs.databases.timeseries.mimir },
      { key: 'loki', pack: packs.databases.timeseries.loki },
      { key: 'tempo', pack: packs.databases.timeseries.tempo },
      { key: 'pyroscope', pack: packs.databases.timeseries.pyroscope },
      { key: 'alloy', pack: packs.collector.alloy },
    ]),
}
