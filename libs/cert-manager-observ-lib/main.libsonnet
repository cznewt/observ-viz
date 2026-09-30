// observ-viz cert-manager pack (hand-written).
// Built for cert-manager's controller metrics (certmanager_*, :9402): per
// Certificate expiry / readiness, ClusterIssuer readiness, ACME client
// requests and controller sync. Alerts ported from the service catalog's
// cert-manager-mixin (CertManagerCertExpirySoon, CertManagerCertNotReady,
// CertManagerHittingRateLimits); its absent()-based CertManagerAbsent becomes
// CertManagerDown on the shared targetDown pattern (one cluster missing
// cert-manager does not hide behind another that has it), plus a
// ClusterIssuer-not-ready alert.
// Usage:
//   g.libs.kubernetes.certManager.new({ ruleSelector: 'job=~".*cert-manager.*"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-cert-manager',
      dashboardTitle: 'cert-manager',
      // Platform / Kubernetes
      folderPath: (import 'libs/common-lib/folders.libsonnet').kubernetes,
      dashboardTags: ['cert-manager', 'certificates', 'tls', 'kubernetes', 'app-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      // controller / ACME series live in cert-manager's namespace; the
      // certificate series carry the Certificate's namespace, filtered by
      // $namespace on top of this selector
      selector: 'job=~"$job", cluster=~"$cluster"',
      varMetric: 'certmanager_certificate_expiration_timestamp_seconds',
      varLabels: ['cluster', 'namespace'],
      ruleSelector: '',
      certExpiryDays: 21,
    } + config;

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local ns = 'namespace=~"$namespace", ';

    local sig(name, expr, unit, legend='{{namespace}}/{{name}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      // overview
      certificates: sig('Certificates', 'count(certmanager_certificate_expiration_timestamp_seconds{' + ns + '%(queriesSelector)s})', 'short', 'certificates'),
      notReady: sig('Not ready', 'count(certmanager_certificate_ready_status{condition!="True", ' + ns + '%(queriesSelector)s} == 1) or vector(0)', 'short', 'not ready'),
      expiringSoon: sig('Expiring soon', 'count((certmanager_certificate_expiration_timestamp_seconds{' + ns + '%(queriesSelector)s} - time()) < ' + (cfg.certExpiryDays * 86400) + ') or vector(0)', 'short', 'expiring'),
      soonest: sig('Soonest expiry', 'min((certmanager_certificate_expiration_timestamp_seconds{' + ns + '%(queriesSelector)s} - time()) / 86400)', 'd', 'soonest'),
      issuersNotReady: sig('ClusterIssuers not ready', 'count(certmanager_clusterissuer_ready_status{condition!="True", %(queriesSelector)s} == 1) or vector(0)', 'short', 'not ready'),
      challengesPending: sig('Challenges not valid', 'count(certmanager_certificate_challenge_status{status!="valid", ' + ns + '%(queriesSelector)s} == 1) or vector(0)', 'short', 'not valid'),
      // certificates over time
      daysLeft: sig('Days until expiry', '(certmanager_certificate_expiration_timestamp_seconds{' + ns + '%(queriesSelector)s} - time()) / 86400', 'd'),
      readyState: sig('Ready', 'max by (namespace, name) (certmanager_certificate_ready_status{condition="True", ' + ns + '%(queriesSelector)s})', 'short'),
      // controller + ACME
      syncCalls: sig('Sync calls', 'sum by (controller) (rate(certmanager_controller_sync_call_count{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{controller}}'),
      syncErrors: sig('Sync errors', 'sum by (controller) (rate(certmanager_controller_sync_error_count{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{controller}} errors'),
      acmeByStatus: sig('ACME requests', 'sum by (status) (rate(certmanager_http_acme_client_request_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{status}}'),
      acmeByAction: sig('ACME requests by action', 'sum by (action) (rate(certmanager_http_acme_client_request_count{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{action}}'),
      acmeLatency: sig('ACME request latency', 'sum by (action) (rate(certmanager_http_acme_client_request_duration_seconds_sum{%(queriesSelector)s}[$__rate_interval])) / sum by (action) (rate(certmanager_http_acme_client_request_duration_seconds_count{%(queriesSelector)s}[$__rate_interval]))', 's', '{{action}}'),
    };

    // one row per Certificate: expiry, issuer, readiness - joined on
    // namespace|name (as the Syncthing folders table)
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local jk = '"key", "|", "cluster", "namespace", "name"';
    local sel = ns + cfg.selector;
    local certsTable =
      panel.table.new('Certificates')
      + panel.table.withTargets([
        tq('min by (key, cluster, namespace, name, issuer_name, issuer_kind) (label_join((certmanager_certificate_expiration_timestamp_seconds{' + sel + '} - time()) / 86400, ' + jk + '))'),  // A
        tq('max by (key) (label_join(certmanager_certificate_ready_status{condition="True", ' + sel + '}, ' + jk + '))'),  // B
        tq('max by (key) (label_join(certmanager_certificate_renewal_timestamp_seconds{' + sel + '} * 1000, ' + jk + '))'),  // C
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: ['key', 'cluster', 'namespace', 'name', 'issuer_name', 'issuer_kind', 'Value #A', 'Value #B', 'Value #C'] } } },
        { id: 'seriesToColumns', options: { byField: 'key' } },
        { id: 'organize', options: {
          excludeByName: { key: true },
          indexByName: { cluster: 0, namespace: 1, name: 2, issuer_kind: 3, issuer_name: 4, 'Value #A': 5, 'Value #C': 6, 'Value #B': 7, key: 8 },
          renameByName: { cluster: 'Cluster', namespace: 'Namespace', name: 'Certificate', issuer_kind: 'Issuer kind', issuer_name: 'Issuer', 'Value #A': 'Expires in', 'Value #C': 'Renews', 'Value #B': 'Ready' },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Expires in', desc: false }] } },
      ])
      + panel.table.withOverrides([
        ov('^Expires in$', [
          { id: 'unit', value: 'd' },
          { id: 'decimals', value: 0 },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'red', value: null }, { color: 'orange', value: 7 }, { color: 'green', value: cfg.certExpiryDays }] } },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
          { id: 'custom.width', value: 110 },
        ]),
        ov('^Renews$', [{ id: 'unit', value: 'dateTimeFromNow' }, { id: 'custom.width', value: 130 }]),
        ov('^Ready$', [
          { id: 'custom.width', value: 90 },
          { id: 'mappings', value: [{ type: 'value', options: { '1': { text: 'ready', color: 'green' }, '0': { text: 'NOT READY', color: 'red' } } }] },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ]),
      ]);

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 5,
        elements: {
          a_certs: signals.certificates.asStat('Certificates'),
          b_notReady: signals.notReady.asStat('Not ready'),
          c_expiring: signals.expiringSoon.asStat('Expiring < ' + cfg.certExpiryDays + ' d'),
          d_soonest: signals.soonest.asStat('Soonest expiry'),
          e_issuers: signals.issuersNotReady.asStat('ClusterIssuers not ready'),
          f_challenges: signals.challengesPending.asStat('Challenges not valid'),
        },
      },
      { title: 'Certificates', width: 24, height: 10, elements: { certsTable: certsTable } },
      {
        title: 'Expiry',
        width: 24,
        height: 8,
        elements: { a_days: signals.daysLeft.asTimeSeries('Days until expiry') },
      },
      {
        title: 'Controller & ACME',
        width: 12,
        height: 7,
        elements: {
          a_sync: signals.syncCalls.asTimeSeries('Controller syncs')
                  + panel.withTargetsMixin([signals.syncErrors.asTarget()]),
          b_acme: signals.acmeByStatus.asTimeSeries('ACME requests by status'),
          c_action: signals.acmeByAction.asTimeSeries('ACME requests by action'),
          d_latency: signals.acmeLatency.asTimeSeries('ACME request latency'),
        },
      },
    ], [
      alert.rule.group('cert-manager', [
        alert.rule.new(
          'CertManagerDown',
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('certmanager_clock_time_seconds', cfg.ruleSelector),
          '10m',
          'critical',
          {},
          { summary: 'cert-manager is down.', description: 'cert-manager {{ $labels.instance }} has disappeared from target discovery - no certificate is being issued or renewed.' }
        ),
        alert.rule.new(
          'CertManagerCertExpirySoon',
          'certmanager_certificate_expiration_timestamp_seconds' + rs + ' - time() < ' + (cfg.certExpiryDays * 86400),
          '1h',
          'warning',
          {},
          { summary: 'A certificate expires soon.', description: 'Certificate {{ $labels.namespace }}/{{ $labels.name }} expires in {{ $value | humanizeDuration }} and has not been renewed.' }
        ),
        alert.rule.new(
          'CertManagerCertNotReady',
          'max by (cluster, namespace, name) (certmanager_certificate_ready_status{condition!="True"' + rsComma + '}) == 1',
          '10m',
          'critical',
          {},
          { summary: 'A certificate is not ready.', description: 'Certificate {{ $labels.namespace }}/{{ $labels.name }} has not been ready to serve traffic for at least 10m.' }
        ),
        alert.rule.new(
          'CertManagerClusterIssuerNotReady',
          'certmanager_clusterissuer_ready_status{condition!="True"' + rsComma + '} == 1',
          '10m',
          'warning',
          {},
          { summary: 'A ClusterIssuer is not ready.', description: 'ClusterIssuer {{ $labels.name }} is not ready - certificates it signs cannot be issued or renewed.' }
        ),
        alert.rule.new(
          'CertManagerHittingRateLimits',
          'sum by (cluster, host) (rate(certmanager_http_acme_client_request_count{status="429"' + rsComma + '}[5m])) > 0',
          '5m',
          'critical',
          {},
          { summary: 'cert-manager is hitting ACME rate limits.', description: 'The ACME server {{ $labels.host }} answers 429 - depending on the limit, cert-manager may be unable to issue certificates for up to a week.' }
        ),
      ]),
    ]),
}
