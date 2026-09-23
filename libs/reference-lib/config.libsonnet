// observ-viz reference — shared config. Grafana folders (nested under "Reference").
{
  _config+:: {
    datasource: '${datasource}',
    tags: ['observ-viz', 'reference'],
    local reference = { uid: 'observ-viz-reference', title: 'Reference' },
    folders: {
      panels: { uid: 'observ-viz-panels', title: 'Panels', parent: reference },
      languages: { uid: 'observ-viz-languages', title: 'Runtimes', parent: reference },
      deployments: { uid: 'observ-viz-deployments', title: 'Deployments', parent: reference },
    },
  },
}
