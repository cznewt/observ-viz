// observ-viz blackbox_exporter pack (hand-written).
// Black-box probes from prometheus/blackbox_exporter: did the target answer
// (probe_success), how long it took and where the time went (HTTP / ICMP /
// DNS phases), what HTTP said, and when the TLS certificate runs out. Plus
// the exporter itself: build and whether its module config loaded.
//
// A probe series is keyed by `instance` (the target, after the usual
// __param_target relabel) and `job` (one scrape job per module is the common
// layout). The exporter's own series (blackbox_exporter_*) come from its
// self-scrape job, so the Exporter tab filters on cluster only.
//
//   g.libs.monitoring.blackboxExporter.new({}).grafana.dashboard
//   g.libs.monitoring.blackboxExporter.new({ ruleSelector: 'job=~"blackbox.*"' }).prometheus.alerts
//
// Metric names checked against blackbox_exporter prober/*.go (master, 2026-09).
local dashboard = import 'custom/dashboard.libsonnet';
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local annotations = import 'libs/common-lib/annotations/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-blackbox-exporter',
      dashboardTitle: 'Blackbox exporter',
      dashboardTags: ['blackbox-exporter', 'probes', 'collector', 'cluster-level'],
      description: 'Black-box probes from blackbox_exporter: availability and uptime per target, probe latency by phase (HTTP, ICMP, DNS), HTTP status, version and redirects, TLS certificate expiry and version, and the exporter itself. A row is one target (instance) probed by one module (job).',
      references: [
        { title: 'blackbox_exporter', url: 'https://github.com/prometheus/blackbox_exporter', description: 'probers, modules and the multi-target relabel pattern' },
        { title: 'Module configuration', url: 'https://github.com/prometheus/blackbox_exporter/blob/master/CONFIGURATION.md', description: 'valid_status_codes, fail_if_* regexes, TLS options' },
      ],
      datasource: '${datasource}',
      // probes: target + module
      selector: 'cluster=~"$cluster", job=~"$job", instance=~"$instance"',
      // the exporter's own series come from a different (self-scrape) job
      exporterSelector: 'cluster=~"$cluster"',
      varLabels: ['cluster', 'instance'],
      varMetric: 'probe_success',
      // firing-alert annotations: probe alerts keep job + instance
      alertSelector: 'cluster=~"$cluster", job=~"$job", instance=~"$instance"',
      // static label filter for the alerting/recording rules (no dashboard vars)
      ruleSelector: '',
      probeFailedFor: '5m',
      slowProbeSeconds: 1,
      certExpiryDaysWarning: 14,
      certExpiryDaysCritical: 7,
      httpFailureStatus: 400,
      docTabs: true,
      tabbed: true,
      // Overview instances table: one row per target / module
      rowLabels: ['instance', 'job'],
      overviewSignals: ['successRange', 'lastStatus', 'duration', 'httpCode', 'certDays'],
      folderPath: (import 'libs/common-lib/folders.libsonnet').monitoringCollectors,
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local sigWith(sel) = function(name, expr, unit, legend, desc)
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(sel).withLegendFormat(legend).withDescription(desc);
    local sig = sigWith(cfg.selector);
    local sigExp = sigWith(cfg.exporterSelector);
    local q(metric, extra='') = metric + '{%(queriesSelector)s' + extra + '}';
    local byTarget = 'by (instance, job)';

    local signals = {
      // ---- overview columns (per target / module)
      successRange: sig('Success %', 'avg ' + byTarget + ' (avg_over_time(' + q('probe_success') + '[$__range]))', 'percentunit', '{{instance}} ({{job}})',
                        'Share of probes that succeeded over the selected time range.'),
      lastStatus: sig('Last status', 'min ' + byTarget + ' (' + q('probe_success') + ')', 'short', '{{instance}} ({{job}})',
                      '1 when the latest probe succeeded, 0 when it failed.'),
      duration: sig('Probe duration', 'max ' + byTarget + ' (' + q('probe_duration_seconds') + ')', 's', '{{instance}} ({{job}})',
                    'Wall time of the whole probe, DNS lookup included. Bounded by the module timeout.'),
      httpCode: sig('HTTP status', 'max ' + byTarget + ' (' + q('probe_http_status_code') + ')', 'short', '{{instance}} ({{job}})',
                    'Status code of the last HTTP response, after redirects. 0 means no response at all.'),
      certDays: sig('Cert expiry (days)', 'min ' + byTarget + ' ((' + q('probe_ssl_earliest_cert_expiry') + ' - time()) / 86400)', 'd', '{{instance}} ({{job}})',
                    'Days until the earliest certificate in the served chain expires. Only TLS probes that completed a handshake report it.'),
      // ---- overview stats
      targets: sig('Targets', 'count(' + q('probe_success') + ')', 'short', 'targets', 'Target / module pairs being probed.'),
      failing: sig('Failing', 'count(' + q('probe_success') + ' == 0) or vector(0)', 'short', 'failing', 'Probes whose latest attempt failed.'),
      successAvg: sig('Availability', 'avg(avg_over_time(' + q('probe_success') + '[$__range]))', 'percentunit', 'availability',
                      'Average probe success across every selected target over the time range.'),
      certMin: sig('Soonest cert expiry', 'min((' + q('probe_ssl_earliest_cert_expiry') + ' - time()) / 86400)', 'd', 'soonest',
                   'Days until the first certificate among the probed targets expires.'),
      // ---- availability
      success: sig('Probe success', 'min ' + byTarget + ' (' + q('probe_success') + ')', 'short', '{{instance}} ({{job}})',
                   'Probe result over time: 1 success, 0 failure.'),
      uptime: sig('Uptime', 'avg ' + byTarget + ' (avg_over_time(' + q('probe_success') + '[$__range]))', 'percentunit', '{{instance}} ({{job}})',
                  'Share of successful probes per target over the whole time range.'),
      // ---- latency
      durationSeries: sig('Probe duration by target', 'max ' + byTarget + ' (' + q('probe_duration_seconds') + ')', 's', '{{instance}} ({{job}})',
                          'Total probe duration per target.'),
      dnsLookup: sig('DNS lookup time', 'max ' + byTarget + ' (' + q('probe_dns_lookup_time_seconds') + ')', 's', '{{instance}} ({{job}})',
                     'Time spent resolving the target name before the probe proper - every prober reports it.'),
      httpPhases: sig('HTTP duration by phase', 'avg by (phase) (' + q('probe_http_duration_seconds') + ')', 's', '{{phase}}',
                      'HTTP probe time split into resolve / connect / tls / processing / transfer, averaged over the selected targets and summed across redirects.'),
      icmpPhases: sig('ICMP duration by phase', 'avg by (phase) (' + q('probe_icmp_duration_seconds') + ')', 's', '{{phase}}',
                      'ICMP probe time split into resolve / setup / rtt, averaged over the selected targets.'),
      icmpRtt: sig('ICMP round trip', 'max ' + byTarget + ' (' + q('probe_icmp_duration_seconds', ', phase="rtt"') + ')', 's', '{{instance}} ({{job}})',
                   'Echo round-trip time per target.'),
      dnsPhases: sig('DNS probe duration by phase', 'avg by (phase) (' + q('probe_dns_duration_seconds') + ')', 's', '{{phase}}',
                     'DNS prober (module prober: dns) time split into resolve / connect / request.'),
      dnsAnswers: sig('DNS answer records', 'max ' + byTarget + ' (' + q('probe_dns_answer_rrs') + ')', 'short', '{{instance}} ({{job}})',
                      'Records in the answer section of the last DNS probe response.'),
      ipProtocol: sig('IP protocol', 'max ' + byTarget + ' (' + q('probe_ip_protocol') + ')', 'short', '{{instance}} ({{job}})',
                      'IP version the probe used (4 or 6).'),
      // ---- http
      httpCodeSeries: sig('HTTP status by target', 'max ' + byTarget + ' (' + q('probe_http_status_code') + ')', 'short', '{{instance}} ({{job}})',
                          'Final HTTP status code per target over time.'),
      httpVersion: sig('HTTP version', 'max ' + byTarget + ' (' + q('probe_http_version') + ')', 'short', '{{instance}} ({{job}})',
                       'Protocol version of the last response (1.1, 2, ...).'),
      httpSsl: sig('HTTPS', 'max ' + byTarget + ' (' + q('probe_http_ssl') + ')', 'short', '{{instance}} ({{job}})',
                   '1 when the final request after redirects used TLS.'),
      httpRedirects: sig('Redirects', 'max ' + byTarget + ' (' + q('probe_http_redirects') + ')', 'short', '{{instance}} ({{job}})',
                         'Redirects the probe followed.'),
      httpContentLength: sig('Content length', 'max ' + byTarget + ' (' + q('probe_http_content_length') + ')', 'bytes', '{{instance}} ({{job}})',
                             'Length of the response body as reported by the server; -1 when it is unknown (chunked).'),
      regexFailed: sig('Regex failures', 'max ' + byTarget + ' (' + q('probe_failed_due_to_regex') + ')', 'short', '{{instance}} ({{job}})',
                       '1 when the probe failed on a fail_if_body_* / fail_if_header_* regex - the page answered, but not with the expected content.'),
      // ---- tls
      certDaysTable: sig('Certificate expiry', 'min ' + byTarget + ' ((' + q('probe_ssl_earliest_cert_expiry') + ' - time()) / 86400)', 'd', '{{instance}} ({{job}})',
                         'Days left per target, soonest first.'),
      tlsVersion: sig('TLS version', 'max by (instance, job, version) (' + q('probe_tls_version_info') + ')', 'short', '{{instance}} {{version}}',
                      'TLS version negotiated on the last probe (label `version`).'),
      tlsVersionCount: sig('Targets by TLS version', 'count by (version) (' + q('probe_tls_version_info') + ')', 'short', '{{version}}',
                           'How many targets negotiated each TLS version. Anything below TLS 1.2 is worth finding.'),
      // ---- exporter
      version: sigExp('Exporter version', 'max by (job, instance, version) (' + q('blackbox_exporter_build_info') + ')', 'short', '{{instance}} {{version}}',
                      'Running blackbox_exporter builds.'),
      configOk: sigExp('Config loaded', 'min by (job, instance) (' + q('blackbox_exporter_config_last_reload_successful') + ')', 'short', '{{instance}}',
                       '1 when the last module config (re)load succeeded; 0 leaves the exporter probing with the previous modules.'),
      configLastOk: sigExp('Last good config load', 'max by (job, instance) (' + q('blackbox_exporter_config_last_reload_success_timestamp_seconds') + ') * 1000', 'dateTimeFromNow', '{{instance}}',
                           'When the module config last loaded successfully.'),
    };

    local upDown = [{ type: 'value', options: { '0': { text: 'DOWN', color: 'red', index: 0 }, '1': { text: 'UP', color: 'green', index: 1 } } }];
    local okMap = [{ type: 'value', options: { '0': { text: 'FAILED', color: 'red', index: 0 }, '1': { text: 'ok', color: 'green', index: 1 } } }];
    local stacked = panel.timeSeries.withFieldConfigDefaults({ custom+: { stacking: { mode: 'normal', group: 'A' }, fillOpacity: 60 } });
    local certSteps = [
      { color: 'red', value: null },
      { color: 'orange', value: cfg.certExpiryDaysCritical },
      { color: 'green', value: cfg.certExpiryDaysWarning },
    ];
    local instant(s) = s.asTableTarget();
    // a table of one instant value per target, label columns kept, value renamed
    local targetTable(s, title, valueName) =
      s.asTable(title)
      + panel.table.withTransformations([
        { id: 'organize', options: { excludeByName: { Time: true }, renameByName: { instance: 'Target', job: 'Module', Value: valueName } } },
      ]);

    local annList =
      annotations.alert.bySeverity(cfg.datasource, cfg.alertSelector);

    local built = pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 4,
        elements: {
          ov1_targets: signals.targets.asStat('Targets'),
          ov2_failing: signals.failing.asStat('Failing')
                       + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }]),
          ov3_successAvg: signals.successAvg.asStat('Availability')
                          + panel.stat.withThresholds([{ color: 'red', value: null }, { color: 'orange', value: 0.95 }, { color: 'green', value: 0.99 }]),
          ov4_certMin: signals.certMin.asStat('Soonest cert expiry') + panel.stat.withThresholds(certSteps),
        },
      },
      {
        title: 'Availability',
        width: 12,
        height: 8,
        signalKeys: ['success', 'uptime'],
        elements: {
          av1_success: signals.success.asTimeSeries('Probe success over time')
                       + panel.timeSeries.withMin(0) + panel.timeSeries.withMax(1),
          av2_uptime: panel.barGauge.new('Uptime over range per target')
                      + panel.withDescription(signals.uptime._description)
                      + panel.barGauge.withTargets([instant(signals.uptime) { spec+: { query+: { spec+: { format: 'time_series' } } } }])
                      + panel.barGauge.withUnit('percentunit')
                      + panel.barGauge.withMin(0) + panel.barGauge.withMax(1)
                      + panel.barGauge.withThresholds([{ color: 'red', value: null }, { color: 'orange', value: 0.95 }, { color: 'green', value: 0.99 }])
                      + panel.barGauge.withOptions({ orientation: 'horizontal', displayMode: 'gradient', showUnfilled: true }),
          av3_history: panel.statusHistory.new('Status history')
                       + panel.withDescription('Each cell is the probe result for one target in one time bucket: green UP, red DOWN.')
                       + panel.statusHistory.withTargets([signals.success.asTarget()])
                       + panel.statusHistory.withMappings(upDown)
                       + panel.statusHistory.withOptions({ showValue: 'never', rowHeight: 0.9 }),
        },
      },
      {
        title: 'Latency',
        width: 12,
        height: 7,
        elements: {
          durationSeries: signals.durationSeries.asTimeSeries('Probe duration by target'),
          dnsLookup: signals.dnsLookup.asTimeSeries('DNS lookup time'),
          httpPhases: signals.httpPhases.asTimeSeries('HTTP duration by phase (stacked)') + stacked,
          icmpPhases: signals.icmpPhases.asTimeSeries('ICMP duration by phase (stacked)') + stacked,
          icmpRtt: signals.icmpRtt.asTimeSeries('ICMP round trip'),
          dnsPhases: signals.dnsPhases.asTimeSeries('DNS probe duration by phase (stacked)') + stacked,
          dnsAnswers: signals.dnsAnswers.asTimeSeries('DNS answer records'),
          ipProtocol: targetTable(signals.ipProtocol, 'IP protocol', 'IP version'),
        },
      },
      {
        title: 'HTTP',
        width: 12,
        height: 7,
        elements: {
          httpCodeSeries: signals.httpCodeSeries.asTimeSeries('HTTP status by target')
                          + panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 300 }, { color: 'red', value: cfg.httpFailureStatus }])
                          + panel.timeSeries.withFieldConfigDefaults({ custom+: { thresholdsStyle: { mode: 'dashed' } } }),
          httpVersion: targetTable(signals.httpVersion, 'HTTP version', 'HTTP version'),
          httpRedirects: signals.httpRedirects.asTimeSeries('Redirects followed'),
          httpContentLength: signals.httpContentLength.asTimeSeries('Content length'),
          regexFailed: signals.regexFailed.asTimeSeries('Regex failures')
                       + panel.timeSeries.withThresholds([{ color: 'green', value: null }, { color: 'red', value: 1 }])
                       + panel.timeSeries.withFieldConfigDefaults({ custom+: { thresholdsStyle: { mode: 'dashed' } } }),
          httpSsl: targetTable(signals.httpSsl, 'HTTPS (final request)', 'TLS'),
        },
      },
      {
        title: 'TLS',
        width: 12,
        height: 9,
        elements: {
          certDaysTable: targetTable(signals.certDaysTable, 'Certificate expiry (soonest first)', 'Days left')
                         + panel.table.withThresholds(certSteps)
                         + panel.table.withOverrides([{ matcher: { id: 'byName', options: 'Days left' }, properties: [
                           { id: 'unit', value: 'd' },
                           { id: 'decimals', value: 1 },
                           { id: 'custom.cellOptions', value: { type: 'color-background', mode: 'basic' } },
                         ] }])
                         + panel.table.withOptions({ sortBy: [{ displayName: 'Days left', desc: false }] }),
          tlsVersion: targetTable(signals.tlsVersion, 'TLS version by target', 'Info')
                      + panel.table.withTransformations([
                        { id: 'organize', options: { excludeByName: { Time: true, Value: true }, renameByName: { instance: 'Target', job: 'Module', version: 'TLS version' } } },
                      ]),
          tlsVersionCount: panel.pieChart.new('Targets by TLS version')
                           + panel.withDescription(signals.tlsVersionCount._description)
                           + panel.pieChart.withTargets([signals.tlsVersionCount.asTarget()])
                           + panel.pieChart.withOptions({ reduceOptions: { calcs: ['lastNotNull'], values: false }, pieType: 'donut', legend: { displayMode: 'table', placement: 'right', values: ['value'] } }),
        },
      },
      {
        title: 'Exporter',
        width: 12,
        height: 7,
        elements: {
          version: targetTable(signals.version, 'Exporter version', 'Info')
                   + panel.table.withTransformations([
                     { id: 'organize', options: { excludeByName: { Time: true, Value: true }, renameByName: { instance: 'Exporter', job: 'Job', version: 'Version' } } },
                   ]),
          configOk: signals.configOk.asTimeSeries('Config loaded (1 ok / 0 failed)')
                    + panel.timeSeries.withMappings(okMap)
                    + panel.timeSeries.withMin(0) + panel.timeSeries.withMax(1),
          configLastOk: signals.configLastOk.asStat('Last good config load'),
        },
      },
    ], [
      alert.rule.group('blackbox-exporter', [
        alert.rule.new(
          'BlackboxProbeFailed',
          'probe_success' + rsBrace + ' == 0',
          cfg.probeFailedFor,
          'critical',
          {},
          {
            summary: 'Probe of {{ $labels.instance }} ({{ $labels.job }}) is failing.',
            description: 'blackbox_exporter cannot reach {{ $labels.instance }} with module {{ $labels.job }}, or the answer did not satisfy the module (status code, regex, TLS).',
          }
        ),
        alert.rule.new(
          'BlackboxSlowProbe',
          'avg_over_time(probe_duration_seconds' + rsBrace + '[1m]) > ' + cfg.slowProbeSeconds,
          '10m',
          'warning',
          {},
          {
            summary: 'Probe of {{ $labels.instance }} ({{ $labels.job }}) is slow.',
            description: 'The probe took {{ $value | humanizeDuration }} on average over the last minute, above ' + cfg.slowProbeSeconds + 's. The Latency tab shows which phase the time goes to.',
          }
        ),
        alert.rule.new(
          'BlackboxSslCertExpiringSoon',
          '(last_over_time(probe_ssl_earliest_cert_expiry' + rsBrace + '[10m]) - time()) / 86400 < ' + cfg.certExpiryDaysWarning
          + ' >= ' + cfg.certExpiryDaysCritical,
          '5m',
          'warning',
          {},
          {
            summary: 'TLS certificate of {{ $labels.instance }} expires in {{ printf "%.0f" $value }} days.',
            description: 'Below ' + cfg.certExpiryDaysWarning + ' days. Automated renewal (ACME / cert-manager) should normally have happened by now.',
          }
        ),
        alert.rule.new(
          'BlackboxSslCertExpiring',
          '(last_over_time(probe_ssl_earliest_cert_expiry' + rsBrace + '[10m]) - time()) / 86400 < ' + cfg.certExpiryDaysCritical,
          '5m',
          'critical',
          {},
          {
            summary: 'TLS certificate of {{ $labels.instance }} expires in {{ printf "%.1f" $value }} days.',
            description: 'Below ' + cfg.certExpiryDaysCritical + ' days. Clients will reject the endpoint once it expires.',
          }
        ),
        // a status the module accepted (valid_status_codes: [401, 403], say)
        // leaves probe_success at 1 - only a probe that failed on its status
        // is an HTTP failure
        alert.rule.new(
          'BlackboxProbeHttpFailure',
          'probe_http_status_code' + rsBrace + ' >= ' + cfg.httpFailureStatus
          + ' and on (instance, job) probe_success' + rsBrace + ' == 0',
          '5m',
          'warning',
          {},
          {
            summary: '{{ $labels.instance }} answers HTTP {{ $value }}.',
            description: 'The HTTP probe ({{ $labels.job }}) got status {{ $value }}, which the module does not accept.',
          }
        ),
        alert.rule.new(
          'BlackboxConfigReloadFailed',
          'blackbox_exporter_config_last_reload_successful' + rsBrace + ' == 0',
          '10m',
          'warning',
          {},
          {
            summary: 'blackbox_exporter {{ $labels.instance }} failed to load its config.',
            description: 'The last module config reload failed; the exporter keeps probing with the previous modules, so new or changed modules are not in effect.',
          }
        ),
      ]),
    ], [
      alert.rule.group('blackbox-exporter.rules', [
        alert.rule.record('instance:probe_success:avg_over_time1h', 'avg_over_time(probe_success' + rsBrace + '[1h])'),
        alert.rule.record('instance:probe_duration_seconds:avg_over_time5m', 'avg_over_time(probe_duration_seconds' + rsBrace + '[5m])'),
        alert.rule.record('instance:probe_ssl_earliest_cert_expiry:days', '(probe_ssl_earliest_cert_expiry' + rsBrace + ' - time()) / 86400'),
      ]),
    ]);
    built {
      grafana+: { dashboard: super.dashboard + dashboard.withAnnotationsMixin(annList) },
    },
}
