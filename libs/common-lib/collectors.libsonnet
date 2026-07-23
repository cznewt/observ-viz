// observ-viz collector registry (hand-curated, fleet-grounded).
// Each collector declares the metric families it produces (name patterns are
// RE2, anchored by the docs generator). Signals at the mixin/lib level
// reference metrics; scripts/gen-collector-docs.py joins the two so every
// signal shows which collector(s) can supply it — unions like "CPU model from
// unix.cpu-info OR OhmGraphite" become explicit instead of tribal knowledge.
// Flags/notes record what must be enabled for the family to exist.
{
  collectors: {
    'unix.cpu': {
      source: 'node_exporter (alloy prometheus.exporter.unix)',
      notes: 'node_cpu_info needs the cpu info flag (alloy-resources enable_cpu_info, default on since 2026-07-22).',
      patterns: ['node_cpu_seconds_total', 'node_cpu_info', 'node_cpu_scaling_frequency_.*', 'node_cpu_frequency_.*', 'node_schedstat_.*'],
    },
    'unix.loadavg': { source: 'node_exporter', patterns: ['node_load1', 'node_load5', 'node_load15'] },
    'unix.meminfo': { source: 'node_exporter', patterns: ['node_memory_.*'] },
    'unix.filesystem': { source: 'node_exporter', patterns: ['node_filesystem_.*'] },
    'unix.diskstats': { source: 'node_exporter', patterns: ['node_disk_.*'] },
    'unix.netdev': { source: 'node_exporter', notes: 'veth/cali interfaces excluded at collection.', patterns: ['node_network_.*'] },
    'unix.hwmon': { source: 'node_exporter', notes: 'CPU package temps: coretemp / AMD SMN pci0000:00_0000:00:18_3; nvme drive temps.', patterns: ['node_hwmon_.*'] },
    'unix.systemd': {
      source: 'node_exporter',
      notes: 'Enabled 2026-07-23 with a curated unit allowlist (salt-minion/alloy/sshd/docker/containerd/crio/kubelet/gdm/gnome-session/wg-quick/zerotier).',
      patterns: ['node_systemd_.*'],
    },
    'unix.os-uname-dmi': {
      source: 'node_exporter',
      notes: 'Device identity: system_vendor + product_version|product_name (firmware garbage fallback).',
      patterns: ['node_os_info', 'node_uname_info', 'node_dmi_info', 'node_boot_time_seconds'],
    },
    'unix.pressure-vmstat-misc': { source: 'node_exporter', patterns: ['node_pressure_.*', 'node_vmstat_.*', 'node_procs_.*', 'node_context_switches_total', 'node_intr_total', 'node_entropy_.*', 'node_filefd_.*', 'node_nf_conntrack_.*', 'node_time.*', 'node_power_supply_.*', 'node_nfs.*', 'node_zfs_.*'] },
    'unix.textfile.gpu': {
      source: 'gpu-ohm-textfile script -> node_exporter textfile collector',
      notes: 'Linux GPUs emitted in the OhmGraphite schema (nvidia via nvidia-smi, amdgpu + i915 via sysfs); 30s systemd timer, batocera via a service loop.',
      patterns: ['ohm_gpunvidia_.*', 'ohm_gpuati_.*', 'ohm_gpuintel_.*'],
    },

    'windows.core': {
      source: 'windows_exporter (alloy prometheus.exporter.windows)',
      patterns: ['windows_cpu_.*', 'windows_os_.*', 'windows_memory_.*', 'windows_logical_disk_.*', 'windows_net_.*', 'windows_system_.*', 'windows_time_.*'],
    },
    'windows.service': { source: 'windows_exporter service collector', patterns: ['windows_service_.*'] },
    'windows.textfile.device': {
      source: 'device.prom -> windows_exporter textfile collector (C:\\apps\\alloy\\textfile)',
      notes: 'One-shot Win32_ComputerSystemProduct write per box (vendor/product/model).',
      patterns: ['windows_device_info', 'windows_textfile_.*'],
    },

    ohmgraphite: {
      source: 'OhmGraphite (LibreHardwareMonitor), opt-in via alloy:hardware_sensors pillar',
      notes: 'hardware label carries CPU/GPU/disk model names; gpu families are per vendor (gpunvidia/gpuati/gpuintel).',
      patterns: ['ohm_cpu_.*', 'ohm_gpunvidia_.*', 'ohm_gpuati_.*', 'ohm_gpuintel_.*', 'ohm_hdd_.*', 'ohm_battery_.*', 'ohm_memory_.*', 'ohm_mainboard_.*'],
    },

    cadvisor: {
      source: 'k8s-monitoring cAdvisor scrape',
      notes: 'Scrape allowlist: only ~20 container_* families carry pod/namespace labels here; container_network_* is unlabeled.',
      patterns: ['container_cpu_.*', 'container_memory_.*', 'container_fs_.*', 'container_last_seen', 'container_network_.*', 'container_spec_.*'],
    },
    'kube-state-metrics': { source: 'k8s-monitoring KSM', patterns: ['kube_.*'] },
    kubelet: { source: 'k8s-monitoring control-plane scrape', patterns: ['kubelet_.*'] },
    apiserver: { source: 'k8s-monitoring control-plane scrape', patterns: ['apiserver_.*', 'workqueue_.*'] },

    'mimir.ruler': {
      source: 'recording rules (deployed via deploy-lib with MIMIR_RULER_URL)',
      patterns: ['base:cluster_nodes:n', 'node_namespace_pod_container:.*', 'namespace_cpu:.*', 'namespace_memory:.*', 'namespace_workload_pod:.*', 'instance:.*', 'cluster:.*'],
    },

    alerts: { source: 'prometheus/mimir alerting state', patterns: ['ALERTS', 'ALERTS_FOR_STATE'] },

    // catch-alls (the docs generator prefers longer/more specific patterns, so
    // these only absorb families the specific collectors above do not claim).
    'unix.other': { source: 'node_exporter (unclassified families)', patterns: ['node_.*'] },
    'windows.other': { source: 'windows_exporter (unclassified families)', patterns: ['windows_.*'] },
    'ohm.other': { source: 'OhmGraphite (unclassified families)', patterns: ['ohm_.*'] },
    'app.exporters': { source: 'application exporters (etcd/loki/mimir/grafana/guardian/...)', patterns: ['.*'] },
  },
}
