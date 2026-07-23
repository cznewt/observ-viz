# windows.textfile.device

- **source**: device.prom -> windows_exporter textfile collector (C:\apps\alloy\textfile)
- **notes**: One-shot Win32_ComputerSystemProduct write per box (vendor/product/model).
- **patterns**: `windows_device_info`, `windows_textfile_.*`

## Live metrics (2)

- `windows_device_info`
- `windows_textfile_mtime_seconds`
