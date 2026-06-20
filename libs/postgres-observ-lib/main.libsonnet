// observ-viz PostgreSQL pack (hand-written).
// Mirrors postgres_exporter (pg_stat_database) conventions, emitted as native v2
// elements. Usage:
//   g.libs.databases.postgres.new({ selector: 'job="postgres"' }).grafana.dashboard
//   g.libs.databases.postgres.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-postgres',
      dashboardTitle: 'PostgreSQL',
      dashboardTags: ['postgres', 'database'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'pg_up',
    } + config;

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
    ]),
}
