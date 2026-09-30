// observ-viz Kubernetes pods table (hand-written).
// One row per pod: where it runs, what it belongs to, how long it has been up
// and what it costs. Exported so any board can carry it:
//   local pods = import 'libs/kubernetes-observ-lib/pods.libsonnet';
//   g.element.panel('pods', pods.table({ selector: 'cluster=~"$cluster"' }))
//
// Columns
//   Namespace / Pod   the row key (cluster + namespace + pod, joined into pod_key)
//   Workload          the owner: ReplicaSet -> its Deployment, a CronJob's Job ->
//                     the CronJob, else the pod name less its generated suffixes
//   App / Component   app.kubernetes.io/part-of / component, where the pod has them
//   Node              kube_pod_info node
//   Version           app.kubernetes.io/version (or `version`) pod label - empty,
//                     and the column absent, where kube-state-metrics does not
//                     export it (its --metric-labels-allowlist)
//   Uptime            time() - kube_pod_start_time
//   Ready             ready containers / containers
//   Restarts          container restarts over the dashboard range
//   CPU / Memory      cAdvisor usage (cores / working set), sparkline over the range
//
// The identity query rebuilds pod -> labels / owner from kube_pod_info,
// kube_pod_labels and kube_pod_owner, each join falling back (`or on (...)`) so
// a pod missing a label or an owner still gets a row; every value query is
// reduced to `by (pod_key)` so the table joins on that one field.
//
// Links carry the row's cluster: Pod -> this pod on the pod board, Workload ->
// the workload's pods (var-pod regex), Namespace -> the namespace on the pod
// board, Node -> the Linux node board (node_exporter instance == node name).
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

local defaults = {
  datasource: '${datasource}',
  // pod-scoped selector (the pod board passes namespace + its $pod filter)
  selector: 'namespace=~"$namespace"',
  podBoardUid: 'observ-viz-kube-pod',
  nodeBoardUid: 'compute-linux-overview',
  title: 'Pods',
};

