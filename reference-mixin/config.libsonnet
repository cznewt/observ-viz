// Reference mixin config — mirrors the monitor-tools reference-mixin shape.
{
  _config+:: {
    datasource: '${datasource}',
    selector: '',
    // the Grafana folder all reference boards are placed in
    folder: { uid: 'observ-viz-reference', title: 'observ-viz Reference' },
    tags: ['observ-viz', 'reference'],
  },
}
