// observ-viz Alloy pack (hand-written).
// Grafana Alloy internal monitoring (alloy_* metrics), emitted as native v2
// elements. Usage:
//   g.libs.collector.alloy.new({ selector: 'job="alloy"' }).grafana.dashboard
//   g.libs.collector.alloy.new({...}).grafana.elements   // reuse in a board
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-alloy',
      dashboardTitle: 'Alloy',
      dashboardTags: ['alloy', 'collector', 'grafana', 'app-level'],
      description: 'Grafana Alloy self-monitoring: pipeline components, evaluation latency, remote-write throughput and backlog, process resources.',
      // per-instance legend: the pod on kube; set '{{instance}}' for a host deployment.
      legend: '{{pod}}',
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      varMetric: 'alloy_build_info',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      docTabs: true,  // add Signals + Runbooks reference tabs (built from this pack)
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend).withDescription(desc);

    local signals = {
      running: sig('Running components', 'sum(alloy_component_controller_running_components{%(queriesSelector)s})', 'short', desc='Components running in the Alloy pipeline. A drop means a component failed to evaluate or was removed by a config reload.'),
      evalP99: sig('Evaluation p99', 'histogram_quantile(0.99, sum by (le)(rate(alloy_component_evaluation_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', desc='Slowest 1 percent of component evaluations. Slow evaluations delay every downstream component.'),
      // alloy_component_dependencies_wait_seconds tracks how long a component
      // waits on dependencies before evaluating; keep the alloy_ metric name.
      evalRate: sig('Evaluations', 'sum(rate(alloy_component_evaluation_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 'ops', desc='Component evaluations per second.'),
      // alloy_component_controller_evaluating reports the controller queue depth.
      controllerQueue: sig('Controller queue', 'sum(alloy_component_controller_evaluating{%(queriesSelector)s})', 'short', desc='Components waiting to be evaluated. A queue that never drains means a component is stuck.'),
      // prometheus_remote_write_wal_samples_appended_total is exposed by Alloy's
      // prometheus.remote_write WAL; keep the upstream metric name.
      appended: sig('Samples appended', 'sum(rate(prometheus_remote_write_wal_samples_appended_total{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='Samples appended to the remote-write WAL per second, the volume Alloy is trying to ship.'),
      // prometheus_remote_storage_samples_failed_total counts WAL send failures.
      sendFailed: sig('Samples failed', 'sum(rate(prometheus_remote_storage_samples_failed_total{%(queriesSelector)s}[$__rate_interval]))', 'short', desc='Samples that failed to send to the remote endpoint per second. Sustained failures end in data loss once the WAL is truncated.'),
      // prometheus_remote_storage_samples_pending gauges the in-flight backlog.
      pending: sig('Samples pending', 'sum(prometheus_remote_storage_samples_pending{%(queriesSelector)s})', 'short', desc='Samples waiting in the remote-write queue. Growing means the endpoint is slower than the scrape volume.'),
      cpu: sig('CPU', 'rate(alloy_resources_process_cpu_seconds_total{%(queriesSelector)s}[$__rate_interval])', 'short', desc='CPU cores used by the Alloy process.'),
      rss: sig('Resident memory', 'alloy_resources_process_resident_memory_bytes{%(queriesSelector)s}', 'bytes', desc='Resident memory of the Alloy process.'),
      // alloy_resources_process_start_time_seconds drives uptime.
      uptime: sig('Uptime', 'time() - alloy_resources_process_start_time_seconds{%(queriesSelector)s}', 's', desc='Time since the Alloy process started.'),
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
    ], [
      // alerting rule group
      alert.rule.group('alloy', [
        alert.rule.new(
          'AlloyNoRunningComponents',
          'alloy_component_controller_running_components' + rsBrace + ' == 0',
          '5m',
          'critical',
          {},
          { summary: 'Alloy on {{ $labels.instance }} has no running components.' }
        ),
        alert.rule.new(
          'AlloyRemoteWriteFailing',
          'rate(prometheus_remote_storage_samples_failed_total' + rsBrace + '[5m]) > 0',
          '15m',
          'warning',
          {},
          { summary: 'Alloy remote write on {{ $labels.instance }} is failing to send samples.' }
        ),
        alert.rule.new(
          'AlloyRemoteWriteBacklog',
          'prometheus_remote_storage_samples_pending' + rsBrace + ' > 10000',
          '15m',
          'warning',
          {},
          { summary: 'Alloy remote write backlog on {{ $labels.instance }} is above 10000 pending samples.' }
        ),
        alert.rule.new(
          'AlloyControllerQueueHigh',
          'alloy_component_controller_evaluating' + rsBrace + ' > 0',
          '15m',
          'warning',
          {},
          { summary: 'Alloy controller evaluation queue on {{ $labels.instance }} is not draining.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('alloy.rules', [
        alert.rule.record('instance:alloy_cpu_usage:rate5m', 'rate(alloy_resources_process_cpu_seconds_total' + rsBrace + '[5m])'),
        alert.rule.record('instance:alloy_samples_appended:rate5m', 'rate(prometheus_remote_write_wal_samples_appended_total' + rsBrace + '[5m])'),
      ]),
    ]),
}