{
  defaults:: defaults,

  // a workload's pods as a regex for the pod board's $pod variable: the
  // workload name alone (a bare pod) or followed by its generated suffixes.
  workloadPodRegex(workload):: workload + '(-.*)?',

  table(config={})::
    local c = defaults + config;
    local s = c.selector;
    local sc = if s != '' then s + ', ' else '';
    local by = 'cluster, namespace, pod';
    local rl(expr, dst, repl, src, re) = 'label_replace(' + expr + ', "' + dst + '", "' + repl + '", "' + src + '", "' + re + '")';
    local key(expr) = 'sum by (pod_key) (label_join(' + expr + ', "pod_key", "/", "cluster", "namespace", "pod"))';
    local tq(expr) =
      query.prometheus.new(c.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local rq(expr) = query.prometheus.new(c.datasource, expr);

    // ---- identity: one series per pod ----
    local labelSet = 'label_app_kubernetes_io_part_of, label_app_kubernetes_io_component, label_app_kubernetes_io_version, label_version';
    local pods = '(topk by (' + by + ') (1, group by (' + by + ', node) (kube_pod_info{' + s + '}))'
                 + ' or on (' + by + ') group by (' + by + ') (container_memory_working_set_bytes{' + sc + 'container!="", pod!=""}))';
    local podLabels = 'topk by (' + by + ') (1, group by (' + by + ', ' + labelSet + ') (kube_pod_labels{' + s + '}))';
    local podOwner = 'topk by (' + by + ') (1, group by (' + by + ', owner_kind, owner_name) (kube_pod_owner{' + sc + 'owner_kind!="Node", owner_name!="<none>"}))';
    local withLabels = '((' + pods + ' * on (' + by + ') group_left (' + labelSet + ') ' + podLabels + ') or on (' + by + ') ' + pods + ')';
    local withOwner = '((' + withLabels + ' * on (' + by + ') group_left (owner_kind, owner_name) ' + podOwner + ') or on (' + by + ') ' + withLabels + ')';
    // pod name minus the generated suffixes (k8s' vowel-free alphabet), then the
    // owner where there is one - the same rules as the base Applications table
    local sfx = '[b-df-hj-np-tv-z2-9]';
    local podWorkload = rl(withOwner, 'workload', '$1$2$3$4', 'pod', '(.+)-' + sfx + '{6,10}-' + sfx + '{5}|(.+)-' + sfx + '{5}|(.+)-[0-9]+|(.+)');
    local workload = rl('label_join(' + podWorkload + ', "owner", ":", "owner_kind", "owner_name")',
                        'workload', '$1$2$3', 'owner', 'ReplicaSet:(.+)-[a-z0-9]+|Job:(.+)-[0-9]{8,}|[A-Za-z]+:(.+)');
    local named =
      rl(rl(rl(rl(workload, 'app', '$1', 'label_app_kubernetes_io_part_of', '(.+)'),
               'component', '$1', 'label_app_kubernetes_io_component', '(.+)'),
            'version', '$1', 'label_version', '(.+)'),
         'version', '$1', 'label_app_kubernetes_io_version', '(.+)');
    local ident = 'label_join(group by (' + by + ', node, workload, app, component, version) (' + named + '), "pod_key", "/", "cluster", "namespace", "pod")';

    local qIdent = tq(ident);
    local qUptime = tq(key('time() - max by (' + by + ') (kube_pod_start_time{' + s + '})'));
    local qReady = tq(key('sum by (' + by + ') (kube_pod_container_status_ready{' + s + '}) / count by (' + by + ') (kube_pod_container_status_ready{' + s + '})'));
    local qRestarts = tq(key('sum by (' + by + ') (increase(kube_pod_container_status_restarts_total{' + s + '}[$__range]))'));
    local qCpu = rq(key('sum by (' + by + ') (rate(container_cpu_usage_seconds_total{' + sc + 'container!=""}[$__rate_interval]))'));
    local qMem = rq(key('sum by (' + by + ') (container_memory_working_set_bytes{' + sc + 'container!=""})'));

    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local link(title, url) = { id: 'links', value: [{ title: title, url: url }] };
    local sparkCell = { id: 'custom.cellOptions', value: { type: 'sparkline', hideValue: false, lineWidth: 1.5, fillOpacity: 16 } };
    local colorText(steps) = [
      { id: 'custom.cellOptions', value: { type: 'color-text' } },
      { id: 'color', value: { mode: 'thresholds' } },
      { id: 'thresholds', value: { mode: 'absolute', steps: steps } },
    ];
    local podBoard = '/d/' + c.podBoardUid + '?var-cluster=${__data.fields.cluster}&var-namespace=${__data.fields.Namespace}';

    panel.table.new(c.title)
    + panel.table.withDescription('One row per pod. Workload = the owner (ReplicaSet -> Deployment, CronJob Job -> CronJob), else the pod name less its generated suffixes. App / Component = app.kubernetes.io/part-of / component; Version = app.kubernetes.io/version where kube-state-metrics exports it. Ready = ready containers / containers; Restarts over the dashboard range; CPU in cores and Memory (working set) trend over the range. Pod, Workload and Namespace filter the pod board; Node opens the Linux node board.')
    // refIds by position: A identity, B uptime, C ready, D restarts, E cpu (range), F memory (range)
    + panel.table.withTargets([qIdent, qUptime, qReady, qRestarts, qCpu, qMem])
    + panel.table.withTransformations([
      { id: 'timeSeriesTable', options: {} },
      { id: 'labelsToFields' },
      { id: 'filterFieldsByName', options: { include: { names: ['pod_key', 'cluster', 'namespace', 'pod', 'workload', 'app', 'component', 'node', 'version', 'Value #B', 'Value #C', 'Value #D', 'Trend #E', 'Trend #F'] } } },
      { id: 'seriesToColumns', options: { byField: 'pod_key' } },
      { id: 'organize', options: {
        excludeByName: { pod_key: true },
        indexByName: { namespace: 0, pod: 1, workload: 2, app: 3, component: 4, node: 5, version: 6, 'Value #B': 7, 'Value #C': 8, 'Value #D': 9, 'Trend #E': 10, 'Trend #F': 11, cluster: 12, pod_key: 13 },
        renameByName: { namespace: 'Namespace', pod: 'Pod', workload: 'Workload', app: 'App', component: 'Component', node: 'Node', version: 'Version', 'Value #B': 'Uptime', 'Value #C': 'Ready', 'Value #D': 'Restarts', 'Trend #E': 'CPU', 'Trend #F': 'Memory' },
      } },
      // the CPU / Memory trends reach back over the whole range and so name
      // pods that are gone; the identity query names only the live ones
      { id: 'filterByValue', options: { type: 'exclude', match: 'any', filters: [{ fieldName: 'Pod', config: { id: 'isNull', options: {} } }] } },
      { id: 'sortBy', options: { sort: [{ field: 'Pod', desc: false }] } },
    ])
    + panel.table.withOverrides([
      // the row's cluster rides along for the links, but is not a column
      ov('^cluster$', [{ id: 'custom.hidden', value: true }]),
      ov('^Namespace$', [link('Pods in ${__data.fields.Namespace}', '/d/' + c.podBoardUid + '?var-cluster=${__data.fields.cluster}&var-namespace=${__value.raw}')]),
      ov('^Pod$', [link('Open pod ${__value.raw}', podBoard + '&var-pod=${__value.raw}')]),
      ov('^Workload$', [link('Pods of ${__value.raw}', podBoard + '&var-pod=${__value.raw}(-.*)?')]),
      ov('^Node$', [link('Open node ${__value.raw}', '/d/' + c.nodeBoardUid + '?var-cluster=${__data.fields.cluster}&var-instance=${__value.raw}')]),
      ov('^Uptime$', [{ id: 'unit', value: 's' }, { id: 'decimals', value: 0 }, { id: 'custom.width', value: 90 }]),
      ov('^Ready$', [{ id: 'unit', value: 'percentunit' }, { id: 'decimals', value: 0 }, { id: 'custom.width', value: 70 }]
                    + colorText([{ color: 'red', value: null }, { color: 'orange', value: 0.5 }, { color: 'green', value: 1 }])),
      ov('^Restarts$', [{ id: 'decimals', value: 0 }, { id: 'custom.width', value: 80 }]
                       + colorText([{ color: 'green', value: null }, { color: 'orange', value: 1 }, { color: 'red', value: 5 }])),
      ov('^CPU$', [{ id: 'unit', value: 'short' }, { id: 'decimals', value: 3 }, sparkCell]),
      ov('^Memory$', [{ id: 'unit', value: 'bytes' }, sparkCell]),
    ]),
}
