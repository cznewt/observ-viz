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
          + { uid: 'scn-' + cfg.uid + '-' + m.key, dashboardTitle: if std.objectHas(m, 'title') then m.title else cfg.title + ' / ' + m.key }
        ),
      }
      for m in members
    ];

    // every member's alert or rule groups, tagged with the member key.
    local taggedGroups(field) = std.flattenArrays([
      [{ key: inst.key, group: g } for g in inst.instance.prometheus[field]]
      for inst in instances
      if std.objectHas(inst.instance, 'prometheus') && std.objectHas(inst.instance.prometheus, field)
    ]);
    // group names must be unique inside one Mimir/Prometheus rule namespace:
    // members that embed the same lib (grafana + grafanaTest, three demo
    // environments) get their member key prefixed on the colliding names only.
    local uniqueGroups(tagged) =
      local names = [t.group.name for t in tagged];
      [if std.count(names, t.group.name) > 1 then t.group { name: t.key + '-' + t.group.name } else t.group for t in tagged];

    {
      config: cfg,
      folder: folder,

      // boards: each member's pack dashboard, placed in the scenario folder.
      grafanaDashboards: {
        ['scn-' + cfg.uid + '-' + inst.key + '.json']:
          inst.instance.grafana.dashboard
          + (if std.objectHas(folder, 'parent')
             then dashboard.withFolder(folder.uid, folder.title, folder.parent.uid, folder.parent.title)
             else dashboard.withFolder(folder.uid, folder.title))
          + dashboard.withTagsMixin(tags)
        for inst in instances
      },

      // merged prometheus alerts across all members.
      prometheusAlerts: { groups: uniqueGroups(taggedGroups('alerts')) },

      // merged recording rules across all members.
      prometheusRules: { groups: uniqueGroups(taggedGroups('rules')) },

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

      // monitor-tools / mixin consumers: v2 dashboard specs keyed by file name,
      // merged alert groups and recording rules. (Locals: `self` inside the
      // returned literal would be the literal itself.)
      asMonitoringMixin()::
        local boards = self.grafanaDashboards, alerts = self.prometheusAlerts, rules = self.prometheusRules;
        {
          grafanaDashboards+:: { [k]: boards[k].toSpec() for k in std.objectFields(boards) },
          prometheusAlerts+:: alerts,
          prometheusRules+:: rules,
        },
    },
}
