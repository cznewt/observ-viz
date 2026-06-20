// observ-viz reference — Language folder. One TABBED board per language runtime:
// an Overview tab (markdown signal descriptions) + one tab per signal group.
local g = import 'g.libsonnet';
local util = import 'reference/_util.libsonnet';

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
      util.place(
        util.tabbedBoard(
          g.libs.runtimes[r[0]].new({
            uid: 'observ-viz-lang-' + r[0],
            dashboardTitle: r[1] + ' runtime',
            datasource: $._config.datasource,
          }),
          r[1] + ' runtime',
          'observ-viz-lang-' + r[0],
        ),
        $._config.folders.languages,
        $._config.tags,
      )
    for r in runtimes
  },
}
