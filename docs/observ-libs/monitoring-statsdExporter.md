# StatsD exporter  (`g.libs.monitoring.statsdExporter`)

Dashboard uid `observ-viz-statsd-exporter` · 26 signals · 4 alerts · 2 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `actions` | ops | `sum by (action) (rate(statsd_exporter_events_actions_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `conflicts` | ops | `topk(10, sum by (type, metric_name) (rate(statsd_exporter_events_conflict_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])))` | — |
| `errors` | ops | `(sum by (instance) (rate(statsd_exporter_sample_errors_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))) + (sum by (instance) (rate(statsd_exporter_tag_errors_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval])) or vector(0))` | — |
| `eventErrors` | ops | `sum by (reason) (rate(statsd_exporter_events_error_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `events` | ops | `sum by (instance) (rate(statsd_exporter_events_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `eventsByType` | ops | `sum by (type) (rate(statsd_exporter_events_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `flushes` | ops | `sum by (instance) (rate(statsd_exporter_event_queue_flushed_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `lines` | ops | `sum by (instance) (rate(statsd_exporter_lines_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `mappings` | short | `max by (instance) (statsd_exporter_loaded_mappings{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `mappingsSeries` | short | `max by (instance) (statsd_exporter_loaded_mappings{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `metrics` | short | `sum by (instance) (statsd_exporter_metrics_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `metricsByType` | short | `sum by (type) (statsd_exporter_metrics_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `reloads` | short | `sum by (outcome) (increase(statsd_exporter_config_reloads_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `sampleErrors` | ops | `sum by (reason) (rate(statsd_exporter_sample_errors_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `samples` | ops | `sum by (instance) (rate(statsd_exporter_samples_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `tagErrors` | ops | `sum by (instance) (rate(statsd_exporter_tag_errors_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `tags` | ops | `sum by (instance) (rate(statsd_exporter_tags_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `tcpConnections` | ops | `sum by (instance) (rate(statsd_exporter_tcp_connections_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `tcpErrors` | ops | `sum by (instance) (rate(statsd_exporter_tcp_connection_errors_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `tcpTooLong` | ops | `sum by (instance) (rate(statsd_exporter_tcp_too_long_lines_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `udpDrops` | pps | `sum by (instance) (rate(statsd_exporter_udp_packet_drops_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `udpPackets` | pps | `sum by (instance) (rate(statsd_exporter_udp_packets_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `unixgramPackets` | pps | `sum by (instance) (rate(statsd_exporter_unixgram_packets_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `unmapped` | ops | `sum by (instance) (rate(statsd_exporter_events_unmapped_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `unmappedSeries` | ops | `sum by (instance) (rate(statsd_exporter_events_unmapped_total{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__rate_interval]))` | — |
| `version` | short | `max by (instance, version) (statsd_exporter_build_info{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |

## Dashboard

- **Overview** — `ov1_events`, `ov2_unmapped`, `ov3_mappings`, `ov4_metrics`, `ov5_errors`
- **Ingest** — `in1_packets`, `in2_lines`, `in3_eventsByType`, `in4_tcp`, `in5_tags`, `in6_flushes`
- **Mapping** — `actions`, `conflicts`, `mappingsSeries`, `reloads`, `unmappedSeries`
- **Errors** — `er1_samples`, `er2_events`, `er3_tags_tcp`
- **Output** — `metricsByType`, `version`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `StatsdExporterDown` | warning | 5m | — |
| `StatsdExporterUnmappedEvents` | warning | 15m | — |
| `StatsdExporterConfigReloadFailed` | warning | 1m | — |
| `StatsdExporterEventConflicts` | warning | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:statsd_exporter_events:rate5m` | `sum by (cluster, job, instance, type) (rate(statsd_exporter_events_total[5m]))` |
| `instance:statsd_exporter_events_unmapped:rate5m` | `sum by (cluster, job, instance) (rate(statsd_exporter_events_unmapped_total[5m]))` |
