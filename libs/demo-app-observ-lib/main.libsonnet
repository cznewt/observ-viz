// observ-viz demo-app pack (hand-written).
// The online store the demo-apps chart (oci://ghcr.io/cznewt/charts/demo-apps)
// runs per release: the metrics generator's storefront traffic under the
// OpenTelemetry HTTP names (http_server_request_duration_seconds,
// http_server_active_requests) - the same for every language - plus the business
// metrics of the metrics app the release runs: checkout_* from the Python app,
// inventory_* from the Go and Rust apps. One release per namespace, so every
// rule aggregates by namespace.
// The monitoring course's running example. Its generators open an incident
// window (error ratio 0.5, latency x5) on a schedule or on demand; the storefront
// alerts are sized so one incident fires them: the error ratio and p95 against
// fixed thresholds, and DemoAppErrorRatioAnomalous against the ratio's own
// median of the last hour. The business ratios stay at the apps' fixed 8 %.
// Usage:
//   g.libs.demos.demoApp.new({ selector: 'job=~"$job", namespace=~"$namespace"', ruleSelector: 'namespace="lab-test"' })
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local rule = import 'libs/common-lib/alert/rule.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-demo-app',
      dashboardTitle: 'Online store (demo app)',
      primaryTabTitle: 'Storefront',
      // Workloads / Demos
      folderPath: (import 'libs/common-lib/folders.libsonnet').demos,
      dashboardTags: ['demo-apps', 'red', 'app-level'],
      description: 'The demo-apps online store, one release per namespace: storefront rate, errors and duration from the traffic generator, and the business metrics of the checkout (Python) or inventory (Go, Rust) app.',
      docTabs: true,
      datasource: '${datasource}',
      // the cluster collector labels annotation-scraped pods job="annotation_autodiscovery..."; a
      // student Alloy picks its own job name - the $job variable takes either
      selector: 'job=~"$job", namespace=~"$namespace"',
      varMetric: 'http_server_request_duration_seconds_count',
      varLabels: ['namespace'],
      // spliced into every rule: the tenant may hold several scrapes of the same app
      ruleSelector: '',
      errorRatio: 0.2,
      p95Seconds: 0.5,
      // DemoAppErrorRatioAnomalous: this many times the last hour's median ratio,
      // the median never taken below the floor, and only above minRequests req/s
      anomalyFactor: 4,
      anomalyFloor: 0.01,
      minRequests: 1,
      'for': '2m',
      declineRatio: 0.2,
      reserveFailRatio: 0.2,
      businessFor: '15m',
    } + config;

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    // thresholds as written, not as a float prints (0.2, not 0.20000000000000001)
    local num(x) = std.format('%g', x);
    local rc = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, legend='{{namespace}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);
    local http = 'http_server_request_duration_seconds';
    local ratio5xx(by) =
      'sum by (' + by + ') (rate(' + http + '_count{%(queriesSelector)s, http_response_status_code=~"5.."}[$__rate_interval])) / clamp_min(sum by (' + by + ') (rate(' + http + '_count{%(queriesSelector)s}[$__rate_interval])), 0.001)';

    local signals = {
      // storefront: the metrics generator
      rps: sig('Requests', 'sum by (namespace) (rate(' + http + '_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', desc='Storefront requests per second.'),
      errorRatio: sig('Error ratio', ratio5xx('namespace'), 'percentunit', desc='Share of storefront requests answered with a 5xx. About 5 % normally, half of them during an incident.'),
      // the baseline DemoAppErrorRatioAnomalous compares against, computed in place so the board works without the recording rules
      errorRatioMedian: sig('Error ratio, median of the last hour', 'quantile_over_time(0.5, (' + ratio5xx('namespace') + ')[1h:1m])', 'percentunit', '{{namespace}} median 1h', desc='Median of the error ratio over the last hour: the baseline of the anomaly alert.'),
      p50: sig('Duration p50', 'histogram_quantile(0.50, sum by (namespace, le) (rate(' + http + '_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{namespace}} p50', desc='Median storefront request duration.'),
      p95: sig('Duration p95', 'histogram_quantile(0.95, sum by (namespace, le) (rate(' + http + '_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{namespace}} p95', desc='Slowest 5 percent of storefront requests. Five times longer during an incident.'),
      p99: sig('Duration p99', 'histogram_quantile(0.99, sum by (namespace, le) (rate(' + http + '_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{namespace}} p99', desc='Slowest 1 percent of storefront requests.'),
      byStatus: sig('Requests by status', 'sum by (http_response_status_code) (rate(' + http + '_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{http_response_status_code}}', desc='Storefront requests per second by response status.'),
      byRoute: sig('Requests by route', 'sum by (http_route) (rate(' + http + '_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{http_route}}', desc='Storefront requests per second by route.'),
      p95ByRoute: sig('Duration p95 by route', 'histogram_quantile(0.95, sum by (http_route, le) (rate(' + http + '_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{http_route}}', desc='Slowest 5 percent per route.'),
      active: sig('Active requests', 'sum by (namespace) (http_server_active_requests{%(queriesSelector)s})', 'short', desc='Requests in progress. 0 to 3 normally, up to 12 during an incident.'),
      // checkout: the Python metrics app
      checkoutRate: sig('Transactions', 'sum by (status) (rate(checkout_transactions_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{status}}', desc='Checkout transactions per second, success and declined.'),
      checkoutByMethod: sig('Transactions by payment method', 'sum by (payment_method) (rate(checkout_transactions_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{payment_method}}', desc='Checkout transactions per second by payment method.'),
      declineRatio: sig('Decline ratio', 'sum by (namespace) (rate(checkout_transactions_total{%(queriesSelector)s, status="declined"}[$__rate_interval])) / clamp_min(sum by (namespace) (rate(checkout_transactions_total{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'percentunit', desc='Share of checkout transactions declined - a fixed 8 % in the demo app.'),
      paymentP95: sig('Payment duration p95', 'histogram_quantile(0.95, sum by (payment_method, le) (rate(checkout_payment_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{payment_method}} p95', desc='Slowest 5 percent of payments per method. Declined payments take the longest.'),
      paymentP50: sig('Payment duration p50', 'histogram_quantile(0.50, sum by (le) (rate(checkout_payment_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', 'p50', desc='Median payment duration.'),
      queueDepth: sig('Queue depth', 'sum by (namespace) (checkout_queue_depth{%(queriesSelector)s})', 'short', desc='The checkout queue. It only grows until the pod restarts - a gauge that drifts, not one to alert on.'),
      // inventory: the Go and Rust metrics apps
      inventoryRate: sig('Reservations', 'sum by (warehouse, operation) (rate(inventory_updates_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{warehouse}} {{operation}}', desc='Stock reservations per second by warehouse, successful and failed.'),
      reserveFailRatio: sig('Reservation failure ratio', 'sum by (namespace) (rate(inventory_updates_total{%(queriesSelector)s, operation="reserve_failed"}[$__rate_interval])) / clamp_min(sum by (namespace) (rate(inventory_updates_total{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'percentunit', desc='Share of stock reservations that failed - a fixed 8 % in the demo app.'),
      reservationP95: sig('Reservation duration p95', 'histogram_quantile(0.95, sum by (namespace, le) (rate(inventory_reservation_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{namespace}} p95', desc='Slowest 5 percent of reservations. Failed ones take ten times longer.'),
      stockLevel: sig('Stock level', 'sum by (namespace) (inventory_stock_level{%(queriesSelector)s})', 'short', desc='Units in stock. Grows for as long as the app runs.'),
      pendingShipments: sig('Pending shipments', 'sum by (namespace) (inventory_pending_shipments{%(queriesSelector)s})', 'short', desc='Shipments waiting - a random walk that can go below zero.'),
    };

    local stat(s, title) = s.asStat(title);
    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 6,
        height: 4,
        elements: {
          a_rps: stat(signals.rps, 'Requests/s'),
          b_errors: stat(signals.errorRatio, 'Error ratio') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.1 }, { color: 'red', value: cfg.errorRatio }]),
          c_p95: stat(signals.p95, 'Duration p95') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: cfg.p95Seconds }]),
          d_active: stat(signals.active, 'Active requests'),
        },
      },
      {
        title: 'Rate, errors, duration',
        width: 12,
        height: 8,
        elements: {
          a_status: signals.byStatus.asTimeSeries('Requests/s by status'),
          b_errors: signals.errorRatio.asTimeSeries('Error ratio against its last hour')
                    + panel.withTargetsMixin([signals.errorRatioMedian.asTarget()]),
          c_duration: signals.p50.asTimeSeries('Duration p50 / p95 / p99')
                      + panel.withTargetsMixin([signals.p95.asTarget(), signals.p99.asTarget()]),
          d_active: signals.active.asTimeSeries('Active requests'),
        },
      },
      {
        title: 'Routes',
        width: 12,
        height: 8,
        elements: {
          a_routes: signals.byRoute.asTimeSeries('Requests/s by route'),
          b_routes: signals.p95ByRoute.asTimeSeries('Duration p95 by route'),
        },
      },
    ], [
      alert.rule.group('demo-app', [
        alert.rule.new(
          'DemoAppDown',
          rule.targetDown(http + '_count', cfg.ruleSelector),
          '2m',
          'critical',
          {},
          { summary: 'The demo app metrics endpoint {{ $labels.instance }} is down.', description: 'The storefront metrics of {{ $labels.namespace }} have not been scraped for two minutes - the generator is gone or its Service has no endpoints.' }
        ),
        alert.rule.new(
          'DemoAppErrorRatioHigh',
          'namespace:demo_http_errors:ratio_rate5m > ' + num(cfg.errorRatio),
          cfg['for'],
          'critical',
          {},
          { summary: 'The storefront in {{ $labels.namespace }} fails {{ $value | humanizePercentage }} of its requests.', description: 'More than ' + num(cfg.errorRatio * 100) + ' % of storefront requests in {{ $labels.namespace }} end with a 5xx.' }
        ),
        alert.rule.new(
          'DemoAppLatencyHigh',
          'namespace:demo_http_request_duration_seconds:p95_rate5m > ' + num(cfg.p95Seconds),
          cfg['for'],
          'warning',
          {},
          { summary: 'The storefront in {{ $labels.namespace }} is slow: p95 {{ $value | humanizeDuration }}.', description: 'The slowest 5 % of storefront requests in {{ $labels.namespace }} take longer than ' + num(cfg.p95Seconds) + ' s.' }
        ),
        alert.rule.new(
          'DemoAppErrorRatioAnomalous',
          'namespace:demo_http_errors:ratio_rate5m > ' + num(cfg.anomalyFactor) + ' * clamp_min(namespace:demo_http_errors_ratio_rate5m:median1h, ' + num(cfg.anomalyFloor) + ')'
          + ' and namespace:demo_http_requests:rate5m > ' + num(cfg.minRequests),
          cfg['for'],
          'warning',
          {},
          { summary: 'The storefront error ratio in {{ $labels.namespace }} left its baseline.', description: 'The error ratio of {{ $labels.namespace }}, {{ $value | humanizePercentage }}, is more than ' + num(cfg.anomalyFactor) + ' times its median of the last hour. A lasting change becomes the new median within the hour and the alert resolves itself.' }
        ),
        alert.rule.new(
          'DemoCheckoutDeclineRatioHigh',
          'namespace:checkout_transactions_declined:ratio_rate5m > ' + num(cfg.declineRatio),
          cfg.businessFor,
          'warning',
          {},
          { summary: 'Checkout in {{ $labels.namespace }} declines {{ $value | humanizePercentage }} of transactions.' }
        ),
        alert.rule.new(
          'DemoInventoryReservationFailuresHigh',
          'namespace:inventory_reservations_failed:ratio_rate5m > ' + num(cfg.reserveFailRatio),
          cfg.businessFor,
          'warning',
          {},
          { summary: 'Inventory in {{ $labels.namespace }} fails {{ $value | humanizePercentage }} of stock reservations.' }
        ),
      ]),
    ], [
      rule.group('demo-app.rules', [
        rule.record('namespace:demo_http_requests:rate5m', 'sum by (namespace) (rate(' + http + '_count' + rs + '[5m]))'),
        rule.record('namespace:demo_http_errors:ratio_rate5m', 'sum by (namespace) (rate(' + http + '_count{http_response_status_code=~"5.."' + rc + '}[5m])) / sum by (namespace) (rate(' + http + '_count' + rs + '[5m]))'),
        rule.record('namespace:demo_http_errors_ratio_rate5m:median1h', 'quantile_over_time(0.5, namespace:demo_http_errors:ratio_rate5m[1h])'),
        rule.record('namespace:demo_http_request_duration_seconds:p95_rate5m', 'histogram_quantile(0.95, sum by (namespace, le) (rate(' + http + '_bucket' + rs + '[5m])))'),
        rule.record('namespace:checkout_transactions_declined:ratio_rate5m', 'sum by (namespace) (rate(checkout_transactions_total{status="declined"' + rc + '}[5m])) / sum by (namespace) (rate(checkout_transactions_total' + rs + '[5m]))'),
        rule.record('namespace:checkout_payment_duration_seconds:p95_rate5m', 'histogram_quantile(0.95, sum by (namespace, le) (rate(checkout_payment_duration_seconds_bucket' + rs + '[5m])))'),
        rule.record('namespace:inventory_reservations_failed:ratio_rate5m', 'sum by (namespace) (rate(inventory_updates_total{operation="reserve_failed"' + rc + '}[5m])) / sum by (namespace) (rate(inventory_updates_total' + rs + '[5m]))'),
        rule.record('namespace:inventory_reservation_duration_seconds:p95_rate5m', 'histogram_quantile(0.95, sum by (namespace, le) (rate(inventory_reservation_duration_seconds_bucket' + rs + '[5m])))'),
      ]),
    ], [
      {
        title: 'Checkout (Python)',
        width: 12,
        height: 8,
        elements: {
          co_a_rate: signals.checkoutRate.asTimeSeries('Transactions/s by status'),
          co_b_decline: signals.declineRatio.asTimeSeries('Decline ratio'),
          co_c_method: signals.checkoutByMethod.asTimeSeries('Transactions/s by payment method'),
          co_d_duration: signals.paymentP95.asTimeSeries('Payment duration p95 by method')
                         + panel.withTargetsMixin([signals.paymentP50.asTarget()]),
          co_e_queue: signals.queueDepth.asTimeSeries('Queue depth (unbounded)'),
        },
      },
      {
        title: 'Inventory (Go, Rust)',
        width: 12,
        height: 8,
        elements: {
          in_a_rate: signals.inventoryRate.asTimeSeries('Reservations/s by warehouse'),
          in_b_fail: signals.reserveFailRatio.asTimeSeries('Reservation failure ratio'),
          in_c_duration: signals.reservationP95.asTimeSeries('Reservation duration p95'),
          in_d_stock: signals.stockLevel.asTimeSeries('Stock level (drifts)'),
          in_e_pending: signals.pendingShipments.asTimeSeries('Pending shipments (random walk)'),
        },
      },
    ]),
}
