# Blackbox exporter  (`g.libs.monitoring.blackboxExporter`)

Dashboard uid `observ-viz-blackbox-exporter` · 31 signals · 6 alerts · 3 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `certDays` | d | `min by (instance, job) ((probe_ssl_earliest_cert_expiry{cluster=~"$cluster", job=~"$job", instance=~"$instance"} - time()) / 86400)` | — |
| `certDaysTable` | d | `min by (instance, job) ((probe_ssl_earliest_cert_expiry{cluster=~"$cluster", job=~"$job", instance=~"$instance"} - time()) / 86400)` | — |
| `certMin` | d | `min((probe_ssl_earliest_cert_expiry{cluster=~"$cluster", job=~"$job", instance=~"$instance"} - time()) / 86400)` | — |
| `configLastOk` | dateTimeFromNow | `max by (job, instance) (blackbox_exporter_config_last_reload_success_timestamp_seconds{cluster=~"$cluster"}) * 1000` | — |
| `configOk` | short | `min by (job, instance) (blackbox_exporter_config_last_reload_successful{cluster=~"$cluster"})` | — |
| `dnsAnswers` | short | `max by (instance, job) (probe_dns_answer_rrs{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `dnsLookup` | s | `max by (instance, job) (probe_dns_lookup_time_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `dnsPhases` | s | `avg by (phase) (probe_dns_duration_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `duration` | s | `max by (instance, job) (probe_duration_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `durationSeries` | s | `max by (instance, job) (probe_duration_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `failing` | short | `count(probe_success{cluster=~"$cluster", job=~"$job", instance=~"$instance"} == 0) or vector(0)` | — |
| `httpCode` | short | `max by (instance, job) (probe_http_status_code{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `httpCodeSeries` | short | `max by (instance, job) (probe_http_status_code{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `httpContentLength` | bytes | `max by (instance, job) (probe_http_content_length{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `httpPhases` | s | `avg by (phase) (probe_http_duration_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `httpRedirects` | short | `max by (instance, job) (probe_http_redirects{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `httpSsl` | short | `max by (instance, job) (probe_http_ssl{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `httpVersion` | short | `max by (instance, job) (probe_http_version{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `icmpPhases` | s | `avg by (phase) (probe_icmp_duration_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `icmpRtt` | s | `max by (instance, job) (probe_icmp_duration_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance", phase="rtt"})` | — |
| `ipProtocol` | short | `max by (instance, job) (probe_ip_protocol{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `lastStatus` | short | `min by (instance, job) (probe_success{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `regexFailed` | short | `max by (instance, job) (probe_failed_due_to_regex{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `success` | short | `min by (instance, job) (probe_success{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `successAvg` | percentunit | `avg(avg_over_time(probe_success{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__range]))` | — |
| `successRange` | percentunit | `avg by (instance, job) (avg_over_time(probe_success{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__range]))` | — |
| `targets` | short | `count(probe_success{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `tlsVersion` | short | `max by (instance, job, version) (probe_tls_version_info{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `tlsVersionCount` | short | `count by (version) (probe_tls_version_info{cluster=~"$cluster", job=~"$job", instance=~"$instance"})` | — |
| `uptime` | percentunit | `avg by (instance, job) (avg_over_time(probe_success{cluster=~"$cluster", job=~"$job", instance=~"$instance"}[$__range]))` | — |
| `version` | short | `max by (job, instance, version) (blackbox_exporter_build_info{cluster=~"$cluster"})` | — |

## Dashboard

- **Overview** — `ov1_targets`, `ov2_failing`, `ov3_successAvg`, `ov4_certMin`
- **Availability** — `av1_success`, `av2_uptime`, `av3_history`
- **Latency** — `dnsAnswers`, `dnsLookup`, `dnsPhases`, `durationSeries`, `httpPhases`, `icmpPhases`, `icmpRtt`, `ipProtocol`
- **HTTP** — `httpCodeSeries`, `httpContentLength`, `httpRedirects`, `httpSsl`, `httpVersion`, `regexFailed`
- **TLS** — `certDaysTable`, `tlsVersion`, `tlsVersionCount`
- **Exporter** — `configLastOk`, `configOk`, `version`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `BlackboxProbeFailed` | critical | 5m | — |
| `BlackboxSlowProbe` | warning | 10m | — |
| `BlackboxSslCertExpiringSoon` | warning | 5m | — |
| `BlackboxSslCertExpiring` | critical | 5m | — |
| `BlackboxProbeHttpFailure` | warning | 5m | — |
| `BlackboxConfigReloadFailed` | warning | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:probe_success:avg_over_time1h` | `avg_over_time(probe_success[1h])` |
| `instance:probe_duration_seconds:avg_over_time5m` | `avg_over_time(probe_duration_seconds[5m])` |
| `instance:probe_ssl_earliest_cert_expiry:days` | `(probe_ssl_earliest_cert_expiry - time()) / 86400` |
