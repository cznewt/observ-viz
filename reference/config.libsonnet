// observ-viz reference — shared config. Grafana folders.
// Depends on common-lib (see jsonnetfile.json): the Common folder renders a
// sample board for each common-lib panel-preset category + the patterns.
{
  _config+:: {
    datasource: '${datasource}',
    tags: ['observ-viz', 'reference'],
    folders: {
      common: { uid: 'observ-viz-common', title: 'Common Reference' },
      panels: { uid: 'observ-viz-panels', title: 'Panel Reference' },
      languages: { uid: 'observ-viz-languages', title: 'Language Reference' },
      deployments: { uid: 'observ-viz-deployments', title: 'Deployment Reference' },
    },
  },
}
