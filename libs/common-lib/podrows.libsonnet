// observ-viz pod rows (hand-written).
// The rows a workload board's Overview tab opens on - the same on a service
// board (g.libs.service) and on every pack board whose targets are pods
// (pack.build adds them there, scoped to the pods behind the selected job):
//   Pods       one row per pod: node, phase, restarts, age, CPU, memory and
//              memory vs limit - instant queries merged on cluster/namespace/pod
//   Resources  CPU and memory vs requests / limits, network, disk IO (cAdvisor)
//   Logs       lines by level, error lines by pod, then the pod log lines (Loki)
//
// groups(cfg) -> overviewLeadGroups for tabbed.libsonnet. cfg:
//   datasource      Prometheus datasource ('${datasource}')
//   lokiDatasource  Loki datasource ('${loki_datasource}')
//   kubeSelector    the pods, as cluster / namespace / pod matchers
//   pods, logs      include the Pods + Resources rows / the log rows
//   gates           { pods, resources, logs }: the hidden presence variable a
//                   row waits for; a missing key renders that row always
local panel = import 'custom/panel.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

local stateMappings(m) = [{ type: 'value', options: m }];
local dashed(regex) = panel.withOverrides([{
  matcher: { id: 'byRegexp', options: regex },
  properties: [
    { id: 'custom.lineStyle', value: { fill: 'dash', dash: [10, 10] } },
    { id: 'custom.fillOpacity', value: 0 },
  ],
}]);
local logLevelColors = { critical: 'dark-red', fatal: 'dark-red', 'error': 'red', warn: 'orange', info: 'green', debug: 'blue', unknown: 'text' };

