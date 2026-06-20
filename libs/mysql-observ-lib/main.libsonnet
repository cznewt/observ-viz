// observ-viz MySQL pack (hand-written).
// Mirrors mysqld_exporter metric conventions, emitted as native v2 elements.
// Usage:
//   g.libs.databases.mysql.new({ selector: 'job="mysql"' }).grafana.dashboard
//   g.libs.databases.mysql.new({...}).grafana.elements   // reuse in a board
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-mysql',
      dashboardTitle: 'MySQL',
      dashboardTags: ['mysql', 'database'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'mysql_up',
    } + config;

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
    ]),
}
