// observ-viz etcd pack (hand-written).
// Mirrors etcd server signal conventions, emitted as native v2 elements.
// Usage:
//   g.packs.databases.etcd.new({ selector: 'job="etcd"' }).grafana.dashboard
//   g.packs.databases.etcd.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-etcd',
      dashboardTitle: 'etcd',
      dashboardTags: ['etcd', 'database', 'kv'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'etcd_server_has_leader',
    } + config;

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      hasLeader: sig('Has leader', 'etcd_server_has_leader{%(queriesSelector)s}', 'short'),
      leaderChanges: sig('Leader changes', 'rate(etcd_server_leader_changes_seen_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      proposalsCommitted: sig('Proposals committed', 'rate(etcd_server_proposals_committed_total{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      proposalsFailed: sig('Proposals failed', 'rate(etcd_server_proposals_failed_total{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      walFsyncP99: sig('WAL fsync p99', 'histogram_quantile(0.99, sum by (le)(rate(etcd_disk_wal_fsync_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's'),
      dbSize: sig('DB size', 'etcd_mvcc_db_total_size_in_bytes{%(queriesSelector)s}', 'bytes'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Cluster',
        width: 12,
        height: 7,
        elements: {
          hasLeader: signals.hasLeader.asStat('Has leader'),
          leaderChanges: signals.leaderChanges.asTimeSeries('Leader changes/s'),
        },
      },
      {
        title: 'Operations',
        width: 12,
        height: 7,
        elements: {
          proposalsCommitted: signals.proposalsCommitted.asTimeSeries('Proposals committed/s'),
          proposalsFailed: signals.proposalsFailed.asTimeSeries('Proposals failed/s'),
        },
      },
      {
        title: 'Disk',
        width: 12,
        height: 7,
        elements: {
          walFsyncP99: signals.walFsyncP99.asTimeSeries('WAL fsync p99'),
          dbSize: signals.dbSize.asTimeSeries('DB total size'),
        },
      },
    ]),
}
