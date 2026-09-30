// observ-viz statsd_exporter pack (hand-written).
// prometheus/statsd_exporter reporting on itself: what arrives (UDP / TCP /
// Unixgram packets, lines, samples, events by type), how the mapping config
// treats it (loaded mappings, unmapped and conflicting events, reloads),
// what goes wrong while parsing, and how many metrics it ends up exporting.
// The re-exported application metrics are not this board's business.
//
//   g.libs.monitoring.statsdExporter.new({}).grafana.dashboard
//
// Metric names checked against statsd_exporter main.go (master, 2026-09).
// There is no statsd_exporter_packets_total: packets are counted per
// listener (udp / unixgram), TCP per connection.
local dashboard = import 'custom/dashboard.libsonnet';
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-statsd-exporter',
      dashboardTitle: 'StatsD exporter',
      dashboardTags: ['statsd-exporter', 'statsd', 'collector', 'cluster-level'],
      description: 'statsd_exporter on itself: packets, lines, samples and events it receives, how the mapping config handles them (unmapped, conflicting, reloads), parse and connection errors, and the number of metrics it exports.',
      references: [
        { title: 'statsd_exporter', url: 'https://github.com/prometheus/statsd_exporter', description: 'mapping config, listeners and the exporter\'s own metrics' },
        { title: 'Metric mapping', url: 'https://github.com/prometheus/statsd_exporter#metric-mapping-and-configuration', description: 'glob / regex mappings, match_metric_type, action: drop' },
      ],
      datasource: '${datasource}',
      selector: 'cluster=~"$cluster", job=~"$job", instance=~"$instance"',
      varLabels: ['cluster', 'instance'],
      varMetric: 'statsd_exporter_build_info',
      alertSelector: 'cluster=~"$cluster", job=~"$job"',
      ruleSelector: '',
      // unmapped events per second worth a warning (0 = any)
      unmappedEventsPerSecond: 0,
      docTabs: true,
      tabbed: true,
      overviewSignals: ['events', 'unmapped', 'mappings', 'metrics', 'errors'],
      folderPath: (import 'libs/common-lib/folders.libsonnet').monitoringCollectors,
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local q(metric, extra='') = metric + '{%(queriesSelector)s' + extra + '}';
    local rate(metric, extra='') = 'rate(' + q(metric, extra) + '[$__rate_interval])';
    local byInst(m, extra='') = 'sum by (instance) (' + rate(m, extra) + ')';

    local signals = {
      // ---- overview (per instance)
      events: sig('Events', byInst('statsd_exporter_events_total'), 'ops', '{{instance}}', 'StatsD events (counter / gauge / observer samples) processed per second.'),
      unmapped: sig('Unmapped events', byInst('statsd_exporter_events_unmapped_total'), 'ops', '{{instance}}',
                    'Events no mapping matched; they are exported under an auto-generated name (or dropped with a default drop action).'),
      mappings: sig('Loaded mappings', 'max by (instance) (' + q('statsd_exporter_loaded_mappings') + ')', 'short', '{{instance}}', 'Mappings in the currently loaded config.'),
      metrics: sig('Exported metrics', 'sum by (instance) (' + q('statsd_exporter_metrics_total') + ')', 'short', '{{instance}}', 'Metrics the exporter currently exposes to Prometheus.'),
      errors: sig('Errors', '(' + byInst('statsd_exporter_sample_errors_total') + ') + (' + byInst('statsd_exporter_tag_errors_total') + ' or vector(0))', 'ops', '{{instance}}',
                  'Sample parse errors plus DogStatsD tag errors per second.'),
      // ---- ingest
      udpPackets: sig('UDP packets', byInst('statsd_exporter_udp_packets_total'), 'pps', 'udp {{instance}}', 'StatsD packets received over UDP.'),
      udpDrops: sig('UDP packet drops', byInst('statsd_exporter_udp_packet_drops_total'), 'pps', 'dropped {{instance}}', 'UDP packets dropped because the event queue was full.'),
      unixgramPackets: sig('Unixgram packets', byInst('statsd_exporter_unixgram_packets_total'), 'pps', 'unixgram {{instance}}', 'StatsD packets received over the Unix datagram socket.'),
      tcpConnections: sig('TCP connections', byInst('statsd_exporter_tcp_connections_total'), 'ops', '{{instance}}', 'TCP connections handled per second.'),
      lines: sig('Lines', byInst('statsd_exporter_lines_total'), 'ops', 'lines {{instance}}', 'StatsD lines received (one packet can carry many).'),
      samples: sig('Samples', byInst('statsd_exporter_samples_total'), 'ops', 'samples {{instance}}', 'Samples parsed from the lines (a line with multiple values yields several).'),
      eventsByType: sig('Events by type', 'sum by (type) (' + rate('statsd_exporter_events_total') + ')', 'ops', '{{type}}', 'Events per second by type: counter, gauge, observer.'),
      tags: sig('Tags', byInst('statsd_exporter_tags_total'), 'ops', '{{instance}}', 'DogStatsD / InfluxDB / Librato / SignalFX tags processed per second.'),
      flushes: sig('Event queue flushes', byInst('statsd_exporter_event_queue_flushed_total'), 'ops', '{{instance}}',
                   'How often the event queue was flushed to the exporter (on size or interval).'),
      // ---- mapping
      unmappedSeries: sig('Unmapped events', byInst('statsd_exporter_events_unmapped_total'), 'ops', '{{instance}}', 'Events without a matching mapping, per second.'),
      conflicts: sig('Conflicting events', 'topk(10, sum by (type, metric_name) (' + rate('statsd_exporter_events_conflict_total') + '))', 'ops', '{{metric_name}} ({{type}})',
                     'Events dropped because the mapped name is already registered with another type or label set - the ten worst names.'),
      actions: sig('Events by action', 'sum by (action) (' + rate('statsd_exporter_events_actions_total') + ')', 'ops', '{{action}}', 'Events per mapping action (map, drop).'),
      reloads: sig('Config reloads', 'sum by (outcome) (increase(' + q('statsd_exporter_config_reloads_total') + '[$__rate_interval]))', 'short', '{{outcome}}',
                   'Mapping config reloads by outcome (success / failure).'),
      mappingsSeries: sig('Loaded mappings', 'max by (instance) (' + q('statsd_exporter_loaded_mappings') + ')', 'short', '{{instance}}', 'Mappings loaded per instance.'),
      // ---- errors
      sampleErrors: sig('Sample errors by reason', 'sum by (reason) (' + rate('statsd_exporter_sample_errors_total') + ')', 'ops', '{{reason}}',
                        'Lines or samples that could not be parsed, by reason (malformed_line, illegal_sample_value, ...).'),
      eventErrors: sig('Event errors by reason', 'sum by (reason) (' + rate('statsd_exporter_events_error_total') + ')', 'ops', '{{reason}}',
                       'Events discarded while being turned into metrics, by reason.'),
      tagErrors: sig('Tag errors', byInst('statsd_exporter_tag_errors_total'), 'ops', 'tags {{instance}}', 'DogStatsD tags that could not be parsed.'),
      tcpErrors: sig('TCP connection errors', byInst('statsd_exporter_tcp_connection_errors_total'), 'ops', 'tcp errors {{instance}}', 'Errors reading from TCP connections.'),
      tcpTooLong: sig('TCP lines too long', byInst('statsd_exporter_tcp_too_long_lines_total'), 'ops', 'too long {{instance}}', 'TCP lines discarded for exceeding the line length limit.'),
      // ---- output
      metricsByType: sig('Metrics by type', 'sum by (type) (' + q('statsd_exporter_metrics_total') + ')', 'short', '{{type}}', 'Exported metrics by type (counter, gauge, summary, histogram).'),
      version: sig('Version', 'max by (instance, version) (' + q('statsd_exporter_build_info') + ')', 'short', '{{instance}} {{version}}', 'Running statsd_exporter builds.'),
    };
    local redAbove0 = panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.001 }])
                      + panel.timeSeries.withFieldConfigDefaults({ custom+: { thresholdsStyle: { mode: 'dashed' } } });

    local annList =
      annotations.alert.bySeverity(cfg.datasource, cfg.alertSelector + ', alertname=~"StatsdExporter.*"')
      + [
        annotations.restart.newAt('statsd_exporter starts', annotations.restart.processStart(cfg.datasource, cfg.selector), ['job', 'instance'], '{{instance}} started')
        + annotations.base.asToggle(false),
      ];

    local built = pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          ov1_events: signals.events.asStat('Events/s'),
          ov2_unmapped: signals.unmapped.asStat('Unmapped/s')
                        + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.001 }]),
          ov3_mappings: signals.mappings.asStat('Loaded mappings'),
          ov4_metrics: signals.metrics.asStat('Exported metrics'),
          ov5_errors: signals.errors.asStat('Errors/s')
                      + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 0.001 }]),
        },
      },
      {
        title: 'Ingest',
        width: 12,
        height: 7,
        signalKeys: ['udpPackets', 'udpDrops', 'unixgramPackets', 'tcpConnections', 'lines', 'samples', 'eventsByType', 'tags', 'flushes'],
        elements: {
          in1_packets: signals.udpPackets.asTimeSeries('Packets/s (UDP, Unixgram, dropped)')
                       + panel.withTargetsMixin([signals.unixgramPackets.asTarget(), signals.udpDrops.asTarget()]),
          in2_lines: signals.lines.asTimeSeries('Lines and samples/s')
                     + panel.withTargetsMixin([signals.samples.asTarget()]),
          in3_eventsByType: signals.eventsByType.asTimeSeries('Events/s by type'),
          in4_tcp: signals.tcpConnections.asTimeSeries('TCP connections/s'),
          in5_tags: signals.tags.asTimeSeries('Tags/s'),
          in6_flushes: signals.flushes.asTimeSeries('Event queue flushes/s'),
        },
      },
      {
        title: 'Mapping',
        width: 12,
        height: 7,
        elements: {
          mappingsSeries: signals.mappingsSeries.asTimeSeries('Loaded mappings'),
          unmappedSeries: signals.unmappedSeries.asTimeSeries('Unmapped events/s'),
          conflicts: signals.conflicts.asTimeSeries('Conflicting events/s (top 10 names)') + redAbove0,
          actions: signals.actions.asTimeSeries('Events/s by action'),
          reloads: signals.reloads.asTimeSeries('Config reloads by outcome')
                   + panel.timeSeries.withOverrides([{ matcher: { id: 'byName', options: 'failure' }, properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'red' } }] }]),
        },
      },
      {
        title: 'Errors',
        width: 12,
        height: 7,
        signalKeys: ['sampleErrors', 'eventErrors', 'tagErrors', 'tcpErrors', 'tcpTooLong'],
        elements: {
          er1_samples: signals.sampleErrors.asTimeSeries('Sample errors/s by reason') + redAbove0,
          er2_events: signals.eventErrors.asTimeSeries('Event errors/s by reason') + redAbove0,
          er3_tags_tcp: signals.tagErrors.asTimeSeries('Tag / TCP errors/s')
                        + panel.withTargetsMixin([signals.tcpErrors.asTarget(), signals.tcpTooLong.asTarget()])
                        + redAbove0,
        },
      },
      {
        title: 'Output',
        width: 12,
        height: 7,
        elements: {
          metricsByType: signals.metricsByType.asTimeSeries('Exported metrics by type'),
          version: signals.version.asTable('Version')
                   + panel.table.withTransformations([
                     { id: 'organize', options: { excludeByName: { Time: true, Value: true } } },
                   ]),
        },
      },
    ], [
      alert.rule.group('statsd-exporter', [
        alert.rule.new(
          'StatsdExporterDown',
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('statsd_exporter_build_info', cfg.ruleSelector),
          '5m',
          'warning',
          {},
          {
            summary: 'statsd_exporter {{ $labels.instance }} is down.',
            description: 'Prometheus cannot scrape the exporter. StatsD is fire-and-forget over UDP, so the applications keep sending and every metric they send is lost.',
          }
        ),
        alert.rule.new(
          'StatsdExporterUnmappedEvents',
          'sum by (cluster, job, instance) (rate(statsd_exporter_events_unmapped_total' + rsBrace + '[5m])) > ' + cfg.unmappedEventsPerSecond,
          '15m',
          'warning',
          {},
          {
            summary: 'statsd_exporter {{ $labels.instance }} receives events no mapping matches.',
            description: '{{ $value | humanize }} unmapped events/s. They are exported under auto-generated names, which grows cardinality and misses the labels a mapping would extract. Add a mapping, or a drop rule.',
          }
        ),
        alert.rule.new(
          'StatsdExporterConfigReloadFailed',
          'sum by (cluster, job, instance) (increase(statsd_exporter_config_reloads_total{outcome="failure"' + rsComma + '}[15m])) > 0',
          '1m',
          'warning',
          {},
          {
            summary: 'statsd_exporter {{ $labels.instance }} failed to reload its mapping config.',
            description: 'The exporter keeps the previous mappings, so the change that was meant to apply is not in effect. The exporter log names the parse error.',
          }
        ),
        alert.rule.new(
          'StatsdExporterEventConflicts',
          'sum by (cluster, job, instance) (rate(statsd_exporter_events_conflict_total' + rsBrace + '[5m])) > 0',
          '10m',
          'warning',
          {},
          {
            summary: 'statsd_exporter {{ $labels.instance }} drops events with conflicting names.',
            description: 'Events map to a metric name already registered with a different type or label set, and are discarded. The Mapping tab lists the metric names.',
          }
        ),
      ]),
    ], [
      alert.rule.group('statsd-exporter.rules', [
        alert.rule.record('instance:statsd_exporter_events:rate5m', 'sum by (cluster, job, instance, type) (rate(statsd_exporter_events_total' + rsBrace + '[5m]))'),
        alert.rule.record('instance:statsd_exporter_events_unmapped:rate5m', 'sum by (cluster, job, instance) (rate(statsd_exporter_events_unmapped_total' + rsBrace + '[5m]))'),
      ]),
    ]);
    built {
      grafana+: { dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList) },
    },
}
