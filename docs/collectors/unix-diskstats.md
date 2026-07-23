# unix.diskstats

- **source**: node_exporter
- **patterns**: `node_disk_.*`

## Consuming signals

| Lib | Signal | Metrics |
| --- | --- | --- |
| system.linux | diskIo | `node_disk_io_time_seconds_total` |
| system.linux | diskIoLatency | `node_disk_io_time_weighted_seconds_total` |
| system.linux | diskReadBps | `node_disk_read_bytes_total` |
| system.linux | diskReadIops | `node_disk_reads_completed_total` |
| system.linux | diskWriteBps | `node_disk_written_bytes_total` |
| system.linux | diskWriteIops | `node_disk_writes_completed_total` |

## Live metrics (23)

- `node_disk_ata_rotation_rate_rpm`
- `node_disk_ata_write_cache`
- `node_disk_ata_write_cache_enabled`
- `node_disk_device_mapper_info`
- `node_disk_discard_time_seconds_total`
- `node_disk_discarded_sectors_total`
- `node_disk_discards_completed_total`
- `node_disk_discards_merged_total`
- `node_disk_filesystem_info`
- `node_disk_flush_requests_time_seconds_total`
- `node_disk_flush_requests_total`
- `node_disk_info`
- `node_disk_io_now`
- `node_disk_io_time_seconds_total`
- `node_disk_io_time_weighted_seconds_total`
- `node_disk_read_bytes_total`
- `node_disk_read_time_seconds_total`
- `node_disk_reads_completed_total`
- `node_disk_reads_merged_total`
- `node_disk_write_time_seconds_total`
- `node_disk_writes_completed_total`
- `node_disk_writes_merged_total`
- `node_disk_written_bytes_total`
