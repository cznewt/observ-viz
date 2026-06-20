// observ-viz etcd pack (hand-written).
// Mirrors etcd server signal conventions, emitted as native v2 elements.
// Usage:
//   g.libs.databases.etcd.new({ selector: 'job="etcd"' }).grafana.dashboard
//   g.libs.databases.etcd.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-etcd',
      dashboardTitle: 'etcd',
      dashboardTags: ['etcd', 'database', 'kv'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'etcd_server_has_leader',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

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
    ], [
      // alerting rule group
      alert.rule.group('etcd', [
        alert.rule.new(
          'EtcdNoLeader', 'etcd_server_has_leader' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'etcd member {{ $labels.instance }} has no leader.' }
        ),
        alert.rule.new(
          'EtcdHighLeaderChanges',
          'rate(etcd_server_leader_changes_seen_total' + rsBrace + '[15m]) > 0',
          '15m', 'warning', {},
          { summary: 'etcd member {{ $labels.instance }} has seen frequent leader changes.' }
        ),
        alert.rule.new(
          'EtcdHighProposalFailures',
          'rate(etcd_server_proposals_failed_total' + rsBrace + '[5m]) > 0',
          '15m', 'warning', {},
          { summary: 'etcd member {{ $labels.instance }} is seeing proposal failures.' }
        ),
        alert.rule.new(
          'EtcdHighWalFsyncDuration',
          'histogram_quantile(0.99, sum by (le) (rate(etcd_disk_wal_fsync_duration_seconds_bucket' + rsBrace + '[5m]))) > 0.5',
          '15m', 'warning', {},
          { summary: 'etcd member {{ $labels.instance }} WAL fsync p99 is high.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('etcd.rules', [
        alert.rule.record('instance:etcd_wal_fsync_duration_seconds:p99', 'histogram_quantile(0.99, sum by (le) (rate(etcd_disk_wal_fsync_duration_seconds_bucket' + rsBrace + '[5m])))'),
        alert.rule.record('instance:etcd_proposals_failed:rate5m', 'rate(etcd_server_proposals_failed_total' + rsBrace + '[5m])'),
      ]),
    ]),
}
