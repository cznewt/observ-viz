// observ-viz salt conformity pack (hand-written).
// Alcali-style conformity view over the salt_job_* gauges (see main.libsonnet):
// per minion, the LAST highstate (job_name="highstate") within the dashboard
// range decides the bucket —
//   conform      success && failed == 0 && changed == 0
//   changed      success && failed == 0 && changed  > 0   (drift / would-change)
//   non-conform  failed > 0 || !success (crashed, rejected by concurrent run)
// last_over_time($__range) keeps minions visible whose highstate ran days ago
// (the gauges themselves only hold the latest run).
// Usage:
//   g.libs.automation.conformity.new({}).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'salt-conformity',
      dashboardTitle: 'Salt Conformity',
      dashboardTags: ['salt', 'salt-observ-lib', 'cluster-level'],
      datasource: '${datasource}',
      selector: 'job_name="highstate", cluster=~"$cluster", id=~"$id"',
      varMetric: 'salt_job_success',
      varLabels: ['cluster', 'id'],
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      links: [
        { title: 'Salt Jobs', type: 'link', icon: 'dashboard', url: '/d/salt-jobs-overview?var-cluster=${cluster}', keepTime: true, targetBlank: false, asDropdown: false, includeVars: false, tooltip: 'All jobs / engine / traces', tags: [] },
        { title: 'Job view (states / return / trace)', type: 'link', icon: 'doc', url: '/d/salt-job-view', keepTime: true, targetBlank: false, asDropdown: false, includeVars: false, tooltip: 'Per-job drill-down: states, full return, Tempo trace', tags: [] },
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster boards', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local lotq = 'last_over_time(%s{%%(queriesSelector)s}[$__range])';

    local sig(name, expr, unit, legend='{{id}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    // per-minion aggregates (bare label sets so and/or match cleanly);
    // "bad" = failed states OR the job itself did not succeed (crashed,
    // rejected by a concurrent run, ...)
    local agg(m) = 'max by (cluster, id) (' + (lotq % m) + ')';
    local F = agg('salt_job_failed_states');
    local S = agg('salt_job_success');
    local C = agg('salt_job_changed_states');
    local signals = {
      minions: sig('Minions', 'count(' + S + ')', 'short', 'minions'),
      conform: sig('Conform', 'count(((' + F + ') == 0) and ((' + S + ') == 1) and ((' + C + ') == 0)) or vector(0)', 'short', 'conform'),
      changed: sig('Changed', 'count(((' + C + ') > 0) and ((' + F + ') == 0) and ((' + S + ') == 1)) or vector(0)', 'short', 'changed'),
      nonconform: sig('Non-conform', 'count(((' + F + ') > 0) or ((' + S + ') == 0)) or vector(0)', 'short', 'non-conform'),
      conformityPct: sig('Conformity', '100 * (count(((' + F + ') == 0) and ((' + S + ') == 1)) or vector(0)) / count(' + S + ')', 'percent', 'conformity'),
      failedByMinion: sig('Failed states', lotq % 'salt_job_failed_states', 'short'),
      changedByMinion: sig('Changed states', lotq % 'salt_job_changed_states', 'short'),
      durationByMinion: sig('Highstate duration', lotq % 'salt_job_duration', 's'),
    };

    // Conformity table: identity row from the total-states gauge (A), the
    // remaining columns joined on the minion id (B..E carry id+Value only, so
    // the join stays clean — same pattern as iot devicesTable).
    local s = cfg.selector;
    local lot(m) = 'last_over_time(' + m + '{' + s + '}[$__range])';
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local conformityTable =
      panel.table.new('Conformity by minion')
      // join key is cluster/id — a bare id is NOT fleet-unique (both site
      // masters are id="master")
      + panel.table.withTargets([
        tq('label_join(sum by (cluster, id) (' + lot('salt_job_total_states') + '), "key", "/", "cluster", "id")'),  // A: identity + totals
        tq('sum by (key) (label_join(2 * clamp_max((' + lot('salt_job_failed_states') + ' > bool 0) + (' + lot('salt_job_success') + ' == bool 0), 1) + (' + lot('salt_job_changed_states') + ' > bool 0) * (' + lot('salt_job_failed_states') + ' == bool 0) * (' + lot('salt_job_success') + ' == bool 1), "key", "/", "cluster", "id"))'),  // B: status (2 bad / 1 changed / 0 conform)
        tq('sum by (key) (label_join(' + lot('salt_job_changed_states') + ', "key", "/", "cluster", "id"))'),  // C: changed
        tq('sum by (key) (label_join(' + lot('salt_job_failed_states') + ', "key", "/", "cluster", "id"))'),  // D: failed
        tq('sum by (key) (label_join(' + lot('salt_job_duration') + ', "key", "/", "cluster", "id"))'),  // E: duration
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['cluster', 'id', 'key', 'Value #A', 'Value #B', 'Value #C', 'Value #D', 'Value #E'] } } },
        { id: 'seriesToColumns', options: { byField: 'key' } },
        { id: 'organize', options: {
          excludeByName: { key: true },
          indexByName: { cluster: 0, id: 1, 'Value #B': 2, 'Value #A': 3, 'Value #C': 4, 'Value #D': 5, 'Value #E': 6 },
          renameByName: { cluster: 'Cluster', id: 'Minion', 'Value #B': 'Status', 'Value #A': 'States', 'Value #C': 'Changed', 'Value #D': 'Failed', 'Value #E': 'Duration' },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Status', desc: true }] } },
      ])
      + panel.table.withOverrides([
        ov('Status', [
          { id: 'custom.width', value: 130 },
          { id: 'mappings', value: [{ type: 'value', options: {
            '0': { text: 'conform', color: 'green' },
            '1': { text: 'changed', color: 'orange' },
            '2': { text: 'non-conform', color: 'red' },
          } }] },
          { id: 'custom.cellOptions', value: { type: 'color-background', mode: 'basic' } },
        ]),
        ov('Changed', [
          { id: 'custom.width', value: 100 },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'text', value: null }, { color: 'orange', value: 1 }] } },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ]),
        ov('Failed', [
          { id: 'custom.width', value: 100 },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'text', value: null }, { color: 'red', value: 1 }] } },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ]),
        ov('States', [{ id: 'custom.width', value: 100 }]),
        ov('Duration', [{ id: 'unit', value: 's' }, { id: 'custom.width', value: 110 }]),
        ov('Minion', [{ id: 'links', value: [{ title: 'Salt jobs for this minion', url: '/d/salt-infrastructure?var-cluster=${__data.fields.Cluster}&var-id=${__data.fields.Minion}' }] }]),
      ]);

    pack.build(cfg, signals, [
      {
        title: 'Core',
        width: 6,
        height: 5,
        elements: {
          minions: signals.minions.asStat('Minions'),
          conform: signals.conform.asStat('Conform'),
          changed: signals.changed.asStat('Changed'),
          nonconform: signals.nonconform.asStat('Non-conform'),
        },
      },
      {
        title: 'Conformity',
        width: 24,
        height: 12,
        elements: {
          conformityTable: conformityTable,
        },
      },
      {
        title: 'Trends',
        width: 12,
        height: 8,
        elements: {
          a_conformityPct: signals.conformityPct.asTimeSeries('Conformity %'),
          b_failed: signals.failedByMinion.asTimeSeries('Failed states by minion'),
          c_changed: signals.changedByMinion.asTimeSeries('Changed states by minion'),
          d_duration: signals.durationByMinion.asTimeSeries('Highstate duration by minion'),
        },
      },
    ], [
      alert.rule.group('salt-conformity', [
        alert.rule.new(
          'SaltMinionNonConformant',
          '(max by (cluster, id) (salt_job_failed_states{job_name="highstate"' + (if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '') + '}) > 0) or (max by (cluster, id) (salt_job_success{job_name="highstate"' + (if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '') + '}) == 0)',
          '1h',
          'warning',
          {},
          {
            summary: 'Salt minion non-conformant.',
            description: '{{ $labels.id }} ({{ $labels.cluster }}) failed {{ $value }} state(s) in its last highstate and has been non-conformant for 1 hour.',
          }
        ),
      ]),
    ], []),
}
