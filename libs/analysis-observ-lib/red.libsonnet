// observ-viz RED method (hand-written).
// Rate, Errors, Duration for any instrumentation: point it at a source profile
// (libs/analysis-observ-lib/sources.libsonnet) and it builds the same two
// panels - requests split into successes and errors over time, and the p50/p95
// /p99 of the latency histogram - plus a breakdown per route, ingress, view or
// whatever dimension the source groups by.
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  // new({ source: <profile>, ... }) -> a pack
  new(config={}):
    local cfg = {
      uid: 'observ-viz-red',
      dashboardTitle: 'RED method',
      dashboardTags: ['observ-viz', 'analysis', 'red'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varLabels: [],
      legendLabels: [],
      tabbed: true,
    } + config;
    local src = cfg.source;
    local by = std.join(', ', src.groupBy);
    local sel = filters.selector(cfg);
    local sig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit)
      .filteringSelector(sel).withLegendFormat(legend).withDescription(desc);

    // failures are either a label on the request counter or a counter of their own
    local errExpr =
      if std.objectHas(src, 'errorCounter')
      then 'sum by (' + by + ') (rate(' + src.errorCounter + '{%(queriesSelector)s}[$__rate_interval]))'
      else 'sum by (' + by + ') (rate(' + src.counter + '{%(queriesSelector)s, ' + src.errorSelector + '}[$__rate_interval]))';
    local totalExpr = 'sum by (' + by + ') (rate(' + src.counter + '{%(queriesSelector)s}[$__rate_interval]))';
    local quantile(q) =
      'histogram_quantile(' + q + ', sum by (le, ' + by + ') (rate(' + src.bucket + '{%(queriesSelector)s}[$__rate_interval])))';
    local legendBy = std.join(' / ', ['{{' + l + '}}' for l in src.groupBy]);

    local signals = {
      requests: sig('Requests', totalExpr, 'reqps', legendBy, 'Requests per second.'),
      errors: sig('Errors', errExpr, 'reqps', legendBy, 'Requests per second that failed.'),
      success: sig('Successful', '(' + totalExpr + ') - (' + errExpr + ')', 'reqps', legendBy, 'Requests per second that did not fail.'),
      errorRatio: sig('Error ratio', '(' + errExpr + ') / (' + totalExpr + ')', 'percentunit', legendBy, 'Share of requests that failed.'),
      p50: sig('Duration p50', quantile('0.50'), 's', 'p50 ' + legendBy, 'Median request duration.'),
      p95: sig('Duration p95', quantile('0.95'), 's', 'p95 ' + legendBy, '95th percentile request duration.'),
      p99: sig('Duration p99', quantile('0.99'), 's', 'p99 ' + legendBy, '99th percentile request duration.'),
    };

    // panel 1: the request rate as a stack of successes and errors
    local ratePanel =
      panel.timeSeries.new('Requests: successful and failed')
      + panel.timeSeries.withDescription('Requests per second, stacked: what succeeded and what did not.')
      + panel.timeSeries.withTargets([
        signals.success.asTarget() + { spec+: { query+: { spec+: { legendFormat: 'success ' + legendBy } } } },
        signals.errors.asTarget() + { spec+: { query+: { spec+: { legendFormat: 'error ' + legendBy } } } },
      ])
      + panel.timeSeries.standardOptions.withUnit('reqps')
      + panel.timeSeries.withFieldConfigDefaults({
        custom: { fillOpacity: 35, lineWidth: 1, stacking: { mode: 'normal', group: 'A' }, showPoints: 'never' },
      })
      + panel.timeSeries.withOverrides([
        { matcher: { id: 'byRegexp', options: '^error.*' }, properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'red' } }] },
        { matcher: { id: 'byRegexp', options: '^success.*' }, properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: 'green' } }] },
      ]);

    // panel 2: the three quantiles of the same requests
    local durationPanel =
      panel.timeSeries.new('Duration: p99, p95, p50')
      + panel.timeSeries.withDescription('Request duration from the latency histogram, three quantiles.')
      + panel.timeSeries.withTargets([signals.p99.asTarget(), signals.p95.asTarget(), signals.p50.asTarget()])
      + panel.timeSeries.standardOptions.withUnit('s')
      + panel.timeSeries.withFieldConfigDefaults({ custom: { fillOpacity: 8, lineWidth: 2, showPoints: 'never' } });

    pack.build(cfg + {
      description: 'The RED method over ' + std.asciiLower(src.title) + '. ' + src.description,
      references: [
        { title: 'The RED method', url: 'https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/', description: 'rate, errors, duration - what to measure for a request-driven service' },
        { title: 'Histograms and summaries', url: 'https://prometheus.io/docs/practices/histograms/', description: 'how the quantiles here are computed' },
      ],
      rowLabels: src.groupBy,
      overviewSignals: ['requests', 'errors', 'errorRatio', 'p95', 'p99'],
    }, signals, [
      {
        title: 'RED',
        width: 12,
        height: 9,
        elements: { requests: ratePanel, duration: durationPanel },
      },
      {
        title: 'Errors',
        width: 12,
        height: 8,
        elements: {
          errorRatio: signals.errorRatio.asTimeSeries('Error ratio'),
          errors: signals.errors.asTimeSeries('Failed requests'),
        },
      },
    ]),
}
