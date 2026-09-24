// observ-viz shared optional tabs (hand-written).
// Two tabs any board can carry, because the questions they answer belong to
// whatever the board is about rather than to a board of their own:
//
//   alerts  what is firing here - the Grafana alert list, the ALERTS series a
//           Mimir or Prometheus ruler produces, and the state over time
//   logs    what it is saying - one panel per log stream the board can name
//
// Both come back as pack.build optionalTabs entries, so they render only when
// their own queries return something and disappear on a target that has no
// rules or no logs datasource.
local alertPanels = import 'libs/common-lib/alert/panels.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  // alerts(datasource, selector) -> the optionalTabs entry
  alerts(datasource='${datasource}', selector='', limit=100, title='Alerts'):: {
    title: title,
    width: 24,
    height: 10,
    elements: {
      al01_list: alertPanels.list('Alerts', groupMode='custom', groupBy=['alertname']),
      al02_firing: alertPanels.firingTable('Firing alerts', datasource, selector),
      al03_state: alertPanels.timeline('Alert state', datasource, selector, limit),
    },
  },

  // logs(datasource, streams) where each stream is
  //   { key, title, selector, description, pipeline? }
  logs(datasource='${loki_datasource}', streams=[], title='Logs', maxLines=200):: {
    title: title,
    width: 24,
    height: 10,
    elements: {
      ['lg' + std.format('%02d', i) + '_' + streams[i].key]:
        panel.logs.new(streams[i].title)
        + panel.withDescription(if std.objectHas(streams[i], 'description') then streams[i].description else '')
        + panel.logs.withTargets([
          query.loki.new(datasource, streams[i].selector + (if std.objectHas(streams[i], 'pipeline') then ' ' + streams[i].pipeline else ''))
          + { spec+: { query+: { spec+: { maxLines: maxLines } } } },
        ])
        + panel.logs.withOptions({ showTime: true, wrapLogMessage: true, enableLogDetails: true, dedupStrategy: 'none', sortOrder: 'Descending' })
      for i in std.range(0, std.length(streams) - 1)
    },
  },

  // the streams a Kubernetes board can name: the workloads' own lines, and the
  // events the API server recorded about them
  kubernetesStreams(namespace='$namespace', pod='$pod', cluster='$cluster'):: [
    {
      key: 'pods',
      title: 'Pod logs',
      selector: '{cluster=~"' + cluster + '", namespace=~"' + namespace + '", pod=~"' + pod + '"}',
      description: 'Every line the selected pods wrote, newest first.',
    },
    {
      key: 'events',
      title: 'Kubernetes events',
      selector: '{job="integrations/kubernetes/eventhandler", cluster=~"' + cluster + '", namespace=~"' + namespace + '"}',
      pipeline: '| logfmt | line_format "{{.type}} {{.kind}}/{{.name}} {{.reason}}: {{.msg}}"',
      description: 'What the API server recorded about objects in this namespace: scheduling, pulls, probes, evictions. The line that explains a restart is usually here rather than in the pod log.',
    },
  ],
}
