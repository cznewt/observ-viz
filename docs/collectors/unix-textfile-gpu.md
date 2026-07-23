# unix.textfile.gpu

- **source**: gpu-ohm-textfile script -> node_exporter textfile collector
- **notes**: Linux GPUs emitted in the OhmGraphite schema (nvidia via nvidia-smi, amdgpu + i915 via sysfs); 30s systemd timer, batocera via a service loop.
- **patterns**: `ohm_gpunvidia_.*`, `ohm_gpuati_.*`, `ohm_gpuintel_.*`

## Live metrics (0)

_none currently in the datasource_
