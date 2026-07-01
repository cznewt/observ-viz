// observ-viz guardian pack (hand-written).
// Dashboards for the `guardian` Salt formula (device supervision / parental
// control). Guardian ships two kinds of signal into Prometheus (Mimir) via the
// host's alloy textfile collector:
//   KNOW   : guardian_installed_apps{source}  + guardian_inventory_timestamp_seconds
//   CONTROL: guardian_usage_minutes{user} (Windows) / guardian_user_connect_minutes{user} (Debian)
//            — only present once the control half is enabled.
// Usage:
//   g.libs.applications.guardian.new({ selector: 'job=~"$job"' }).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-guardian',
      dashboardTitle: 'Guardian — device supervision',
      dashboardTags: ['guardian', 'parental-control', 'inventory'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      // present on every guardian host, so it drives the $job/$instance vars.
      varMetric: 'guardian_installed_apps',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);

    local signals = {
      // KNOW — inventory
      appsTotal: sig('Installed apps', 'sum by (instance)(guardian_installed_apps{%(queriesSelector)s})', 'short'),
      appsBySource: sig('Installed apps by source', 'sum by (instance, source)(guardian_installed_apps{%(queriesSelector)s})', 'short'),
      hosts: sig('Reporting hosts', 'count(group by (instance)(guardian_installed_apps{%(queriesSelector)s}))', 'short'),
      inventoryAge: sig('Inventory age', 'time() - max by (instance)(guardian_inventory_timestamp_seconds{%(queriesSelector)s})', 's'),
      // CONTROL — usage (empty until the control half is enabled)
      usageMinutes: sig('Daily usage', 'max by (instance, user)(guardian_usage_minutes{%(queriesSelector)s})', 'm'),
      connectMinutes: sig('Connect minutes', 'max by (instance, user)(guardian_user_connect_minutes{%(queriesSelector)s})', 'm'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 4,
        height: 6,
        elements: {
          hosts: signals.hosts.asStat('Reporting hosts'),
          appsTotal: signals.appsTotal.asStat('Installed apps'),
          inventoryAge: signals.inventoryAge.asStat('Oldest inventory age'),
        },
      },
      {
        title: 'Installed applications',
        width: 12,
        height: 8,
        elements: {
          appsBySource: signals.appsBySource.asTable('Installed apps by host / source'),
        },
      },
      {
        title: 'Inventory freshness',
        width: 12,
        height: 7,
        elements: {
          inventoryAge: signals.inventoryAge.asTimeSeries('Time since last inventory run'),
        },
      },
      {
        title: 'Usage — CONTROL half (empty unless enabled)',
        width: 12,
        height: 7,
        elements: {
          usageMinutes: signals.usageMinutes.asTimeSeries('Daily active minutes per user (Windows)'),
          connectMinutes: signals.connectMinutes.asTimeSeries('Connect minutes per user (Debian)'),
        },
      },
    ], [
      // alerting rule group
      alert.rule.group('guardian', [
        alert.rule.new(
          'GuardianInventoryStale',
          '(time() - guardian_inventory_timestamp_seconds' + rsBrace + ') > 129600',
          '1h',
          'warning',
          {},
          { summary: 'Guardian inventory on {{ $labels.instance }} is stale (>36h) — the inventory timer/task may not be running.' }
        ),
      ]),
    ], [
      // recording rule group
      alert.rule.group('guardian.rules', [
        alert.rule.record('instance:guardian_installed_apps:sum', 'sum by (instance) (guardian_installed_apps' + rsBrace + ')'),
      ]),
    ]),
}
