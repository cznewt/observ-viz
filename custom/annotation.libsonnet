// observ-viz annotation veneer (hand-written).
// Merged over gen/annotation.libsonnet setters.
{
  new(name): { kind: 'AnnotationQuery', spec: { name: name, enable: true, hide: false } },

  // the default built-in "Annotations & Alerts" grafana annotation.
  builtinAnnotation(): {
    kind: 'AnnotationQuery',
    spec: {
      name: 'Annotations & Alerts',
      enable: true,
      hide: true,
      iconColor: 'rgba(0, 211, 255, 1)',
      builtIn: true,
      query: {
        kind: 'DataQuery',
        group: 'grafana',
        version: 'v0',
        datasource: { name: '-- Grafana --' },
        spec: {},
      },
    },
  },
}
