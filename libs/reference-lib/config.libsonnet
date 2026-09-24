// observ-viz reference — shared config. Grafana folders (nested under "Reference").
{
  _config+:: {
    datasource: '${datasource}',
    tags: ['observ-viz', 'reference'],
    local reference = { uid: 'observ-viz-reference', title: 'Reference' },
    local base = { uid: 'base', title: 'Base' },
    folders: {
      panels: { uid: 'observ-viz-panels', title: 'Panels', parent: reference },
      analysis: { uid: 'observ-viz-analysis', title: 'Analysis', parent: reference },
      languages: { uid: 'observ-viz-languages', title: 'Runtimes', parent: reference },
      deployments: { uid: 'observ-viz-deployments', title: 'Deployments', parent: reference },
      // the machine itself is not a deployment target of ours, it is the base
      // everything else runs on
      operatingSystems: { uid: 'base-operating-systems', title: 'Operating systems', parent: base },
    },
  },
}
