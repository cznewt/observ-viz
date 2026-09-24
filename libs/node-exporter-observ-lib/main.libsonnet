// observ-viz node_exporter pack (hand-written).
// The exporter itself, not the machine it runs on: which collectors answered,
// how long each took, and whether the scrape came back whole. A Linux board
// full of gaps is usually this - a collector erroring out or a scrape timing
// out - and nothing on that board can say so.
//   g.libs.monitoring.nodeExporter.new({})
local alert = import 'libs/common-lib/alert/main.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-node-exporter',
      dashboardTitle: 'Node exporter',
      dashboardTags: ['node-exporter', 'collector', 'node-level'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'node_exporter_build_info',
      varLabels: ['instance'],
      legendLabels: ['instance'],
      ruleSelector: '',
      docTabs: true,
      tabbed: true,
      overviewSignals: ['scrapeDuration', 'collectorsFailing', 'collectors', 'textfileErrors'],
      description: 'node_exporter reporting on itself: the collectors it ran, what each cost, and whether the scrape completed. When a Linux board has holes in it, the reason is here.',
      references: [
        { title: 'node_exporter', url: 'https://github.com/prometheus/node_exporter', description: 'the collectors and how to enable or disable them' },
        { title: 'Textfile collector', url: 'https://github.com/prometheus/node_exporter#textfile-collector', description: 'what node_textfile_scrape_error means' },
      ],
      folderUid: 'components-monitoring',
      folderTitle: 'Monitoring',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local sig = filters.sig(cfg);

    local signals = {
      // per-collector: the two numbers that explain a missing metric
      collectorDuration: sig('Collector duration', 'node_scrape_collector_duration_seconds{%(queriesSelector)s}', 's',
                             'How long each collector took on the last scrape. One slow collector delays the whole response.'),
      collectorSuccess: sig('Collector success', 'node_scrape_collector_success{%(queriesSelector)s}', 'short',
                            '1 when the collector answered, 0 when it errored. A zero here is why a panel elsewhere is empty.'),
      collectorsFailing: sig('Collectors failing', 'count by (instance) (node_scrape_collector_success{%(queriesSelector)s} == 0) or vector(0)', 'short',
                             'How many collectors are erroring on each host.'),
      collectors: sig('Collectors enabled', 'count by (instance) (node_scrape_collector_success{%(queriesSelector)s})', 'short',
                      'How many collectors the exporter is running at all.'),
      scrapeDuration: sig('Scrape duration', 'sum by (instance) (node_scrape_collector_duration_seconds{%(queriesSelector)s})', 's',
                          'The sum of every collector, which is roughly what a scrape costs. Past the scrape timeout the target goes down and every metric disappears at once.'),
      textfileErrors: sig('Textfile errors', 'node_textfile_scrape_error{%(queriesSelector)s}', 'short',
                          'Non-zero when a .prom file in the textfile directory could not be parsed - usually a half-written file with no atomic rename.'),
      version: sig('Version', 'node_exporter_build_info{%(queriesSelector)s}', 'short',
                   'Which build is running where. Collector behaviour changes between versions more often than the metric names do.'),
      handlerRequests: sig('Scrapes served', 'rate(promhttp_metric_handler_requests_total{%(queriesSelector)s}[$__rate_interval])', 'reqps',
                           'Requests the exporter answered per second, by status.'),
      handlerErrors: sig('Scrape errors', 'rate(promhttp_metric_handler_errors_total{%(queriesSelector)s}[$__rate_interval])', 'ops',
                         'Errors while gathering, which is the exporter failing rather than the target being unreachable.'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Scrape',
        width: 12,
        height: 7,
        elements: {
          scrapeDuration: signals.scrapeDuration.asTimeSeries('Scrape duration'),
          collectorsFailing: signals.collectorsFailing.asTimeSeries('Collectors failing')
                             + panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }])
                             + panel.timeSeries.withFieldConfigDefaults({ custom: { thresholdsStyle: { mode: 'dashed' } } }),
          handlerRequests: signals.handlerRequests.asTimeSeries('Scrapes served'),
          handlerErrors: signals.handlerErrors.asTimeSeries('Scrape errors'),
        },
      },
      {
        title: 'Collectors',
        width: 24,
        height: 10,
        elements: {
          collectorDuration: signals.collectorDuration.asTable('Collector duration'),
          collectorSuccess: signals.collectorSuccess.asTable('Collector success'),
        },
      },
      {
        title: 'Exporter',
        width: 12,
        height: 7,
        elements: {
          version: signals.version.asTable('Version'),
          textfileErrors: signals.textfileErrors.asTimeSeries('Textfile errors'),
        },
      },
    ], [
      alert.rule.group('node-exporter', [
        alert.rule.new(
          'NodeExporterCollectorFailing',
          'node_scrape_collector_success' + rsBrace + ' == 0',
          '15m',
          'warning',
          {},
          {
            summary: 'node_exporter collector {{ $labels.collector }} on {{ $labels.instance }} is erroring.',
            description: 'Every metric that collector provides is missing while this lasts, so a board that looks calm may simply have nothing to draw. Check the exporter log for the collector name.',
          }
        ),
        alert.rule.new(
          'NodeExporterTextfileError',
          'node_textfile_scrape_error' + rsBrace + ' == 1',
          '15m',
          'warning',
          {},
          {
            summary: 'node_exporter cannot parse a textfile on {{ $labels.instance }}.',
            description: 'A .prom file in the textfile directory is malformed, usually because a writer was interrupted. Write to a temporary file and rename it into place.',
          }
        ),
      ]),
    ]),
}
