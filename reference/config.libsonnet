// observ-viz reference — shared config. Three Grafana folders.
{
  _config+:: {
    datasource: '${datasource}',
    tags: ['observ-viz', 'reference'],
    folders: {
      panels: { uid: 'observ-viz-panels', title: 'Panel Reference' },
      languages: { uid: 'observ-viz-languages', title: 'Language Reference' },
      deployments: { uid: 'observ-viz-deployments', title: 'Deployment Reference' },
    },
  },
}
