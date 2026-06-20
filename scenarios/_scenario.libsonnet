// observ-viz scenario contract (hand-written).
// A scenario aggregates several packs (alloy-resources "modules") into one
// environment: a Grafana folder of boards + merged prometheus alerts + a
// Backstage System with a Component per member pack. Mirrors the alloy-resources
// scenarios/ concept (a composition of modules for a deployment).
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local alertsLib = import 'libs/alerts-observ-lib/main.libsonnet';
local logsLib = import 'libs/logs-lib/main.libsonnet';

{
  // new(config)
  //   config: { uid, title, datasource?, tags?, owner?, domain?, folder?,
  //             members: [ { key, pack, config? } ] }  (pack = an observ-lib)
  new(config)::
    local cfg = {
      datasource: '${datasource}',
      lokiDatasource: '${loki_datasource}',
      tags: [],
      owner: 'monitoring',
      domain: 'observability',
      includeAlerts: true,
      includeLogs: true,
      members: [],
    } + config;
    // every profile also gets an alerts-overview + logs board (toggleable).
    local extra =
      (if cfg.includeAlerts then [{ key: 'alerts', pack: alertsLib, config: { filteringSelector: '' } }] else [])
      + (if cfg.includeLogs then [{ key: 'logs', pack: logsLib, config: { datasource: cfg.lokiDatasource, filterSelector: 'job=~".+"' } }] else []);
    local members = cfg.members + extra;
    local folder = if std.objectHas(cfg, 'folder') then cfg.folder else { uid: 'observ-viz-scn-' + cfg.uid, title: cfg.title };
    local tags = ['observ-viz', 'scenario', cfg.uid] + cfg.tags;
    local sysName = 'observ-viz-' + cfg.uid;

    local instances = [
      {
        key: m.key,
        instance: m.pack.new(
          { datasource: cfg.datasource }
          + (if std.objectHas(m, 'config') then m.config else {})
          + { uid: 'scn-' + cfg.uid + '-' + m.key, dashboardTitle: cfg.title + ' / ' + m.key }
        ),
      }
      for m in members
    ];

    {
      config: cfg,
      folder: folder,

      // boards: each member's pack dashboard, placed in the scenario folder.
      grafanaDashboards: {
        ['scn-' + cfg.uid + '-' + inst.key + '.json']:
          inst.instance.grafana.dashboard
          + dashboard.withFolder(folder.uid, folder.title)
          + dashboard.withTagsMixin(tags)
        for inst in instances
      },

      // merged prometheus alerts across all members.
      prometheusAlerts: {
        groups: std.flattenArrays([
          if std.objectHas(inst.instance, 'prometheus') then inst.instance.prometheus.alerts else []
          for inst in instances
        ]),
      },

      // Backstage catalog: a System for the scenario + a Component per member.
      backstage: {
        system: {
          apiVersion: 'backstage.io/v1alpha1',
          kind: 'System',
          metadata: { name: sysName, title: cfg.title, tags: ['observ-viz', 'observability'] },
          spec: { owner: cfg.owner, domain: cfg.domain },
        },
        components: [
          {
            apiVersion: 'backstage.io/v1alpha1',
            kind: 'Component',
            metadata: {
              name: sysName + '-' + inst.key,
              title: cfg.title + ' / ' + inst.key,
              annotations: { 'grafana.app/dashboard-folder': folder.uid },
            },
            spec: { type: 'observability-pack', lifecycle: 'experimental', owner: cfg.owner, system: sysName },
          }
          for inst in instances
        ],
      },

      asMonitoringMixin():: {
        grafanaDashboards+:: self.grafanaDashboards,
        prometheusAlerts+:: self.prometheusAlerts,
      },
    },
}
