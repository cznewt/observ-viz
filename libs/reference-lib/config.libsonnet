// observ-viz reference — shared config. Grafana folders (nested under "Reference").
{
  _config+:: {
    datasource: '${datasource}',
    tags: ['observ-viz', 'reference'],
    local reference = { uid: 'observ-viz-reference', title: 'Reference' },
    local base = { uid: 'base', title: 'Base' },
    // Analysis is a root of its own: these boards are not reference material
    // about observ-viz, they are methods you point at a running service.
    local analysis = { uid: 'observ-viz-analysis', title: 'Analysis' },
    folders: {
      panels: { uid: 'observ-viz-panels', title: 'Panels', parent: reference },
      languages: { uid: 'observ-viz-languages', title: 'Runtimes', parent: reference },
      analysisRed: { uid: 'observ-viz-analysis-red', title: 'RED', parent: analysis },
      analysisUse: { uid: 'observ-viz-analysis-use', title: 'USE', parent: analysis },
      analysisAnomaly: { uid: 'observ-viz-analysis-anomaly', title: 'Anomaly', parent: analysis },
      analysisGolden: { uid: 'observ-viz-analysis-golden', title: 'Golden signals', parent: analysis },
      analysisBurnRate: { uid: 'observ-viz-analysis-burnrate', title: 'Burn rate', parent: analysis },
      analysisCapacity: { uid: 'observ-viz-analysis-capacity', title: 'Capacity', parent: analysis },
      deployments: { uid: 'observ-viz-deployments', title: 'Deployments', parent: reference },
      // the machine itself is not a deployment target of ours, it is the base
      // everything else runs on
      operatingSystems: { uid: 'base-operating-systems', title: 'Operating systems', parent: base },
    },
  },
}
