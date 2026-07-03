// observ-viz PostgreSQL pack (hand-written).
// Mirrors postgres_exporter (pg_stat_database) conventions, emitted as native v2
// elements. Usage:
//   g.libs.databases.postgres.new({ selector: 'job="postgres"' }).grafana.dashboard
//   g.libs.databases.postgres.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-postgres',
      dashboardTitle: 'PostgreSQL',
      dashboardTags: ['postgres', 'database'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'pg_up',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
      // deploy target: Software / Database (nested Grafana folders; loader creates both).
      folderUid: 'software-database',
      folderTitle: 'Database',
      folderParentUid: 'software',
      folderParentTitle: 'Software',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      backends: sig('Connections', 'sum by (datname)(pg_stat_database_numbackends{%(queriesSelector)s})', 'short'),
      commits: sig('Commits', 'sum(rate(pg_stat_database_xact_commit{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      rollbacks: sig('Rollbacks', 'sum(rate(pg_stat_database_xact_rollback{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      cacheHitRatio: sig('Cache hit ratio', 'sum(rate(pg_stat_database_blks_hit{%(queriesSelector)s}[$__rate_interval])) / (sum(rate(pg_stat_database_blks_hit{%(queriesSelector)s}[$__rate_interval])) + sum(rate(pg_stat_database_blks_read{%(queriesSelector)s}[$__rate_interval])))', 'percentunit'),
      databaseSize: sig('Database size', 'pg_database_size_bytes{%(queriesSelector)s}', 'bytes'),
      deadlocks: sig('Deadlocks', 'sum(rate(pg_stat_database_deadlocks{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Connections',
        width: 12,
        height: 7,
        elements: {
          backends: signals.backends.asTimeSeries('Active connections by database'),
        },
      },
      {
        title: 'Throughput',
        width: 12,
        height: 7,
        elements: {
          commits: signals.commits.asTimeSeries('Commits/s'),
          rollbacks: signals.rollbacks.asTimeSeries('Rollbacks/s'),
        },
      },
      {
        title: 'Cache',
        width: 12,
        height: 7,
        elements: {
          cacheHitRatio: signals.cacheHitRatio.asTimeSeries('Buffer cache hit ratio'),
        },
      },
      {
        title: 'Size',
        width: 12,
        height: 7,
        elements: {
          databaseSize: signals.databaseSize.asTimeSeries('Database size'),
          deadlocks: signals.deadlocks.asTimeSeries('Deadlocks/s'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('postgres', [
        alert.rule.new(
          'PostgresDown', 'pg_up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'PostgreSQL instance {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'PostgresHighRollbackRate',
          'sum without (datname) (rate(pg_stat_database_xact_rollback' + rsBrace + '[5m])) / sum without (datname) (rate(pg_stat_database_xact_commit' + rsBrace + '[5m]) + rate(pg_stat_database_xact_rollback' + rsBrace + '[5m])) > 0.1',
          '15m', 'warning', {},
          { summary: 'Rollback rate on {{ $labels.instance }} is above 10% of transactions.' }
        ),
        alert.rule.new(
          'PostgresLowCacheHitRatio',
          'sum without (datname) (rate(pg_stat_database_blks_hit' + rsBrace + '[5m])) / (sum without (datname) (rate(pg_stat_database_blks_hit' + rsBrace + '[5m])) + sum without (datname) (rate(pg_stat_database_blks_read' + rsBrace + '[5m]))) < 0.9',
          '15m', 'warning', {},
          { summary: 'Buffer cache hit ratio on {{ $labels.instance }} is below 90%.' }
        ),
        alert.rule.new(
          'PostgresDeadlocks',
          'sum without (datname) (rate(pg_stat_database_deadlocks' + rsBrace + '[5m])) > 0',
          '15m', 'warning', {},
          { summary: 'Deadlocks detected on {{ $labels.instance }}.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('postgres.rules', [
        alert.rule.record('instance:pg_cache_hit_ratio:ratio5m', 'sum without (datname) (rate(pg_stat_database_blks_hit' + rsBrace + '[5m])) / (sum without (datname) (rate(pg_stat_database_blks_hit' + rsBrace + '[5m])) + sum without (datname) (rate(pg_stat_database_blks_read' + rsBrace + '[5m])))'),
        alert.rule.record('instance:pg_commits:rate5m', 'sum without (datname) (rate(pg_stat_database_xact_commit' + rsBrace + '[5m]))'),
      ]),
    ]),
}
