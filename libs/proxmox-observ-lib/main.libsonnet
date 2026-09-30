// observ-viz Proxmox VE pack (hand-written).
// Two sources, as alloy-resources' proxmox scenario ships them:
//   - the PVE hosts' own node_exporter series (CPU temperature, load, memory,
//     root disk) - selected by hostSelector, default hosts named *pve*
//   - proxmox-exporter's cluster / node allocation (proxmox_*: CPUs and memory
//     allocated to guests vs available, node up) - its tab appears once those
//     series exist
// Usage:
//   g.libs.system.proxmox.new({ hostSelector: 'instance=~".*pve.*"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-proxmox',
      dashboardTitle: 'Proxmox VE',
      // Platform / Infrastructure / Compute
      folderPath: (import 'libs/common-lib/folders.libsonnet').compute,
      dashboardTags: ['proxmox', 'pve', 'virtualization', 'hosts', 'app-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      // PVE hosts among the node_exporter targets
      hostSelector: 'instance=~".*pve.*"',
      selector: 'cluster=~"$cluster", instance=~"$instance"',
      // pack.build appends {...} to varMetric for chained variables, so no
      // selector here: $instance lists every node_exporter host, the queries
      // keep only the PVE ones through hostSelector
      varMetric: 'node_uname_info',
      groupVar: 'cluster',
      varLabels: ['instance'],
      ruleSelector: '',
      cpuChips: '.*coretemp.*|.*k10temp.*|.*zenpower.*|.*cpu_thermal.*|pci0000:00_0000:00:18_3',
      cpuTempWarning: 85,
      cpuTempCritical: 95,
    } + config;

    local h = cfg.hostSelector + ', ';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local hostRule = cfg.hostSelector + rsComma;

    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      // host overview (node_exporter on the PVE hosts)
      hosts: sig('Hosts', 'count(node_uname_info{' + h + '%(queriesSelector)s})', 'short', 'hosts'),
      maxTemp: sig('Hottest CPU', 'max(node_hwmon_temp_celsius{chip=~"' + cfg.cpuChips + '", ' + h + '%(queriesSelector)s})', 'celsius', 'hottest'),
      cpuUsed: sig('CPU used', '1 - avg(rate(node_cpu_seconds_total{mode="idle", ' + h + '%(queriesSelector)s}[$__rate_interval]))', 'percentunit', 'CPU'),
      memUsed: sig('Memory used', '1 - sum(node_memory_MemAvailable_bytes{' + h + '%(queriesSelector)s}) / sum(node_memory_MemTotal_bytes{' + h + '%(queriesSelector)s})', 'percentunit', 'memory'),
      // per host
      temp: sig('CPU temperature', 'max by (instance) (node_hwmon_temp_celsius{chip=~"' + cfg.cpuChips + '", ' + h + '%(queriesSelector)s})', 'celsius'),
      cpu: sig('CPU used', '1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle", ' + h + '%(queriesSelector)s}[$__rate_interval]))', 'percentunit'),
      load: sig('Load per CPU', 'max by (instance) (node_load5{' + h + '%(queriesSelector)s}) / count by (instance) (node_cpu_seconds_total{mode="idle", ' + h + '%(queriesSelector)s})', 'short'),
      mem: sig('Memory used', '1 - node_memory_MemAvailable_bytes{' + h + '%(queriesSelector)s} / node_memory_MemTotal_bytes{' + h + '%(queriesSelector)s}', 'percentunit'),
      rootDisk: sig('Root disk used', '1 - max by (instance) (node_filesystem_avail_bytes{mountpoint="/", ' + h + '%(queriesSelector)s} / node_filesystem_size_bytes{mountpoint="/", ' + h + '%(queriesSelector)s})', 'percentunit'),
      uptime: sig('Uptime', 'time() - node_boot_time_seconds{' + h + '%(queriesSelector)s}', 's'),
      // proxmox-exporter allocation
      nodeUp: sig('PVE nodes up', 'sum(proxmox_node_up{%(queriesSelector)s})', 'short', 'up'),
      clusterCpuAlloc: sig('CPUs allocated', 'sum by (cluster) (proxmox_cluster_cpus_allocated{%(queriesSelector)s}) / sum by (cluster) (proxmox_cluster_cpus_total{%(queriesSelector)s})', 'percentunit', '{{cluster}} CPUs allocated'),
      clusterMemAlloc: sig('Memory allocated', 'sum by (cluster) (proxmox_cluster_memory_allocated_bytes{%(queriesSelector)s}) / sum by (cluster) (proxmox_cluster_memory_total_bytes{%(queriesSelector)s})', 'percentunit', '{{cluster}} memory allocated'),
      nodeCpuAlloc: sig('CPUs allocated per node', 'proxmox_node_cpus_allocated{%(queriesSelector)s}', 'short'),
      nodeMemAlloc: sig('Memory allocated per node', 'proxmox_node_memory_allocated_bytes{%(queriesSelector)s}', 'bytes'),
    };

    local presence(metrics) = { label: 'cluster', query: '{__name__=~"' + std.join('|', metrics) + '", cluster=~"$cluster"}' };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 6,
        height: 5,
        elements: {
          a_hosts: signals.hosts.asStat('Hosts'),
          b_temp: signals.maxTemp.asStat('Hottest CPU')
                  + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: cfg.cpuTempWarning - 10 }, { color: 'red', value: cfg.cpuTempWarning }]),
          c_cpu: signals.cpuUsed.asStat('CPU used'),
          d_mem: signals.memUsed.asStat('Memory used'),
        },
      },
      {
        title: 'Hosts',
        width: 12,
        height: 7,
        elements: {
          a_temp: signals.temp.asTimeSeries('CPU temperature'),
          b_cpu: signals.cpu.asTimeSeries('CPU used'),
          c_load: signals.load.asTimeSeries('Load (5m) per CPU'),
          d_mem: signals.mem.asTimeSeries('Memory used'),
          e_disk: signals.rootDisk.asTimeSeries('Root disk used'),
          f_uptime: signals.uptime.asTimeSeries('Uptime'),
        },
      },
    ], [
      alert.rule.group('proxmox', [
        alert.rule.new(
          'ProxmoxHostCpuHot',
          'max by (cluster, instance) (node_hwmon_temp_celsius{chip=~"' + cfg.cpuChips + '", ' + hostRule + '}) > ' + cfg.cpuTempWarning,
          '10m',
          'warning',
          {},
          { summary: 'A Proxmox host runs hot.', description: 'The CPU of {{ $labels.instance }} has been at {{ $value }} °C for 10 minutes - check its cooling before it throttles.' }
        ),
        alert.rule.new(
          'ProxmoxHostCpuOverheating',
          'max by (cluster, instance) (node_hwmon_temp_celsius{chip=~"' + cfg.cpuChips + '", ' + hostRule + '}) > ' + cfg.cpuTempCritical,
          '5m',
          'critical',
          {},
          { summary: 'A Proxmox host is overheating.', description: 'The CPU of {{ $labels.instance }} is at {{ $value }} °C - it throttles and every guest on it slows down.' }
        ),
        alert.rule.new(
          'ProxmoxNodeDown',
          'proxmox_node_up' + (if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '') + ' == 0',
          '5m',
          'critical',
          {},
          { summary: 'A Proxmox node is down.', description: 'Proxmox reports node {{ $labels.node }} in {{ $labels.cluster }} as down.' }
        ),
      ]),
    ], [], [
      {
        title: 'Allocation',
        presence: presence(['proxmox_node_up', 'proxmox_cluster_cpus_total']),
        width: 12,
        height: 7,
        elements: {
          a_cpu: signals.clusterCpuAlloc.asTimeSeries('Guest allocation vs capacity')
                 + panel.withTargetsMixin([signals.clusterMemAlloc.asTarget()]),
          b_nodeCpu: signals.nodeCpuAlloc.asTimeSeries('CPUs allocated per node'),
          c_nodeMem: signals.nodeMemAlloc.asTimeSeries('Memory allocated per node'),
          d_up: signals.nodeUp.asStat('PVE nodes up'),
        },
      },
    ]),
}
