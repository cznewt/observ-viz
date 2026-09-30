// observ-viz Elasticsearch pack (hand-written, NOT checked against live data -
// nothing ships elasticsearch_* series on the lab clusters today).
// A port of prometheus-community/elasticsearch_exporter's elasticsearch-mixin
// cluster board (overview, shards, documents, memory, threads, network; the
// upstream transport TX / RX queries are swapped, fixed here) plus node CPU,
// disk and circuit breakers. The upstream mixin ships no alerts; its example
// rules give ElasticsearchTooFewNodesRunning and ElasticsearchHeapTooHigh, the
// rest (down, health red / yellow, disk, thread-pool rejections) are ours.
// NOTE: the exporter labels every series with `cluster` = the Elasticsearch
// cluster name, which wins over a remote_write external `cluster` label; set
// `cluster` on the scrape target (honor_labels false) so the platform cluster
// stays in `cluster` and the ES name lands in `exported_cluster`.
// Usage:
//   g.libs.databases.search.elasticsearch.new({ ruleSelector: 'job=~".*elasticsearch.*"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-elasticsearch',
      dashboardTitle: 'Elasticsearch',
      // Platform / Databases
      folderPath: (import 'libs/common-lib/folders.libsonnet').databases,
      dashboardTags: ['elasticsearch', 'search', 'database', 'app-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      // `name` is the exporter's node label
      selector: 'job=~"$job", cluster=~"$cluster", name=~"$name"',
      varMetric: 'elasticsearch_jvm_memory_max_bytes',
      varLabels: ['cluster', 'name'],
      ruleSelector: '',
      // upstream's example rule assumes a 3-node cluster
      minNodes: 3,
      heapRatio: 0.9,
      diskAvailableRatio: 0.15,
    } + config;

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    // cluster health series carry no node `name`
    local clusterSel = 'job=~"$job", cluster=~"$cluster"';

    local sig(name, expr, unit, legend='{{name}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);
    local csig(name, expr, unit, legend) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(clusterSel).withLegendFormat(legend);
    local shards(state, legend) =
      csig(legend, 'sum(elasticsearch_cluster_health_' + state + '_shards{%(queriesSelector)s})', 'short', legend);

    local signals = {
      // overview: the worst selected cluster, green 2 / yellow 1 / red 0
      health: csig('Health', 'min(2 * max by (cluster, exported_cluster) (elasticsearch_cluster_health_status{color="green", %(queriesSelector)s}) + max by (cluster, exported_cluster) (elasticsearch_cluster_health_status{color="yellow", %(queriesSelector)s}))', 'short', 'health'),
      nodes: csig('Nodes', 'sum(elasticsearch_cluster_health_number_of_nodes{%(queriesSelector)s})', 'short', 'nodes'),
      dataNodes: csig('Data nodes', 'sum(elasticsearch_cluster_health_number_of_data_nodes{%(queriesSelector)s})', 'short', 'data nodes'),
      pendingTasks: csig('Pending tasks', 'sum(elasticsearch_cluster_health_number_of_pending_tasks{%(queriesSelector)s})', 'short', 'pending tasks'),
      unassigned: shards('unassigned', 'unassigned'),
      documents: sig('Documents', 'sum(elasticsearch_indices_docs{%(queriesSelector)s})', 'short', 'documents'),
      // shards
      active: shards('active', 'active'),
      activePrimary: shards('active_primary', 'active primary'),
      initializing: shards('initializing', 'initializing'),
      relocating: shards('relocating', 'relocating'),
      delayedUnassigned: shards('delayed_unassigned', 'delayed unassigned'),
      // documents
      docsPerNode: sig('Indexed documents', 'elasticsearch_indices_docs{%(queriesSelector)s}', 'short'),
      indexSize: sig('Index size', 'elasticsearch_indices_store_size_bytes{%(queriesSelector)s}', 'bytes'),
      indexRate: sig('Index rate', 'rate(elasticsearch_indices_indexing_index_total{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      queryRate: sig('Query rate', 'rate(elasticsearch_indices_search_query_total{%(queriesSelector)s}[$__rate_interval])', 'ops'),
      queryLatency: sig('Query latency', 'rate(elasticsearch_indices_search_query_time_seconds{%(queriesSelector)s}[$__rate_interval]) / rate(elasticsearch_indices_search_query_total{%(queriesSelector)s}[$__rate_interval])', 's'),
      // nodes
      heap: sig('Heap used', 'elasticsearch_jvm_memory_used_bytes{area="heap", %(queriesSelector)s} / elasticsearch_jvm_memory_max_bytes{area="heap", %(queriesSelector)s}', 'percentunit'),
      heapAvg: sig('Heap used, 15m average', 'avg_over_time(elasticsearch_jvm_memory_used_bytes{area="heap", %(queriesSelector)s}[15m]) / elasticsearch_jvm_memory_max_bytes{area="heap", %(queriesSelector)s}', 'percentunit'),
      memory: sig('JVM memory used', 'elasticsearch_jvm_memory_used_bytes{%(queriesSelector)s}', 'bytes', '{{name}} {{area}}'),
      gc: sig('GC time', 'rate(elasticsearch_jvm_gc_collection_seconds_sum{%(queriesSelector)s}[$__rate_interval])', 's', '{{name}} {{gc}}'),
      cpu: sig('CPU', 'elasticsearch_process_cpu_percent{%(queriesSelector)s} / 100', 'percentunit'),
      disk: sig('Data disk used', '1 - sum by (name) (elasticsearch_filesystem_data_available_bytes{%(queriesSelector)s}) / sum by (name) (elasticsearch_filesystem_data_size_bytes{%(queriesSelector)s})', 'percentunit'),
      breakers: sig('Circuit breakers tripped', 'sum by (name, breaker) (increase(elasticsearch_breakers_tripped{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{name}} {{breaker}}'),
      // threads & network
      poolActive: sig('Thread pools active', 'sum by (type) (elasticsearch_thread_pool_active_count{%(queriesSelector)s})', 'short', '{{type}}'),
      poolQueue: sig('Thread pool queues', 'sum by (type) (elasticsearch_thread_pool_queue_count{type!="management", %(queriesSelector)s})', 'short', '{{type}}'),
      poolRejections: sig('Thread-pool rejections', 'rate(elasticsearch_thread_pool_rejected_count{%(queriesSelector)s}[$__rate_interval])', 'ops', '{{name}} {{type}}'),
      transportTx: sig('Transport TX', 'rate(elasticsearch_transport_tx_size_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{name}} TX'),
      transportRx: sig('Transport RX', 'rate(elasticsearch_transport_rx_size_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{name}} RX'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 5,
        elements: {
          a_health: signals.health.asStat('Health')
                    + panel.stat.withMappings([{ type: 'value', options: { '2': { text: 'green', color: 'green' }, '1': { text: 'yellow', color: 'yellow' }, '0': { text: 'red', color: 'red' } } }]),
          b_nodes: signals.nodes.asStat('Nodes'),
          c_dataNodes: signals.dataNodes.asStat('Data nodes'),
          d_pending: signals.pendingTasks.asStat('Pending tasks'),
          e_unassigned: signals.unassigned.asStat('Unassigned shards'),
          f_documents: signals.documents.asStat('Documents'),
        },
      },
      {
        title: 'Shards',
        width: 24,
        height: 8,
        elements: {
          a_shards: signals.active.asTimeSeries('Shards')
                    + panel.withTargetsMixin([s.asTarget() for s in [signals.activePrimary, signals.initializing, signals.relocating, signals.unassigned, signals.delayedUnassigned]]),
        },
      },
      {
        title: 'Documents',
        width: 12,
        height: 7,
        elements: {
          a_docs: signals.docsPerNode.asTimeSeries('Indexed documents'),
          b_size: signals.indexSize.asTimeSeries('Index size'),
          c_index: signals.indexRate.asTimeSeries('Index rate'),
          d_query: signals.queryRate.asTimeSeries('Query rate'),
          e_latency: signals.queryLatency.asTimeSeries('Query latency'),
        },
      },
      {
        title: 'Nodes',
        width: 12,
        height: 7,
        elements: {
          a_heap: signals.heap.asTimeSeries('JVM heap used'),
          b_heapAvg: signals.heapAvg.asTimeSeries('JVM heap used, 15m average'),
          c_memory: signals.memory.asTimeSeries('JVM memory used by area'),
          d_gc: signals.gc.asTimeSeries('GC time'),
          e_cpu: signals.cpu.asTimeSeries('CPU'),
          f_disk: signals.disk.asTimeSeries('Data disk used'),
          g_breakers: signals.breakers.asTimeSeries('Circuit breakers tripped'),
        },
      },
      {
        title: 'Threads & network',
        width: 12,
        height: 7,
        elements: {
          a_active: signals.poolActive.asTimeSeries('Thread pools active'),
          b_queue: signals.poolQueue.asTimeSeries('Thread pool queues'),
          c_rejections: signals.poolRejections.asTimeSeries('Thread-pool rejections'),
          d_transport: signals.transportTx.asTimeSeries('Transport rate')
                       + panel.withTargetsMixin([signals.transportRx.asTarget()]),
        },
      },
    ], [
      alert.rule.group('elasticsearch', [
        alert.rule.new(
          'ElasticsearchDown',
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('elasticsearch_cluster_health_number_of_nodes', cfg.ruleSelector),
          '5m',
          'critical',
          {},
          { summary: 'The Elasticsearch exporter is down.', description: 'elasticsearch_exporter {{ $labels.instance }} has disappeared from target discovery - Elasticsearch is not monitored.' }
        ),
        alert.rule.new(
          'ElasticsearchClusterRed',
          'elasticsearch_cluster_health_status{color="red"' + rsComma + '} == 1',
          '5m',
          'critical',
          {},
          { summary: 'Elasticsearch cluster health is red.', description: 'Elasticsearch in {{ $labels.cluster }} is red: a primary shard is unassigned, some data cannot be searched or written.' }
        ),
        alert.rule.new(
          'ElasticsearchClusterYellow',
          'elasticsearch_cluster_health_status{color="yellow"' + rsComma + '} == 1',
          '20m',
          'warning',
          {},
          { summary: 'Elasticsearch cluster health is yellow.', description: 'Elasticsearch in {{ $labels.cluster }} is yellow: replica shards are unassigned, one more lost node can lose data.' }
        ),
        alert.rule.new(
          'ElasticsearchTooFewNodesRunning',
          'elasticsearch_cluster_health_number_of_nodes' + rs + ' < ' + cfg.minNodes,
          '5m',
          'critical',
          {},
          { summary: 'Elasticsearch runs on fewer nodes than expected.', description: 'Elasticsearch in {{ $labels.cluster }} runs {{ $value }} nodes, fewer than ' + cfg.minNodes + '.' }
        ),
        alert.rule.new(
          'ElasticsearchHeapTooHigh',
          'elasticsearch_jvm_memory_used_bytes{area="heap"' + rsComma + '} / elasticsearch_jvm_memory_max_bytes{area="heap"' + rsComma + '} > ' + cfg.heapRatio,
          '15m',
          'critical',
          {},
          { summary: 'An Elasticsearch node runs out of heap.', description: 'Node {{ $labels.name }} has used {{ $value | humanizePercentage }} of its JVM heap for 15 minutes.' }
        ),
        alert.rule.new(
          'ElasticsearchDiskSpaceLow',
          'elasticsearch_filesystem_data_available_bytes' + rs + ' / elasticsearch_filesystem_data_size_bytes' + rs + ' < ' + cfg.diskAvailableRatio,
          '15m',
          'warning',
          {},
          { summary: 'An Elasticsearch data disk is filling up.', description: 'Node {{ $labels.name }} has {{ $value | humanizePercentage }} of {{ $labels.path }} free - at the disk watermarks Elasticsearch stops allocating shards to it, then makes its indices read-only.' }
        ),
        alert.rule.new(
          'ElasticsearchThreadPoolRejections',
          'sum by (cluster, name, type) (increase(elasticsearch_thread_pool_rejected_count' + rs + '[5m])) > 0',
          '10m',
          'warning',
          {},
          { summary: 'Elasticsearch rejects work.', description: 'Node {{ $labels.name }} rejects {{ $labels.type }} tasks - that thread pool and its queue are full.' }
        ),
      ]),
    ]),
}
