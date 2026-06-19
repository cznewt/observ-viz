// observ-viz Alloy pack (hand-written).
// Grafana Alloy internal monitoring (alloy_* metrics), emitted as native v2
// elements. Usage:
//   g.packs.collector.alloy.new({ selector: 'job="alloy"' }).grafana.dashboard
//   g.packs.collector.alloy.new({...}).grafana.elements   // reuse in a board
local pack = import 'packs/_pack.libsonnet';
local signal = import 'signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-alloy',
      dashboardTitle: 'Alloy',
      dashboardTags: ['alloy', 'collector', 'grafana'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'alloy_build_info',
    } + config;

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      running: sig('Running components', 'sum(alloy_component_controller_running_components{%(queriesSelector)s})', 'short'),
      evalP99: sig('Evaluation p99', 'histogram_quantile(0.99, sum by (le)(rate(alloy_component_evaluation_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's'),
      // alloy_component_dependencies_wait_seconds tracks how long a component
      // waits on dependencies before evaluating; keep the alloy_ metric name.
      evalRate: sig('Evaluations', 'sum(rate(alloy_component_evaluation_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      // alloy_component_controller_evaluating reports the controller queue depth.
      controllerQueue: sig('Controller queue', 'sum(alloy_component_controller_evaluating{%(queriesSelector)s})', 'short'),
      // prometheus_remote_write_wal_samples_appended_total is exposed by Alloy's
      // prometheus.remote_write WAL; keep the upstream metric name.
      appended: sig('Samples appended', 'sum(rate(prometheus_remote_write_wal_samples_appended_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      // prometheus_remote_storage_samples_failed_total counts WAL send failures.
      sendFailed: sig('Samples failed', 'sum(rate(prometheus_remote_storage_samples_failed_total{%(queriesSelector)s}[$__rate_interval]))', 'short'),
      // prometheus_remote_storage_samples_pending gauges the in-flight backlog.
      pending: sig('Samples pending', 'sum(prometheus_remote_storage_samples_pending{%(queriesSelector)s})', 'short'),
      cpu: sig('CPU', 'rate(alloy_resources_process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short'),
      rss: sig('Resident memory', 'alloy_resources_process_resident_memory_bytes{%(queriesSelector)s}', 'bytes'),
      // alloy_resources_process_start_time_seconds drives uptime.
      uptime: sig('Uptime', 'time() - alloy_resources_process_start_time_seconds{%(queriesSelector)s}', 's'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Components',
        width: 6,
        height: 7,
        elements: {
          running: signals.running.asStat('Running components'),
          evalP99: signals.evalP99.asTimeSeries('Component evaluation p99'),
          evalRate: signals.evalRate.asTimeSeries('Evaluations/s'),
          controllerQueue: signals.controllerQueue.asTimeSeries('Controller queue depth'),
        },
      },
      {
        title: 'Remote write',
        width: 8,
        height: 7,
        elements: {
          appended: signals.appended.asTimeSeries('Samples appended/s'),
          sendFailed: signals.sendFailed.asTimeSeries('Samples failed/s'),
          pending: signals.pending.asTimeSeries('Samples pending'),
        },
      },
      {
        title: 'Resources',
        width: 8,
        height: 7,
        elements: {
          cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          rss: signals.rss.asTimeSeries('Resident memory'),
          uptime: signals.uptime.asStat('Uptime'),
        },
      },
    ]),
}
