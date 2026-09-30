// observ-viz MongoDB pack (hand-written).
// Built for percona/mongodb_exporter >= 0.20 (--collect-all), on its current
// metric schema (mongodb_ss_* from serverStatus, mongodb_rs_* from
// replSetGetStatus, mongodb_dbstats_*); the oplog window and the replication
// headroom alert read the only oplog head / tail series the exporter has, the
// v1 ones behind --compatible-mode. Checked against exporter 0.44 on MongoDB 7.
// Alerts ported from the service catalog's mongodb-mixin (awesome-prometheus-
// alerts, written for the old exporter's names): MongodbDown, replication lag
// and headroom, open cursors, cursor timeouts, connections - its
// MongodbVirtualMemoryUsage is dropped (virtual vs MMAPv1 mapped memory, which
// WiredTiger does not have) and replica member health is added.
// serverStatus series carry rs_state, which changes on failover, so per-member
// queries aggregate by instance.
// Usage:
//   g.libs.databases.document.mongodb.new({ ruleSelector: 'job=~".*mongodb.*"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-mongodb',
      dashboardTitle: 'MongoDB',
      // Platform / Databases
      folderPath: (import 'libs/common-lib/folders.libsonnet').databases,
      dashboardTags: ['mongodb', 'database', 'app-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      selector: 'job=~"$job", cluster=~"$cluster", instance=~"$instance"',
      varMetric: 'mongodb_up',
      varLabels: ['cluster', 'instance'],
      ruleSelector: '',
      replicationLagSeconds: 10,
      openCursors: 10000,
      cursorTimeoutsPerMinute: 100,
      connectionsRatio: 0.8,
    } + config;

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);
    // opLatencies are cumulative microseconds per op type
    local latency(opType) =
      'sum(rate(mongodb_ss_opLatencies_latency{op_type="' + opType + '", %(queriesSelector)s}[$__rate_interval])) / sum(rate(mongodb_ss_opLatencies_ops{op_type="' + opType + '", %(queriesSelector)s}[$__rate_interval])) / 1e6';
    local conn(type, by='instance') = 'sum by (' + by + ') (mongodb_ss_connections{conn_type="' + type + '", %(queriesSelector)s})';
    // each member's exporter reports the whole replica set, so the lag is the
    // primary's optime minus each secondary's, as seen from one member
    local optime(state, by) = 'max by (' + by + ') (mongodb_rs_members_optimeDate{member_state="' + state + '", %(queriesSelector)s})';

    local signals = {
      // overview
      up: sig('Instances up', 'sum(mongodb_up{%(queriesSelector)s})', 'short', 'up'),
      ops: sig('Operations', 'sum(rate(mongodb_ss_opcounters{legacy_op_type!="command", %(queriesSelector)s}[$__rate_interval]))', 'ops', 'operations'),
      connections: sig('Connections', 'sum(mongodb_ss_connections{conn_type="current", %(queriesSelector)s})', 'short', 'connections'),
      readLatency: sig('Read latency', latency('reads'), 's', 'reads'),
      writeLatency: sig('Write latency', latency('writes'), 's', 'writes'),
      uptime: sig('Uptime', 'min(mongodb_ss_uptime{%(queriesSelector)s})', 's', 'uptime'),
      // operations
      opsByType: sig('Operations by type', 'sum by (legacy_op_type) (rate(mongodb_ss_opcounters{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{legacy_op_type}}'),
      replOps: sig('Replicated operations', 'sum by (legacy_op_type) (rate(mongodb_ss_opcountersRepl{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{legacy_op_type}}'),
      documents: sig('Document operations', 'sum by (doc_op_type) (rate(mongodb_ss_metrics_document{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{doc_op_type}}'),
      latencyByType: sig('Latency by operation', 'sum by (op_type) (rate(mongodb_ss_opLatencies_latency{op_type!="transactions", %(queriesSelector)s}[$__rate_interval])) / sum by (op_type) (rate(mongodb_ss_opLatencies_ops{op_type!="transactions", %(queriesSelector)s}[$__rate_interval])) / 1e6', 's', '{{op_type}}'),
      scannedObjects: sig('Documents scanned per returned', 'sum(rate(mongodb_ss_metrics_queryExecutor_scannedObjects{%(queriesSelector)s}[$__rate_interval])) / sum(rate(mongodb_ss_metrics_document{doc_op_type="returned", %(queriesSelector)s}[$__rate_interval]))', 'short', 'documents scanned per returned'),
      scannedKeys: sig('Index keys scanned per returned', 'sum(rate(mongodb_ss_metrics_queryExecutor_scanned{%(queriesSelector)s}[$__rate_interval])) / sum(rate(mongodb_ss_metrics_document{doc_op_type="returned", %(queriesSelector)s}[$__rate_interval]))', 'short', 'index keys scanned per returned'),
      ttlDeletes: sig('TTL deletes', 'sum by (instance) (rate(mongodb_ss_metrics_ttl_deletedDocuments{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      // connections & cursors
      connectionsPerInstance: sig('Connections', conn('current'), 'short'),
      connectionUsage: sig('Connection usage', conn('current') + ' / (' + conn('current') + ' + ' + conn('available') + ')', 'percentunit'),
      cursors: sig('Open cursors', 'sum by (csr_type) (mongodb_ss_metrics_cursor_open{%(queriesSelector)s})', 'short', '{{csr_type}}'),
      cursorTimeouts: sig('Cursor timeouts', 'sum by (instance) (rate(mongodb_ss_metrics_cursor_timedOut{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      queued: sig('Queued operations', 'sum by (count_type) (mongodb_ss_globalLock_currentQueue{count_type!="total", %(queriesSelector)s})', 'short', '{{count_type}}'),
      tickets: sig('WiredTiger tickets in use', 'sum by (txn_rw) (mongodb_ss_wt_concurrentTransactions_out{%(queriesSelector)s})', 'short', '{{txn_rw}}'),
      // resources
      resident: sig('Resident memory', 'sum by (instance) (mongodb_ss_mem_resident{%(queriesSelector)s}) * 1048576', 'bytes'),
      cacheUsed: sig('Cache used', 'sum by (instance) (mongodb_ss_wt_cache_bytes_currently_in_the_cache{%(queriesSelector)s}) / sum by (instance) (mongodb_ss_wt_cache_maximum_bytes_configured{%(queriesSelector)s})', 'percentunit', '{{instance}} used'),
      cacheDirty: sig('Cache dirty', 'sum by (instance) (mongodb_ss_wt_cache_tracked_dirty_bytes_in_the_cache{%(queriesSelector)s}) / sum by (instance) (mongodb_ss_wt_cache_maximum_bytes_configured{%(queriesSelector)s})', 'percentunit', '{{instance}} dirty'),
      pagesRead: sig('Pages read into cache', 'sum by (instance) (rate(mongodb_ss_wt_cache_pages_read_into_cache{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{instance}} read'),
      pagesWritten: sig('Pages written from cache', 'sum by (instance) (rate(mongodb_ss_wt_cache_pages_written_from_cache{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{instance}} written'),
      netIn: sig('Network in', 'sum by (instance) (rate(mongodb_ss_network_bytesIn{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} in'),
      netOut: sig('Network out', 'sum by (instance) (rate(mongodb_ss_network_bytesOut{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{instance}} out'),
      asserts: sig('Asserts', 'sum by (assert_type) (rate(mongodb_ss_asserts{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{assert_type}}'),
      pageFaults: sig('Page faults', 'sum by (instance) (rate(mongodb_ss_extra_info_page_faults{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      // replication
      memberState: sig('Member state', 'max by (instance) (mongodb_rs_myState{%(queriesSelector)s})', 'short'),
      members: sig('Members', 'count(max by (cluster, rs_nm, member_idx) (mongodb_rs_members_health{%(queriesSelector)s}))', 'short', 'members'),
      unhealthy: sig('Unhealthy members', 'count(min by (cluster, rs_nm, member_idx) (mongodb_rs_members_health{%(queriesSelector)s}) == 0) or vector(0)', 'short', 'unhealthy'),
      sinceElection: sig('Since last election', 'time() - max(mongodb_rs_members_electionDate{%(queriesSelector)s}) / 1000', 's', 'since election'),
      lag: sig('Replication lag', '(' + optime('PRIMARY', 'cluster, rs_nm') + ' - on (cluster, rs_nm) group_right ' + optime('SECONDARY', 'cluster, rs_nm, member_idx') + ') / 1000', 's', '{{rs_nm}} / {{member_idx}}'),
      oplogWindow: sig('Oplog window', 'max by (instance) (mongodb_mongod_replset_oplog_head_timestamp{%(queriesSelector)s} - mongodb_mongod_replset_oplog_tail_timestamp{%(queriesSelector)s})', 's'),
      // databases
      dataSize: sig('Data size', 'mongodb_dbstats_dataSize{database!~"admin|config|local", %(queriesSelector)s}', 'bytes', '{{instance}} {{database}}'),
      storageSize: sig('Storage size', 'mongodb_dbstats_storageSize{database!~"admin|config|local", %(queriesSelector)s}', 'bytes', '{{instance}} {{database}}'),
      indexSize: sig('Index size', 'mongodb_dbstats_indexSize{database!~"admin|config|local", %(queriesSelector)s}', 'bytes', '{{instance}} {{database}}'),
      objects: sig('Documents', 'mongodb_dbstats_objects{database!~"admin|config|local", %(queriesSelector)s}', 'short', '{{instance}} {{database}}'),
    };

    local presence(metrics) = { label: 'job', query: '{__name__=~"' + std.join('|', metrics) + '", job=~"$job"}' };
    local states = {
      '0': 'STARTUP', '1': 'PRIMARY', '2': 'SECONDARY', '3': 'RECOVERING', '5': 'STARTUP2',
      '6': 'UNKNOWN', '7': 'ARBITER', '8': 'DOWN', '9': 'ROLLBACK', '10': 'REMOVED',
    };
    local stateColor(s) = if s == '1' then 'green' else if s == '2' then 'blue' else if s == '7' then 'text' else 'red';

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 5,
        elements: {
          a_up: signals.up.asStat('Instances up'),
          b_ops: signals.ops.asStat('Operations'),
          c_connections: signals.connections.asStat('Connections'),
          d_read: signals.readLatency.asStat('Read latency'),
          e_write: signals.writeLatency.asStat('Write latency'),
          f_uptime: signals.uptime.asStat('Uptime'),
        },
      },
      {
        title: 'Operations',
        width: 12,
        height: 7,
        elements: {
          a_ops: signals.opsByType.asTimeSeries('Operations by type'),
          b_repl: signals.replOps.asTimeSeries('Replicated operations'),
          c_docs: signals.documents.asTimeSeries('Document operations'),
          d_latency: signals.latencyByType.asTimeSeries('Latency by operation'),
          e_efficiency: signals.scannedObjects.asTimeSeries('Query efficiency')
                        + panel.withTargetsMixin([signals.scannedKeys.asTarget()]),
          f_ttl: signals.ttlDeletes.asTimeSeries('TTL deletes'),
        },
      },
      {
        title: 'Connections & cursors',
        width: 12,
        height: 7,
        elements: {
          a_connections: signals.connectionsPerInstance.asTimeSeries('Connections'),
          b_usage: signals.connectionUsage.asTimeSeries('Connection usage'),
          c_cursors: signals.cursors.asTimeSeries('Open cursors'),
          d_timeouts: signals.cursorTimeouts.asTimeSeries('Cursor timeouts'),
          e_queued: signals.queued.asTimeSeries('Queued operations'),
          f_tickets: signals.tickets.asTimeSeries('WiredTiger tickets in use'),
        },
      },
      {
        title: 'Resources',
        width: 12,
        height: 7,
        elements: {
          a_resident: signals.resident.asTimeSeries('Resident memory'),
          b_cache: signals.cacheUsed.asTimeSeries('WiredTiger cache')
                   + panel.withTargetsMixin([signals.cacheDirty.asTarget()]),
          c_pages: signals.pagesRead.asTimeSeries('Cache pages')
                   + panel.withTargetsMixin([signals.pagesWritten.asTarget()]),
          d_network: signals.netIn.asTimeSeries('Network')
                     + panel.withTargetsMixin([signals.netOut.asTarget()]),
          e_asserts: signals.asserts.asTimeSeries('Asserts'),
          f_faults: signals.pageFaults.asTimeSeries('Page faults'),
        },
      },
    ], [
      alert.rule.group('mongodb', [
        alert.rule.new(
          'MongodbDown',
          'mongodb_up' + rs + ' == 0',
          '1m',
          'critical',
          {},
          { summary: 'MongoDB is down.', description: 'The exporter {{ $labels.instance }} cannot reach its MongoDB.' }
        ),
        alert.rule.new(
          'MongodbReplicaMemberUnhealthy',
          'min by (cluster, rs_nm, member_idx) (mongodb_rs_members_health' + rs + ') == 0',
          '1m',
          'critical',
          {},
          { summary: 'A MongoDB replica set member is unhealthy.', description: 'Member {{ $labels.member_idx }} of replica set {{ $labels.rs_nm }} is unhealthy - the set runs with less redundancy.' }
        ),
        alert.rule.new(
          'MongodbReplicationLag',
          '(max by (cluster, rs_nm) (mongodb_rs_members_optimeDate{member_state="PRIMARY"' + rsComma + '}) - on (cluster, rs_nm) group_right max by (cluster, rs_nm, member_idx) (mongodb_rs_members_optimeDate{member_state="SECONDARY"' + rsComma + '})) / 1000 > ' + cfg.replicationLagSeconds,
          '2m',
          'critical',
          {},
          { summary: 'MongoDB replication lag.', description: 'Secondary {{ $labels.member_idx }} of {{ $labels.rs_nm }} is {{ $value | humanizeDuration }} behind its primary.' }
        ),
        alert.rule.new(
          'MongodbReplicationHeadroom',
          'max by (cluster, instance) (mongodb_mongod_replset_oplog_head_timestamp' + rs + ' - mongodb_mongod_replset_oplog_tail_timestamp' + rs + ') - on (cluster, instance) (max by (cluster, instance) (mongodb_rs_members_optimeDate{member_state="PRIMARY"' + rsComma + '}) - min by (cluster, instance) (mongodb_rs_members_optimeDate{member_state="SECONDARY"' + rsComma + '})) / 1000 <= 0',
          '0m',
          'critical',
          {},
          { summary: 'MongoDB replication headroom is exhausted.', description: 'A secondary seen from {{ $labels.instance }} lags by more than the oplog window - it can no longer catch up and needs an initial sync.' }
        ),
        alert.rule.new(
          'MongodbNumberCursorsOpen',
          'sum by (cluster, instance) (mongodb_ss_metrics_cursor_open{csr_type="total"' + rsComma + '}) > ' + cfg.openCursors,
          '2m',
          'warning',
          {},
          { summary: 'MongoDB has too many open cursors.', description: '{{ $labels.instance }} holds {{ $value }} open cursors for its clients.' }
        ),
        alert.rule.new(
          'MongodbCursorsTimeouts',
          'sum by (cluster, instance) (rate(mongodb_ss_metrics_cursor_timedOut' + rs + '[5m])) * 60 > ' + cfg.cursorTimeoutsPerMinute,
          '2m',
          'warning',
          {},
          { summary: 'MongoDB cursors are timing out.', description: '{{ $value | humanize }} cursors per minute time out on {{ $labels.instance }}.' }
        ),
        alert.rule.new(
          'MongodbTooManyConnections',
          'sum by (cluster, instance) (mongodb_ss_connections{conn_type="current"' + rsComma + '}) / (sum by (cluster, instance) (mongodb_ss_connections{conn_type="current"' + rsComma + '}) + sum by (cluster, instance) (mongodb_ss_connections{conn_type="available"' + rsComma + '})) > ' + cfg.connectionsRatio,
          '2m',
          'warning',
          {},
          { summary: 'MongoDB runs out of connections.', description: '{{ $labels.instance }} uses {{ $value | humanizePercentage }} of its connection limit.' }
        ),
      ]),
    ], [], [
      {
        title: 'Replication',
        presence: presence(['mongodb_rs_myState']),
        groups: [
          {
            title: 'Replica set',
            width: 6,
            height: 5,
            elements: {
              a_state: signals.memberState.asStat('Member state')
                       + panel.stat.withMappings([{ type: 'value', options: { [k]: { text: states[k], color: stateColor(k), index: std.parseInt(k) } for k in std.objectFields(states) } }]),
              b_members: signals.members.asStat('Members'),
              c_unhealthy: signals.unhealthy.asStat('Unhealthy members'),
              d_election: signals.sinceElection.asStat('Since last election'),
            },
          },
          {
            title: 'Replication',
            width: 12,
            height: 7,
            elements: {
              a_lag: signals.lag.asTimeSeries('Replication lag'),
              b_oplog: signals.oplogWindow.asTimeSeries('Oplog window'),
            },
          },
        ],
      },
      {
        title: 'Databases',
        presence: presence(['mongodb_dbstats_dataSize']),
        width: 12,
        height: 7,
        elements: {
          a_data: signals.dataSize.asTimeSeries('Data size'),
          b_storage: signals.storageSize.asTimeSeries('Storage size'),
          c_index: signals.indexSize.asTimeSeries('Index size'),
          d_objects: signals.objects.asTimeSeries('Documents'),
        },
      },
    ]),
}
