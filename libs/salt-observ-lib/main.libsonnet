// observ-viz salt jobs pack (hand-written).
// Consumes the salt-grafana-Alloy pipeline (see README.md): the saltext alloy
// engine enriches job-return events into
//   - salt_job_{duration,success,total_states,changed_states,failed_states}
//     gauges (labels cluster/id/fun/job_name) via the master-pod Alloy, and
//   - {job="salt_events"} Loki lines (traceID deep-links to Tempo).
// The postgres/tempo drill-down lives in the ported salt-job-view board
// (dashboards/salt-job-view.json) — linked from here.
// Usage:
//   g.libs.automation.salt.new({}).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'salt-jobs-overview',
      dashboardTitle: 'Salt Jobs',
      dashboardTags: ['salt', 'salt-observ-lib', 'cluster-level'],
      datasource: '${datasource}',
      selector: 'cluster=~"$cluster", id=~"$id"',
      varMetric: 'salt_job_success',
      varLabels: ['cluster', 'id'],
      ruleSelector: '',
      lokiDatasource: true,
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      links: [
        { title: 'Job view (states / return / trace)', type: 'link', icon: 'doc', url: '/d/salt-job-view', keepTime: true, targetBlank: false, asDropdown: false, includeVars: false, tooltip: 'Per-job drill-down: postgres TreeView + Tempo trace', tags: [] },
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster boards', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';

    local sig(name, expr, unit, legend='{{id}} · {{job_name}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      minionsReporting: sig('Minions reporting', 'count(salt_job_success{%(queriesSelector)s})', 'short', 'minions'),
      minionsFailing: sig('Minions failing', 'count(salt_job_success{%(queriesSelector)s} == 0) or vector(0)', 'short', 'failing'),
      statesFailed: sig('States failed', 'sum(salt_job_failed_states{%(queriesSelector)s})', 'short', 'failed'),
      statesChanged: sig('States changed', 'sum(salt_job_changed_states{%(queriesSelector)s})', 'short', 'changed'),
      duration: sig('Job duration', 'salt_job_duration{%(queriesSelector)s}', 's'),
      failedByJob: sig('States failed', 'salt_job_failed_states{%(queriesSelector)s}', 'short'),
      success: sig('Job success', 'salt_job_success{%(queriesSelector)s}', 'short'),
    };

    // Last-job-per-(minion,function) table from the gauges: identity + duration
    // from one instant query (labels become columns), red rows via the failed
    // count of the same series set.
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local jobsTable =
      panel.table.new('Last jobs')
      + panel.table.withTargets([
        tq('salt_job_duration{' + cfg.selector + '}'),  // A: identity + duration
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['cluster', 'id', 'fun', 'job_name', 'Value'] } } },
        { id: 'organize', options: {
          indexByName: { cluster: 0, id: 1, fun: 2, job_name: 3, Value: 4 },
          renameByName: { cluster: 'Cluster', id: 'Minion', fun: 'Function', job_name: 'Job', Value: 'Duration' },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Duration', desc: true }] } },
      ])
      + panel.table.withOverrides([
        ov('Duration', [{ id: 'unit', value: 's' }]),
      ]);
    local failingTable =
      panel.table.new('Failing (last run)')
      + panel.table.withTargets([
        tq('salt_job_failed_states{' + cfg.selector + '} > 0'),
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['cluster', 'id', 'fun', 'job_name', 'Value'] } } },
        { id: 'organize', options: {
          indexByName: { cluster: 0, id: 1, fun: 2, job_name: 3, Value: 4 },
          renameByName: { cluster: 'Cluster', id: 'Minion', fun: 'Function', job_name: 'Job', Value: 'Failed states' },
        } },
      ])
      + panel.table.withOverrides([
        ov('Failed states', [{ id: 'color', value: { mode: 'fixed', fixedColor: 'red' } }]),
      ]);

    // Engine → Alloy → Loki/Mimir pipeline self-metrics (job="salt-events-pipeline",
    // instance = the master host; no cluster label — one series per master).
    local psig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector('job="salt-events-pipeline"').withLegendFormat('{{instance}}');
    local pipeSignals = {
      eventsReceived: psig('Events received', 'rate(loki_source_api_entries_written{%(queriesSelector)s}[$__rate_interval])', 'short'),
      eventsShipped: psig('Events shipped to Loki', 'rate(loki_write_sent_entries_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      eventsDropped: psig('Events dropped', 'rate(loki_write_dropped_entries_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      rwFailed: psig('Remote-write failed samples', 'rate(prometheus_remote_storage_samples_failed_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
    };

    // Latest job traces straight from Tempo (TraceQL search; every trace id is
    // the zero-padded jid, same ids the events/log lines link to).
    local tracesPanel =
      panel.traces.new('Recent job traces')
      + panel.traces.withTargets([
        // state runs only (upstream salt-grafana traced state.apply/highstate,
        // not every job) — and kspan's stream would crowd out an unfiltered {}
        query.base('tempo', { query: '{ span.fun =~ "state\\..*" && resource.cluster =~ "$cluster" }', queryType: 'traceql', limit: 20, tableType: 'traces' })
        + query.withDatasource('newt-tempo'),
      ]);

    // Raw enriched event stream (jid, summary counts, traceID → Tempo derived link).
    local eventsLog =
      panel.logs.new('Job events')
      + panel.logs.withTargets([
        query.loki.new('${loki_datasource}', '{job="salt_events", cluster=~"$cluster"} | json | id =~ "$id"'),
      ])
      + { spec+: { options+: { showTime: true, wrapLogMessage: true, sortOrder: 'Descending' } } };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 6,
        height: 5,
        elements: {
          minionsReporting: signals.minionsReporting.asStat('Minions reporting'),
          minionsFailing: signals.minionsFailing.asStat('Minions failing'),
          statesFailed: signals.statesFailed.asStat('States failed (last runs)'),
          statesChanged: signals.statesChanged.asStat('States changed (last runs)'),
        },
      },
      {
        title: 'Jobs',
        width: 12,
        height: 9,
        elements: {
          jobsTable: jobsTable,
          failingTable: failingTable,
        },
      },
      {
        title: 'Trends',
        width: 12,
        height: 8,
        elements: {
          duration: signals.duration.asTimeSeries('Job duration'),
          failedByJob: signals.failedByJob.asTimeSeries('States failed'),
        },
      },
      {
        title: 'Events',
        width: 24,
        height: 10,
        elements: {
          eventsLog: eventsLog,
        },
      },
      {
        title: 'Traces',
        width: 24,
        height: 10,
        elements: {
          tracesPanel: tracesPanel,
        },
      },
      {
        title: 'Engine',
        width: 12,
        height: 7,
        elements: {
          eventsReceived: pipeSignals.eventsReceived.asTimeSeries('Events received (engine → alloy)'),
          eventsShipped: pipeSignals.eventsShipped.asTimeSeries('Events shipped to Loki'),
          eventsDropped: pipeSignals.eventsDropped.asTimeSeries('Events dropped'),
          rwFailed: pipeSignals.rwFailed.asTimeSeries('Remote-write failed samples'),
        },
      },
    ], [
      alert.rule.group('salt-jobs', [
        alert.rule.new(
          'SaltJobFailed',
          'max by (cluster, id, job_name) (salt_job_success' + rsBrace + ') == 0',
          '10m',
          'warning',
          {},
          {
            summary: 'Salt job failing on a minion.',
            description: 'The last {{ $labels.job_name }} run on {{ $labels.id }} ({{ $labels.cluster }}) failed and has stayed failed for 10 minutes.',
          }
        ),
        alert.rule.new(
          'SaltStatesFailing',
          'max by (cluster, id, job_name) (salt_job_failed_states' + rsBrace + ') > 0',
          '15m',
          'warning',
          {},
          {
            summary: 'Salt states failing on a minion.',
            description: '{{ $value }} state(s) failed in the last {{ $labels.job_name }} run on {{ $labels.id }} ({{ $labels.cluster }}).',
          }
        ),
      ]),
    ]),
}