{
  signals(cfg)::
    local ksig(name, expr, unit, legend='{{pod}}', desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.kubeSelector).withLegendFormat(legend).withDescription(desc);
    {
      cpu: ksig('CPU usage', 'sum by (pod) (rate(container_cpu_usage_seconds_total{%(queriesSelector)s, container!=""}[$__rate_interval]))', 'short', desc='CPU cores used by all containers of each pod (cAdvisor). Dashed lines are the requests and limits from kube-state-metrics: usage above the request means the pod competes for CPU, usage at the limit means it is being throttled.'),
      cpuRequests: ksig('CPU requests', 'sum by (pod) (kube_pod_container_resource_requests{%(queriesSelector)s, resource="cpu"})', 'short', '{{pod}} requests', desc='CPU requested by the pod containers (what the scheduler reserved).'),
      cpuLimits: ksig('CPU limits', 'sum by (pod) (kube_pod_container_resource_limits{%(queriesSelector)s, resource="cpu"})', 'short', '{{pod}} limits', desc='CPU limit of the pod containers (above it the kernel throttles).'),
      mem: ksig('Memory working set', 'sum by (pod) (container_memory_working_set_bytes{%(queriesSelector)s, container!=""})', 'bytes', desc='Working-set memory of each pod (what the kernel would OOM-kill on). Dashed lines are requests and limits: a working set near the limit means an OOM kill is close.'),
      memRequests: ksig('Memory requests', 'sum by (pod) (kube_pod_container_resource_requests{%(queriesSelector)s, resource="memory"})', 'bytes', '{{pod}} requests', desc='Memory requested by the pod containers.'),
      memLimits: ksig('Memory limits', 'sum by (pod) (kube_pod_container_resource_limits{%(queriesSelector)s, resource="memory"})', 'bytes', '{{pod}} limits', desc='Memory limit of the pod containers (the OOM-kill threshold).'),
      // network is counted on the pod sandbox, a series without a container
      // label: a scrape that drops those (k8s-monitoring cadvisor
      // dropEmptyContainerLabels) leaves it empty.
      netRx: ksig('Network received', 'sum by (pod) (rate(container_network_receive_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{pod}} received', desc='Bytes per second the pod receives over all its interfaces (cAdvisor). Dashed is what it sends. Needs the pod-level network series, which a scrape dropping container-less cAdvisor series removes.'),
      netTx: ksig('Network transmitted', 'sum by (pod) (rate(container_network_transmit_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps', '{{pod}} transmitted', desc='Bytes per second the pod sends over all its interfaces (cAdvisor).'),
      diskRead: ksig('Disk read', 'sum by (pod) (rate(container_fs_reads_bytes_total{%(queriesSelector)s, container!=""}[$__rate_interval]))', 'Bps', '{{pod}} read', desc='Bytes per second the pod containers read from disk (cAdvisor). Dashed is what they write.'),
      diskWrite: ksig('Disk write', 'sum by (pod) (rate(container_fs_writes_bytes_total{%(queriesSelector)s, container!=""}[$__rate_interval]))', 'Bps', '{{pod}} write', desc='Bytes per second the pod containers write to disk (cAdvisor).'),
      logsVolume: signal.new('Log lines by level', 'loki', cfg.lokiDatasource, 'sum by (detected_level) (count_over_time({%(queriesSelector)s} [$__auto]))', 'short')
                  .filteringSelector(cfg.kubeSelector).withLegendFormat('{{detected_level}}')
                  .withDescription('Log lines of the selected pods per interval, by the level Loki detects. A jump in error or warn lines is often the first sign of trouble.'),
      logsErrors: signal.new('Error lines by pod', 'loki', cfg.lokiDatasource, 'sum by (pod) (count_over_time({%(queriesSelector)s} | detected_level=~"error|fatal|critical" [$__auto]))', 'short')
                  .filteringSelector(cfg.kubeSelector).withLegendFormat('{{pod}}')
                  .withDescription('Error, fatal and critical log lines per pod and interval. One pod far above the others points at that pod, all of them at the service.'),
      logsPod: signal.new('Pod logs', 'loki', cfg.lokiDatasource, '{%(queriesSelector)s}', 'short')
               .filteringSelector(cfg.kubeSelector).withDescription('Log lines of the selected pods, from Loki.'),
    },

  // one row per pod, like kubectl get pods: an instant query per column,
  // merged on cluster / namespace / pod. A and B are there for their node and
  // phase labels; their values are hidden.
  podsTable(cfg)::
    local podKey = 'cluster, namespace, pod';
    local pcol(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.kubeSelector);
    local cols = [
      pcol('Node', 'max by (' + podKey + ', node) (kube_pod_info{%(queriesSelector)s})', 'short'),
      pcol('Phase', 'max by (' + podKey + ', phase) (kube_pod_status_phase{%(queriesSelector)s} == 1)', 'short'),
      pcol('Restarts', 'sum by (' + podKey + ') (kube_pod_container_status_restarts_total{%(queriesSelector)s})', 'short'),
      pcol('Age', 'time() - max by (' + podKey + ') (kube_pod_start_time{%(queriesSelector)s})', 'dtdurations'),
      pcol('CPU', 'sum by (' + podKey + ') (rate(container_cpu_usage_seconds_total{%(queriesSelector)s, container!=""}[$__rate_interval]))', 'short'),
      pcol('Memory', 'sum by (' + podKey + ') (container_memory_working_set_bytes{%(queriesSelector)s, container!=""})', 'bytes'),
      pcol('Memory / limit', 'sum by (' + podKey + ') (container_memory_working_set_bytes{%(queriesSelector)s, container!=""}) / sum by (' + podKey + ') (kube_pod_container_resource_limits{%(queriesSelector)s, resource="memory"})', 'percentunit'),
    ];
    local ref(i) = std.char(std.codepoint('A') + i);
    local valueCols = std.range(2, std.length(cols) - 1);
    local colOverride(name, props) = { matcher: { id: 'byName', options: name }, properties: props };
    local colorText = { id: 'custom.cellOptions', value: { type: 'color-text' } };
    local steps(s) = { id: 'thresholds', value: { mode: 'absolute', steps: s } };
    panel.table.new('Pods')
    + panel.table.withDescription('One row per pod, like kubectl get pods: the node it runs on, its phase, restarts, age, CPU cores and working-set memory (cAdvisor), and memory as a share of its limit (empty without a limit). Instant queries merged on cluster / namespace / pod.')
    + panel.table.withTargets([cols[i].asTableTarget() + { spec+: { refId: ref(i) } } for i in std.range(0, std.length(cols) - 1)])
    + panel.table.withTransformations([
      { id: 'merge', options: {} },
      { id: 'organize', options: {
        excludeByName: { Time: true, 'Value #A': true, 'Value #B': true },
        renameByName: { cluster: 'Cluster', namespace: 'Namespace', pod: 'Pod', node: 'Node', phase: 'Phase' }
                      + { ['Value #' + ref(i)]: cols[i]._name for i in valueCols },
        indexByName: { cluster: 0, namespace: 1, pod: 2, node: 3, phase: 4 }
                     + { ['Value #' + ref(i)]: 3 + i for i in valueCols },
      } },
    ])
    + panel.table.withOverrides(
      [colOverride(cols[i]._name, [{ id: 'unit', value: cols[i]._unit }]) for i in valueCols]
      + [
        colOverride('Phase', [colorText, { id: 'mappings', value: stateMappings({
          Running: { color: 'green', index: 0 },
          Pending: { color: 'orange', index: 1 },
          Succeeded: { color: 'blue', index: 2 },
          Failed: { color: 'red', index: 3 },
          Unknown: { color: 'text', index: 4 },
        }) }]),
        colOverride('Restarts', [colorText, steps([{ color: 'green', value: null }, { color: 'orange', value: 1 }])]),
        colOverride('Memory / limit', [colorText, steps([{ color: 'green', value: null }, { color: 'orange', value: 0.8 }, { color: 'red', value: 0.9 }])]),
        colOverride('CPU', [{ id: 'decimals', value: 3 }]),
      ]
    ),

  groups(cfg)::
    local root = self;
    local s = root.signals(cfg);
    local gates = if std.objectHas(cfg, 'gates') then cfg.gates else {};
    local gate(k) = if std.objectHas(gates, k) then { when: gates[k] } else {};
    (if std.objectHas(cfg, 'pods') && cfg.pods then [
       { title: 'Pods', width: 24, height: 8, elements: { ovp01_pods: root.podsTable(cfg) } } + gate('pods'),
       { title: 'Resources', width: 12, height: 7, elements: {
         ovr11_cpu: s.cpu.asTimeSeries('CPU: usage vs requests / limits')
                    + panel.withTargetsMixin([s.cpuRequests.asTarget(), s.cpuLimits.asTarget()])
                    + dashed('/ (requests|limits)$/'),
         ovr12_mem: s.mem.asTimeSeries('Memory: working set vs requests / limits')
                    + panel.withTargetsMixin([s.memRequests.asTarget(), s.memLimits.asTarget()])
                    + dashed('/ (requests|limits)$/'),
         ovr13_net: s.netRx.asTimeSeries('Network: received / transmitted')
                    + panel.withTargetsMixin([s.netTx.asTarget()])
                    + dashed('/ transmitted$/'),
         ovr14_disk: s.diskRead.asTimeSeries('Disk: read / write')
                     + panel.withTargetsMixin([s.diskWrite.asTarget()])
                     + dashed('/ write$/'),
       } } + gate('resources'),
     ] else [])
    + (if std.objectHas(cfg, 'logs') && cfg.logs then [
         { title: 'Logs', width: 12, height: 7, elements: {
           ovl21_volume: s.logsVolume.asTimeSeries()
                         + panel.timeSeries.standardOptions.withMin(0)
                         + panel.timeSeries.custom.withDrawStyle('bars')
                         + panel.timeSeries.custom.withFillOpacity(60)
                         + panel.timeSeries.custom.stacking.withMode('normal')
                         + panel.timeSeries.standardOptions.withOverrides([
                           { matcher: { id: 'byName', options: level }, properties: [{ id: 'color', value: { mode: 'fixed', fixedColor: color } }] }
                           for level in std.objectFields(logLevelColors)
                           for color in [logLevelColors[level]]
                         ]),
           ovl22_errors: s.logsErrors.asTimeSeries(),
         } } + gate('logs'),
         { title: 'Pod logs', hideHeader: true, width: 24, height: 10, elements: {
           ovl31_pod: panel.logs.new('Pod logs') + panel.withDescription(s.logsPod._description) + panel.logs.withTargets([s.logsPod.asTarget()]),
         } } + gate('logs'),
       ] else []),
}
