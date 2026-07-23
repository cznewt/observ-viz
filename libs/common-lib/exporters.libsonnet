// observ-viz exporter registry (hand-curated, fleet-grounded).
// Top level = EXPORTERS (node_exporter, windows_exporter, OhmGraphite, ...);
// each exporter carries its COLLECTORS as modules inside, and every collector
// declares the metric families it produces (RE2 patterns, anchored by the
// docs generator). Signals at the mixin/lib level reference metrics;
// scripts/gen-collector-docs.py joins the two so every signal shows which
// exporter/collector(s) supply it. Notes record enablement requirements.
{
  exporters: {
    node_exporter: {
      source: 'alloy prometheus.exporter.unix (standalone hosts) / prometheus-node-exporter DaemonSet (kube nodes)',
      collectors: {
        cpu: {
          notes: 'node_cpu_info needs the cpu info flag (alloy-resources enable_cpu_info, default on since 2026-07-22).',
          patterns: ['node_cpu_seconds_total', 'node_cpu_info', 'node_cpu_scaling_frequency_.*', 'node_cpu_frequency_.*', 'node_schedstat_.*'],
        },
        loadavg: { patterns: ['node_load1', 'node_load5', 'node_load15'] },
        meminfo: { patterns: ['node_memory_.*'] },
        filesystem: { patterns: ['node_filesystem_.*'] },
        diskstats: { patterns: ['node_disk_.*'] },
        netdev: { notes: 'veth/cali interfaces excluded at collection.', patterns: ['node_network_.*'] },
        hwmon: { notes: 'CPU package temps: coretemp / AMD SMN pci0000:00_0000:00:18_3; nvme drive temps.', patterns: ['node_hwmon_.*'] },
        systemd: {
          notes: 'Enabled 2026-07-23 with a curated unit allowlist (salt-minion/alloy/sshd/docker/containerd/crio/kubelet/gdm/gnome-session/wg-quick/zerotier).',
          patterns: ['node_systemd_.*'],
        },
        'os-uname-dmi': {
          notes: 'Device identity: system_vendor + product_version|product_name (firmware garbage fallback).',
          patterns: ['node_os_info', 'node_uname_info', 'node_dmi_info', 'node_boot_time_seconds'],
        },
        'pressure-vmstat-misc': { patterns: ['node_pressure_.*', 'node_vmstat_.*', 'node_procs_.*', 'node_context_switches_total', 'node_intr_total', 'node_entropy_.*', 'node_filefd_.*', 'node_nf_conntrack_.*', 'node_time.*', 'node_power_supply_.*', 'node_nfs.*', 'node_zfs_.*'] },
        'textfile-gpu': {
          notes: 'gpu-ohm-textfile script: Linux GPUs emitted in the OhmGraphite schema (nvidia via nvidia-smi, amdgpu + i915 via sysfs); 30s systemd timer, batocera via a service loop.',
          patterns: ['ohm_gpunvidia_.*', 'ohm_gpuati_.*', 'ohm_gpuintel_.*'],
        },
        other: { notes: 'unclassified node_exporter families (catch-all).', patterns: ['node_.*'] },
      },
    },

    windows_exporter: {
      source: 'alloy prometheus.exporter.windows (embedded)',
      collectors: {
        cpu: { patterns: ['windows_cpu_.*'] },
        os: { patterns: ['windows_os_.*'] },
        memory: { patterns: ['windows_memory_.*'] },
        logical_disk: { patterns: ['windows_logical_disk_.*'] },
        net: { patterns: ['windows_net_.*'] },
        system: { patterns: ['windows_system_.*'] },
        time: { patterns: ['windows_time_.*'] },
        service: { patterns: ['windows_service_.*'] },
        'textfile-device': {
          notes: 'device.prom in C:\\apps\\alloy\\textfile — one-shot Win32_ComputerSystemProduct write per box (vendor/product/model).',
          patterns: ['windows_device_info', 'windows_textfile_.*'],
        },
        other: { notes: 'unclassified windows_exporter families (catch-all).', patterns: ['windows_.*'] },
      },
    },

    ohmgraphite: {
      source: 'OhmGraphite (LibreHardwareMonitor), opt-in via alloy:hardware_sensors pillar',
      collectors: {
        cpu: { notes: 'hardware label = CPU model name.', patterns: ['ohm_cpu_.*'] },
        gpu: { notes: 'per-vendor families; hardware label = GPU model.', patterns: ['ohm_gpunvidia_.*', 'ohm_gpuati_.*', 'ohm_gpuintel_.*'] },
        hdd: { notes: 'hardware label = disk model.', patterns: ['ohm_hdd_.*'] },
        battery: { patterns: ['ohm_battery_.*'] },
        memory: { patterns: ['ohm_memory_.*'] },
        mainboard: { patterns: ['ohm_mainboard_.*'] },
        other: { patterns: ['ohm_.*'] },
      },
    },

    cadvisor: {
      source: 'k8s-monitoring cAdvisor scrape',
      collectors: {
        container: {
          notes: 'Scrape allowlist: only ~20 container_* families carry pod/namespace labels here; container_network_* is unlabeled.',
          patterns: ['container_cpu_.*', 'container_memory_.*', 'container_fs_.*', 'container_last_seen', 'container_network_.*', 'container_spec_.*'],
        },
      },
    },

    'kube-state-metrics': {
      source: 'k8s-monitoring KSM',
      collectors: { kube: { patterns: ['kube_.*'] } },
    },

    kubelet: {
      source: 'k8s-monitoring control-plane scrape',
      collectors: { kubelet: { patterns: ['kubelet_.*'] } },
    },

    apiserver: {
      source: 'k8s-monitoring control-plane scrape',
      collectors: {
        apiserver: { patterns: ['apiserver_.*'] },
        workqueue: { patterns: ['workqueue_.*'] },
      },
    },

    'mimir-ruler': {
      source: 'recording rules (deployed via deploy-lib with MIMIR_RULER_URL)',
      collectors: {
        'recording-rules': { patterns: ['base:cluster_nodes:n', 'node_namespace_pod_container:.*', 'namespace_cpu:.*', 'namespace_memory:.*', 'namespace_workload_pod:.*', 'instance:.*', 'cluster:.*'] },
      },
    },

    alerting: {
      source: 'prometheus/mimir alerting state',
      collectors: { alerts: { patterns: ['ALERTS', 'ALERTS_FOR_STATE'] } },
    },

    'app-exporters': {
      source: 'application exporters (etcd/loki/mimir/grafana/guardian/...)',
      collectors: { apps: { notes: 'global catch-all — everything unclaimed above.', patterns: ['.*'] } },
    },
  },
}
