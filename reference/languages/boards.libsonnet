// observ-viz reference — Language folder. One board per language runtime pack.
local g = import 'g.libsonnet';
local place = (import 'reference/_util.libsonnet').place;

local runtimes = [
  ['golang', 'Go'],
  ['jvm', 'JVM'],
  ['python', 'Python'],
  ['dotnet', '.NET'],
  ['nodejs', 'Node.js'],
];

{
  _config+:: {},
  grafanaDashboards+:: {
    ['lang-' + r[0] + '.json']:
      place(
        g.packs.runtimes[r[0]].new({ uid: 'observ-viz-lang-' + r[0], dashboardTitle: r[1] + ' runtime' }).grafana.dashboard,
        $._config.folders.languages,
        $._config.tags,
      )
    for r in runtimes
  },
}
