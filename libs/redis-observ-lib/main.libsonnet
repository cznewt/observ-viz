// observ-viz Redis pack (hand-written).
// Mirrors redis_exporter signal conventions, emitted as native v2 elements.
// Usage:
//   g.libs.databases.redis.new({ selector: 'job="redis"' }).grafana.dashboard
//   g.libs.databases.redis.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-redis',
      dashboardTitle: 'Redis',
      dashboardTags: ['redis', 'database'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'redis_up',
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
      connectedClients: sig('Connected clients', 'redis_connected_clients{%(queriesSelector)s}', 'short'),
      blockedClients: sig('Blocked clients', 'redis_blocked_clients{%(queriesSelector)s}', 'short'),
      commands: sig('Commands processed', 'rate(redis_commands_processed_total{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      hitRatio: sig(
        'Hit ratio',
        'sum(rate(redis_keyspace_hits_total{%(queriesSelector)s}[$__rate_interval])) / (sum(rate(redis_keyspace_hits_total{%(queriesSelector)s}[$__rate_interval])) + sum(rate(redis_keyspace_misses_total{%(queriesSelector)s}[$__rate_interval])))',
        'percentunit'
      ),
      memoryUsed: sig('Memory used', 'redis_memory_used_bytes{%(queriesSelector)s}', 'bytes'),
      evictions: sig('Evicted keys', 'rate(redis_evicted_keys_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Clients',
        width: 12,
        height: 7,
        elements: {
          connectedClients: signals.connectedClients.asTimeSeries('Connected clients'),
          blockedClients: signals.blockedClients.asTimeSeries('Blocked clients'),
        },
      },
      {
        title: 'Operations',
        width: 12,
        height: 7,
        elements: {
          commands: signals.commands.asTimeSeries('Commands/s'),
        },
      },
      {
        title: 'Hit ratio',
        width: 12,
        height: 7,
        elements: {
          hitRatio: signals.hitRatio.asStat('Keyspace hit ratio'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memoryUsed: signals.memoryUsed.asTimeSeries('Memory used'),
          evictions: signals.evictions.asTimeSeries('Evicted keys/s'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('redis', [
        alert.rule.new(
          'RedisDown', 'redis_up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'Redis instance {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'RedisHighMemory',
          'redis_memory_used_bytes' + rsBrace + ' > 4e9',
          '15m', 'warning', {},
          { summary: 'Redis memory on {{ $labels.instance }} is above 4GB.' }
        ),
        alert.rule.new(
          'RedisTooManyBlockedClients',
          'redis_blocked_clients' + rsBrace + ' > 0',
          '15m', 'warning', {},
          { summary: 'Redis on {{ $labels.instance }} has blocked clients.' }
        ),
        alert.rule.new(
          'RedisHighEvictionRate',
          'rate(redis_evicted_keys_total' + rsBrace + '[5m]) > 0',
          '15m', 'warning', {},
          { summary: 'Redis on {{ $labels.instance }} is evicting keys.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('redis.rules', [
        alert.rule.record(
          'instance:redis_keyspace_hit_ratio:ratio',
          'sum without (db) (rate(redis_keyspace_hits_total' + rsBrace + '[5m])) / (sum without (db) (rate(redis_keyspace_hits_total' + rsBrace + '[5m])) + sum without (db) (rate(redis_keyspace_misses_total' + rsBrace + '[5m])))'
        ),
        alert.rule.record('instance:redis_commands:rate5m', 'rate(redis_commands_processed_total' + rsBrace + '[5m])'),
      ]),
    ]),
}
