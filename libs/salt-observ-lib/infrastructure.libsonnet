// observ-viz salt infrastructure pack (hand-written).
// Fleet-level salt view: cluster / master / minion selection, tabs
//   Minions     online/offline status of every accepted minion, from the
//               salt_minion_online presence gauge (master presence_events ->
//               alloy engine -> Alloy gauge, 1h idle timeout)
//   Jobs        last-job tables + trends (reused from the salt jobs pack)
//   Conformity  per-minion highstate conformity (reused from the conformity pack)
// Usage:
//   g.libs.automation.infrastructure.new({}).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
local jobsPack = import 'libs/salt-observ-lib/main.libsonnet';
local confPack = import 'libs/salt-observ-lib/conformity.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'salt-infrastructure',
      dashboardTitle: 'Salt Infrastructure',
      dashboardTags: ['salt', 'salt-observ-lib', 'cluster-level'],
      datasource: '${datasource}',
      selector: 'cluster=~"$cluster", master=~"$master", id=~"$id"',
      varMetric: 'salt_minion_online',
      varLabels: ['cluster', 'master', 'id'],
      primaryTabTitle: 'Minions',
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      links: [
        { title: 'Salt Jobs', type: 'link', icon: 'dashboard', url: '/d/salt-jobs-overview?var-cluster=${cluster}', keepTime: true, targetBlank: false, asDropdown: false, includeVars: false, tooltip: 'All jobs / engine / traces', tags: [] },
        { title: 'Conformity', type: 'link', icon: 'dashboard', url: '/d/salt-conformity?var-cluster=${cluster}', keepTime: true, targetBlank: false, asDropdown: false, includeVars: false, tooltip: 'Per-minion highstate conformity', tags: [] },
        { title: 'Job view (states / return / trace)', type: 'link', icon: 'doc', url: '/d/salt-job-view', keepTime: true, targetBlank: false, asDropdown: false, includeVars: false, tooltip: 'Per-job drill-down: states, full return, Tempo trace', tags: [] },
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster boards', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local s = cfg.selector;

    // the sibling packs expose their raw panels via grafana.elements — their
    // queries filter on $cluster/$id/${datasource}, which this board defines too
    local jobs = jobsPack.new({}).grafana.elements;
    local conf = confPack.new({}).grafana.elements;

    local sig(name, expr, unit, legend='{{id}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(s).withLegendFormat(legend);
    local signals = {
      accepted: sig('Accepted minions', 'count(salt_minion_online{%(queriesSelector)s})', 'short', 'accepted'),
      online: sig('Online', 'count(salt_minion_online{%(queriesSelector)s} == 1) or vector(0)', 'short', 'online'),
      offline: sig('Offline', 'count(salt_minion_online{%(queriesSelector)s} == 0) or vector(0)', 'short', 'offline'),
      onlineTrend: sig('Online minions', 'count by (cluster) (salt_minion_online{%(queriesSelector)s} == 1) or vector(0)', 'short', '{{cluster}}'),
      statusSeries: sig('Minion status', 'salt_minion_online{%(queriesSelector)s}', 'short', '{{cluster}} · {{id}}'),
    };

    // one row per cluster/minion, online/offline over the dashboard range
    local statusTimeline =
      panel.stateTimeline.new('Minion status timeline')
      + panel.stateTimeline.withTargets([signals.statusSeries.asTarget()])
      + panel.stateTimeline.withOptions({ showValue: 'never', mergeValues: true, rowHeight: 0.8, legend: { showLegend: true, displayMode: 'list', placement: 'bottom' } })
      + panel.stateTimeline.withMappings([{ type: 'value', options: {
        '0': { text: 'offline', color: 'red' },
        '1': { text: 'online', color: 'green' },
      } }]);

    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local minionsTable =
      panel.table.new('Minions')
      + panel.table.withTargets([
        tq('salt_minion_online{' + s + '}'),
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['cluster', 'master', 'id', 'Value'] } } },
        { id: 'organize', options: {
          indexByName: { cluster: 0, master: 1, id: 2, Value: 3 },
          renameByName: { cluster: 'Cluster', master: 'Master', id: 'Minion', Value: 'Status' },
        } },
        // offline first, then by name
        { id: 'sortBy', options: { sort: [{ field: 'Status', desc: false }] } },
      ])
      + panel.table.withOverrides([
        ov('Status', [
          { id: 'custom.width', value: 120 },
          { id: 'mappings', value: [{ type: 'value', options: {
            '0': { text: 'offline', color: 'red' },
            '1': { text: 'online', color: 'green' },
          } }] },
          { id: 'custom.cellOptions', value: { type: 'color-background', mode: 'basic' } },
        ]),
        ov('Minion', [{ id: 'links', value: [{ title: 'Salt jobs for this minion', url: '/d/salt-jobs-overview?var-cluster=${__data.fields.Cluster}&var-id=${__data.fields.Minion}' }] }]),
      ]);

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 6,
        height: 5,
        elements: {
          accepted: signals.accepted.asStat('Accepted minions'),
          online: signals.online.asStat('Online'),
          offline: signals.offline.asStat('Offline'),
        },
      },
      {
        title: 'Minions',
        width: 24,
        height: 14,
        elements: {
          minionsTable: minionsTable,
        },
      },
      {
        title: 'Timeline',
        width: 24,
        height: 14,
        elements: {
          statusTimeline: statusTimeline,
        },
      },
    ], [
      alert.rule.group('salt-infrastructure', [
        alert.rule.new(
          'SaltMinionOffline',
          'max by (cluster, id) (salt_minion_online' + rsBrace + ') == 0',
          '30m',
          'warning',
          {},
          {
            summary: 'Salt minion offline.',
            description: 'Minion {{ $labels.id }} ({{ $labels.cluster }}) has not been connected to its master for 30 minutes.',
          }
        ),
      ]),
    ], [], [
      {
        title: 'Jobs',
        width: 24,
        height: 9,
        presence: { query: 'salt_job_success{cluster=~"$cluster"}', label: 'id' },
        elements: {
          a_jobs: jobs.jobsTable,
          b_failing: jobs.failingTable,
          c_duration: jobs.duration,
          d_failed: jobs.failedByJob,
        },
      },
      {
        title: 'Conformity',
        width: 24,
        height: 11,
        presence: { query: 'salt_job_success{job_name="highstate", cluster=~"$cluster"}', label: 'id' },
        elements: {
          a_conformity: conf.conformityTable,
          b_trend: conf.a_conformityPct,
        },
      },
    ]),
}
