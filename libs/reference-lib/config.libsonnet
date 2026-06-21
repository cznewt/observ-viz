// observ-viz reference — shared config. Grafana folders (nested under "Reference").
// Depends on common-lib (see jsonnetfile.json): the Common folder renders a
// sample board for each common-lib panel-preset category + the patterns.
{
  _config+:: {
    datasource: '${datasource}',
    tags: ['observ-viz', 'reference'],
    local reference = { uid: 'observ-viz-reference', title: 'Reference' },
    folders: {
      common: { uid: 'observ-viz-common', title: 'Common', parent: reference },
      panels: { uid: 'observ-viz-panels', title: 'Panels', parent: reference },
      languages: { uid: 'observ-viz-languages', title: 'Runtimes', parent: reference },
      deployments: { uid: 'observ-viz-deployments', title: 'Deployments', parent: reference },
    },
  },
}
