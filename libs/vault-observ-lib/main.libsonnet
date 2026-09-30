// observ-viz Vault pack (hand-written) - HashiCorp Vault and OpenBao.
// Built for the Prometheus telemetry at /v1/sys/metrics?format=prometheus
// (vault_* - OpenBao keeps Vault's metric names). The endpoint needs that query
// parameter, so the collector scrapes it explicitly (gedu-prg: alloy-metrics
// extraConfig, job="openbao").
// A sealed server exports little beyond vault_core_unsealed, the barrier and
// the Go runtime; the request and token/lease tabs appear once their metrics do.
// Usage:
//   g.libs.cicd.vault.new({ selector: 'job="openbao"' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-vault',
      dashboardTitle: 'Vault',
      // Platform / Configuration
      folderPath: (import 'libs/common-lib/folders.libsonnet').configuration,
      dashboardTags: ['vault', 'openbao', 'secrets', 'app-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      selector: 'job=~"$job", cluster=~"$cluster", instance=~"$instance"',
      varMetric: 'vault_core_unsealed',
      varLabels: ['cluster', 'instance'],
      ruleSelector: '',
    } + config;

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';

    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);
    // summaries are in milliseconds, one series per quantile
    local p99(m, legend) = sig(legend, 'max by (instance) (' + m + '{quantile="0.99", %(queriesSelector)s})', 'ms', '{{instance}} ' + legend);
    local ops(m, legend) = sig(legend, 'sum by (instance) (rate(' + m + '_count{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{instance}} ' + legend);

    local signals = {
      // overview
      sealed: sig('Sealed', 'count(vault_core_unsealed{%(queriesSelector)s} == 0) or vector(0)', 'short', 'sealed'),
      unsealed: sig('Unsealed', 'sum(vault_core_unsealed{%(queriesSelector)s})', 'short', 'unsealed'),
      active: sig('Active', 'sum(vault_core_active{%(queriesSelector)s}) or vector(0)', 'short', 'active'),
      uptime: sig('Uptime', 'time() - max(process_start_time_seconds{%(queriesSelector)s})', 's', 'uptime'),
      sealState: sig('Seal state', 'vault_core_unsealed{%(queriesSelector)s}', 'short', '{{instance}} unsealed'),
      // runtime
      allocBytes: sig('Heap allocated', 'vault_runtime_alloc_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} allocated'),
      sysBytes: sig('Memory from the OS', 'vault_runtime_sys_bytes{%(queriesSelector)s}', 'bytes', '{{instance}} from the OS'),
      goroutines: sig('Goroutines', 'vault_runtime_num_goroutines{%(queriesSelector)s}', 'short'),
      gcPause: sig('GC pause p99', 'max by (instance) (vault_runtime_gc_pause_ns{quantile="0.99", %(queriesSelector)s})', 'ns'),
      // barrier (the encryption layer over storage): latency and rate per operation
      barrierGet: p99('vault_barrier_get', 'get'),
      barrierPut: p99('vault_barrier_put', 'put'),
      barrierList: p99('vault_barrier_list', 'list'),
      barrierDelete: p99('vault_barrier_delete', 'delete'),
      barrierGetOps: ops('vault_barrier_get', 'get'),
      barrierPutOps: ops('vault_barrier_put', 'put'),
      // requests (unsealed only)
      requests: ops('vault_core_handle_request', 'requests'),
      logins: ops('vault_core_handle_login_request', 'logins'),
      requestP99: p99('vault_core_handle_request', 'request p99'),
      loginP99: p99('vault_core_handle_login_request', 'login p99'),
      auditFailures: sig('Audit log failures', 'sum by (instance) (increase({__name__=~"vault_audit_log_(request|response)_failure", %(queriesSelector)s}[$__rate_interval]))', 'short'),
      // tokens and leases (unsealed only)
      leases: sig('Leases', 'sum by (instance) (vault_expire_num_leases{%(queriesSelector)s})', 'short', '{{instance}} leases'),
      irrevocable: sig('Irrevocable leases', 'sum by (instance) (vault_expire_num_irrevocable_leases{%(queriesSelector)s})', 'short', '{{instance}} irrevocable'),
      tokensByAuth: sig('Tokens by auth method', 'sum by (auth_method) (vault_token_count{%(queriesSelector)s})', 'short', '{{auth_method}}'),
      tokenCreation: sig('Tokens created', 'sum by (instance) (rate(vault_token_creation{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{instance}} created'),
    };

    local presence(metrics) = { label: 'job', query: '{__name__=~"' + std.join('|', metrics) + '", job=~"$job"}' };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 6,
        height: 5,
        elements: {
          a_sealed: signals.sealed.asStat('Sealed'),
          b_unsealed: signals.unsealed.asStat('Unsealed'),
          c_active: signals.active.asStat('Active'),
          d_uptime: signals.uptime.asStat('Uptime'),
        },
      },
      {
        title: 'Seal state & runtime',
        width: 12,
        height: 7,
        elements: {
          a_seal: signals.sealState.asTimeSeries('Unsealed (1) / sealed (0)'),
          b_memory: signals.allocBytes.asTimeSeries('Memory')
                    + panel.withTargetsMixin([signals.sysBytes.asTarget()]),
          c_goroutines: signals.goroutines.asTimeSeries('Goroutines'),
          d_gc: signals.gcPause.asTimeSeries('GC pause (p99)'),
        },
      },
      {
        title: 'Barrier',
        width: 12,
        height: 7,
        elements: {
          a_latency: signals.barrierGet.asTimeSeries('Barrier latency (p99)')
                     + panel.withTargetsMixin([signals.barrierPut.asTarget(), signals.barrierList.asTarget(), signals.barrierDelete.asTarget()]),
          b_ops: signals.barrierGetOps.asTimeSeries('Barrier operations')
                 + panel.withTargetsMixin([signals.barrierPutOps.asTarget()]),
        },
      },
    ], [
      alert.rule.group('vault', [
        alert.rule.new(
          'VaultDown',
          (import 'libs/common-lib/alert/rule.libsonnet').targetDown('vault_core_unsealed', cfg.ruleSelector),
          '5m',
          'critical',
          {},
          { summary: 'Vault metrics endpoint {{ $labels.instance }} is down.' }
        ),
        alert.rule.new(
          'VaultSealed',
          'vault_core_unsealed' + rs + ' == 0',
          '5m',
          'critical',
          {},
          {
            summary: 'Vault is sealed.',
            description: 'Vault {{ $labels.instance }} in {{ $labels.cluster }}/{{ $labels.namespace }} is sealed and serves no secrets until it is unsealed.',
          }
        ),
        alert.rule.new(
          'VaultAuditLogFailures',
          'sum by (cluster, namespace, instance) (increase({__name__=~"vault_audit_log_(request|response)_failure"' + rsComma + '}[5m])) > 0',
          '1m',
          'critical',
          {},
          {
            summary: 'Vault cannot write its audit log.',
            description: 'Vault {{ $labels.instance }} failed to write {{ $value }} audit entries in 5 minutes; with every audit device failing it blocks requests.',
          }
        ),
      ]),
    ], [], [
      {
        title: 'Requests',
        presence: presence(['vault_core_handle_request_count']),
        width: 12,
        height: 7,
        elements: {
          a_rate: signals.requests.asTimeSeries('Requests')
                  + panel.withTargetsMixin([signals.logins.asTarget()]),
          b_latency: signals.requestP99.asTimeSeries('Request latency (p99)')
                     + panel.withTargetsMixin([signals.loginP99.asTarget()]),
          c_audit: signals.auditFailures.asTimeSeries('Audit log failures'),
        },
      },
      {
        title: 'Tokens & leases',
        presence: presence(['vault_expire_num_leases', 'vault_token_count']),
        width: 12,
        height: 7,
        elements: {
          a_leases: signals.leases.asTimeSeries('Leases')
                    + panel.withTargetsMixin([signals.irrevocable.asTarget()]),
          b_tokens: signals.tokensByAuth.asTimeSeries('Tokens by auth method'),
          c_creation: signals.tokenCreation.asTimeSeries('Tokens created'),
        },
      },
    ]),
}
