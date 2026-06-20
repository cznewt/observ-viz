// observ-viz MySQL pack (hand-written).
// Mirrors mysqld_exporter metric conventions, emitted as native v2 elements.
// Usage:
//   g.libs.databases.mysql.new({ selector: 'job="mysql"' }).grafana.dashboard
//   g.libs.databases.mysql.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-mysql',
      dashboardTitle: 'MySQL',
      dashboardTags: ['mysql', 'database'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'mysql_up',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      connected: sig('Threads connected', 'mysql_global_status_threads_connected{%(queriesSelector)s}', 'short'),
      running: sig('Threads running', 'mysql_global_status_threads_running{%(queriesSelector)s}', 'short'),
      qps: sig('Queries per second', 'rate(mysql_global_status_queries{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      slow: sig('Slow queries', 'rate(mysql_global_status_slow_queries{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      bufferPool: sig('Buffer pool data', 'mysql_global_status_innodb_buffer_pool_bytes_data{%(queriesSelector)s}', 'bytes'),
      bytesSent: sig('Bytes sent', 'rate(mysql_global_status_bytes_sent{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
      bytesReceived: sig('Bytes received', 'rate(mysql_global_status_bytes_received{%(queriesSelector)s}[$__rate_interval])', 'Bps'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Connections',
        width: 12,
        height: 7,
        elements: {
          connected: signals.connected.asTimeSeries('Threads connected'),
          running: signals.running.asTimeSeries('Threads running'),
        },
      },
      {
        title: 'Queries',
        width: 12,
        height: 7,
        elements: {
          qps: signals.qps.asTimeSeries('Queries per second'),
          slow: signals.slow.asTimeSeries('Slow queries per second'),
        },
      },
      {
        title: 'InnoDB',
        width: 12,
        height: 7,
        elements: {
          bufferPool: signals.bufferPool.asTimeSeries('Buffer pool data bytes'),
        },
      },
      {
        title: 'Traffic',
        width: 12,
        height: 7,
        elements: {
          bytesSent: signals.bytesSent.asTimeSeries('Bytes sent'),
          bytesReceived: signals.bytesReceived.asTimeSeries('Bytes received'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('mysql', [
        alert.rule.new(
          'MysqlDown', 'mysql_up' + rsBrace + ' == 0', '5m', 'critical', {},
          { summary: 'MySQL instance {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'MysqlHighThreadsRunning',
          'mysql_global_status_threads_running' + rsBrace + ' > 50',
          '15m', 'warning', {},
          { summary: 'MySQL on {{ $labels.instance }} has more than 50 running threads.' }
        ),
        alert.rule.new(
          'MysqlHighSlowQueries',
          'rate(mysql_global_status_slow_queries' + rsBrace + '[5m]) > 1',
          '15m', 'warning', {},
          { summary: 'MySQL on {{ $labels.instance }} has more than 1 slow query per second.' }
        ),
        alert.rule.new(
          'MysqlHighConnections',
          'mysql_global_status_threads_connected' + rsBrace + ' > 200',
          '15m', 'warning', {},
          { summary: 'MySQL on {{ $labels.instance }} has more than 200 connected threads.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('mysql.rules', [
        alert.rule.record('instance:mysql_queries:rate5m', 'rate(mysql_global_status_queries' + rsBrace + '[5m])'),
        alert.rule.record('instance:mysql_slow_queries:rate5m', 'rate(mysql_global_status_slow_queries' + rsBrace + '[5m])'),
      ]),
    ]),
}
