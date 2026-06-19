// observ-viz Memcached pack (hand-written).
// Mirrors memcached_exporter signal conventions, emitted as native v2 elements.
// Usage:
//   g.packs.databases.memcached.new({ selector: 'job="memcached"' }).grafana.dashboard
//   g.packs.databases.memcached.new({...}).grafana.elements   // reuse in a board
local pack = import 'packs/_pack.libsonnet';
local signal = import 'signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-memcached',
      dashboardTitle: 'Memcached',
      dashboardTags: ['memcached', 'database'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'memcached_up',
    } + config;

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      commands: sig('Commands', 'sum(rate(memcached_commands_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      hitRatio: sig(
        'Hit ratio',
        'sum(rate(memcached_slab_lru_hits_total{%(queriesSelector)s}[$__rate_interval])) / (sum(rate(memcached_slab_lru_hits_total{%(queriesSelector)s}[$__rate_interval])) + sum(rate(memcached_slab_lru_misses_total{%(queriesSelector)s}[$__rate_interval])))',
        'percentunit'
      ),
      hits: sig('LRU hits', 'sum(rate(memcached_slab_lru_hits_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      misses: sig('LRU misses', 'sum(rate(memcached_slab_lru_misses_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      memoryUsed: sig('Memory used', 'memcached_current_bytes{%(queriesSelector)s}', 'bytes'),
      memoryLimit: sig('Memory limit', 'memcached_limit_bytes{%(queriesSelector)s}', 'bytes'),
      currentItems: sig('Current items', 'memcached_current_items{%(queriesSelector)s}', 'short'),
      evictions: sig('Evictions', 'sum(rate(memcached_items_evicted_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      connections: sig('Current connections', 'memcached_current_connections{%(queriesSelector)s}', 'short'),
      connectionsTotal: sig('Connections opened', 'sum(rate(memcached_connections_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Operations',
        width: 12,
        height: 7,
        elements: {
          commands: signals.commands.asTimeSeries('Commands/s'),
          evictions: signals.evictions.asTimeSeries('Evictions/s'),
        },
      },
      {
        title: 'Hit ratio',
        width: 12,
        height: 7,
        elements: {
          hitRatio: signals.hitRatio.asStat('LRU hit ratio'),
          hits: signals.hits.asTimeSeries('LRU hits/s'),
          misses: signals.misses.asTimeSeries('LRU misses/s'),
        },
      },
      {
        title: 'Memory',
        width: 12,
        height: 7,
        elements: {
          memoryUsed: signals.memoryUsed.asTimeSeries('Memory used'),
          memoryLimit: signals.memoryLimit.asTimeSeries('Memory limit'),
          currentItems: signals.currentItems.asTimeSeries('Current items'),
        },
      },
      {
        title: 'Connections',
        width: 12,
        height: 7,
        elements: {
          connections: signals.connections.asTimeSeries('Current connections'),
          connectionsTotal: signals.connectionsTotal.asTimeSeries('Connections opened/s'),
        },
      },
    ]),
}
