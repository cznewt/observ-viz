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
local panel = import 'custom/panel.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-guardian',
      dashboardTitle: 'Guardian — device supervision',
      dashboardTags: ['guardian', 'parental-control', 'inventory', 'activity'],
      datasource: '${datasource}',
      selector: 'job=~"$job"',
      // present on every guardian host, so it drives the $job/$instance vars.
      varMetric: 'guardian_installed_apps',
      // static label filter for the alerting/recording rules (no dashboard vars).
      ruleSelector: '',
      // guardian JSONL -> Loki carries service_name="guardian" (activity titles + inventory).
      lokiDatasource: true,
      logsSelector: 'service_name="guardian"',
    } + config;
    local rsBrace = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';

    local sig(name, expr, unit) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector);
    local lsig(name, expr) =
      signal.new(name, 'loki', '${loki_datasource}', expr, 'short').filteringSelector(cfg.logsSelector);

    // click a kid's row (user column) -> the per-kid drill-down board, pre-filled.
    local kidUid = cfg.uid + '-kid';
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local kidLink = panel.table.withOverrides([
      ov('^user$', [{ id: 'links', value: [{
        title: 'Drill into ${__value.raw}',
        url: '/d/' + kidUid + '?var-instance=${__data.fields["instance"]}&var-user=${__value.raw}&${datasource:queryparam}',
      }] }]),
    ]);

    local signals = {
      // KNOW — inventory
      appsTotal: sig('Installed apps', 'sum by (instance)(guardian_installed_apps{%(queriesSelector)s})', 'short'),
      appsBySource: sig('Installed apps by source', 'sum by (instance, source)(guardian_installed_apps{%(queriesSelector)s})', 'short'),
      hosts: sig('Reporting hosts', 'count(group by (instance)(guardian_installed_apps{%(queriesSelector)s}))', 'short'),
      inventoryAge: sig('Inventory age', 'time() - max by (instance)(guardian_inventory_timestamp_seconds{%(queriesSelector)s})', 's'),
      // KNOW — activity / on-screen (Windows usage tracker; empty until monitor.usage runs)
      foregroundByApp: sig('Screen time by app', 'sum by (instance, user, app)(guardian_app_foreground_seconds{%(queriesSelector)s})', 's'),
      runningByApp: sig('Running time by app', 'sum by (instance, user, app)(guardian_app_running_seconds{%(queriesSelector)s})', 's'),
      appsRunning: sig('Apps running', 'max by (instance, user)(guardian_apps_running{%(queriesSelector)s})', 'short'),
      foregroundNow: sig('On screen now', 'max by (instance, user, app)(guardian_foreground_app{%(queriesSelector)s})', 'short'),
      // KNOW — on-screen window titles (the actual content) via Loki
      foregroundTitles: lsig('On screen — window titles', '{%(queriesSelector)s} | json | kind="activity" | foreground_title != "" | line_format "{{.user}} / {{.foreground_app}} / {{.foreground_title}} ({{.running_count}} running)"'),
      // KNOW — web/browsing
      webByDomain: sig('Top domains', 'sum by (instance, user, domain)(guardian_web_visits{%(queriesSelector)s})', 'short'),
      webTitles: lsig('Web visits', '{%(queriesSelector)s} | json | kind="web" | line_format "{{.user}} / {{.domain}} / {{.title}}"'),
      // KNOW — attention (idle vs active)
      activeSeconds: sig('Active', 'max by (instance, user)(guardian_active_seconds{%(queriesSelector)s})', 's'),
      idleSeconds: sig('Idle', 'max by (instance, user)(guardian_idle_seconds{%(queriesSelector)s})', 's'),
      // KNOW — self-integrity + Windows Security events
      integrity: sig('Integrity', 'min by (instance, check)(guardian_integrity{%(queriesSelector)s})', 'short'),
      securityEvents: signal.new('Security events', 'loki', '${loki_datasource}', '{%(queriesSelector)s}', 'short').filteringSelector('service_name="windows", channel="Security"'),
      // CONTROL — usage (empty until the control half is enabled)
      usageMinutes: sig('Daily usage', 'max by (instance, user)(guardian_usage_minutes{%(queriesSelector)s})', 'm'),
      connectMinutes: sig('Connect minutes', 'max by (instance, user)(guardian_user_connect_minutes{%(queriesSelector)s})', 'm'),
    };

    local main = pack.build(cfg, signals, [
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
        title: 'On screen — activity (Windows)',
        width: 12,
        height: 8,
        elements: {
          foregroundByApp: signals.foregroundByApp.asTable('Screen time today by app (focused)') + kidLink,
          runningByApp: signals.runningByApp.asTable('Running time today by app') + kidLink,
        },
      },
      {
        title: 'Concurrency & current focus',
        width: 12,
        height: 7,
        elements: {
          appsRunning: signals.appsRunning.asTimeSeries('Apps running at once, per user'),
          foregroundNow: signals.foregroundNow.asTable('Currently on screen (app = 1)') + kidLink,
        },
      },
      {
        title: 'On screen — window titles (Loki)',
        width: 24,
        height: 9,
        elements: {
          titles: panel.logs.new('On-screen window titles (live, per user)') + panel.logs.withTargets([signals.foregroundTitles.asTarget()]),
        },
      },
      {
        title: 'Web / browsing',
        width: 12,
        height: 8,
        elements: {
          domains: signals.webByDomain.asTable('Top domains today (visits)') + kidLink,
          visits: panel.logs.new('Recent web visits (URL / title)') + panel.logs.withTargets([signals.webTitles.asTarget()]),
        },
      },
      {
        title: 'Attention (active vs idle)',
        width: 12,
        height: 7,
        elements: {
          active: signals.activeSeconds.asTimeSeries('Active seconds today'),
          idle: signals.idleSeconds.asTimeSeries('Idle seconds today'),
        },
      },
      {
        title: 'Security & circumvention',
        width: 12,
        height: 8,
        elements: {
          integrity: signals.integrity.asTable('Guardian integrity (1 = ok)'),
          events: panel.logs.new('Windows Security events (logons / admin / clock / log-cleared)') + panel.logs.withTargets([signals.securityEvents.asTarget()]),
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
    ]);

    // ── per-kid drill-down board (instance -> user cascade, activity only) ──
    local kidCfg = cfg {
      uid: kidUid,
      dashboardTitle: 'Guardian — kid drill-down',
      dashboardTags: ['guardian', 'parental-control', 'activity', 'drilldown'],
      // guardian_app_running_seconds carries job + instance + user, so it drives
      // the $job/$instance/$user cascade; single-select to pin one kid + box.
      varMetric: 'guardian_app_running_seconds',
      varLabels: ['instance', 'user'],
      varMulti: false,
      selector: 'instance=~"$instance", user=~"$user"',
      logsSelector: 'service_name="guardian", instance=~"$instance"',
    };
    local ksig(name, expr, unit) =
      signal.new(name, 'prometheus', kidCfg.datasource, expr, unit).filteringSelector(kidCfg.selector);
    local klsig(name, expr) =
      signal.new(name, 'loki', '${loki_datasource}', expr, 'short').filteringSelector(kidCfg.logsSelector);
    local kidSignals = {
      kApps: ksig('Apps running', 'max(guardian_apps_running{%(queriesSelector)s})', 'short'),
      kTotal: ksig('Screen time today', 'sum(guardian_app_foreground_seconds{%(queriesSelector)s})', 's'),
      kScreenByApp: ksig('Screen time by app', 'sum by (app)(guardian_app_foreground_seconds{%(queriesSelector)s})', 's'),
      kRuntimeByApp: ksig('Runtime by app', 'sum by (app)(guardian_app_running_seconds{%(queriesSelector)s})', 's'),
      kFocusNow: ksig('On screen now', 'guardian_foreground_app{%(queriesSelector)s} == 1', 'short'),
      kTitles: klsig('On-screen titles', '{%(queriesSelector)s} | json | kind="activity" | user="$user" | line_format "{{.foreground_app}} - {{.foreground_title}}"'),
      kActive: ksig('Active', 'max(guardian_active_seconds{%(queriesSelector)s})', 's'),
      kWebByDomain: ksig('Top domains', 'sum by (domain)(guardian_web_visits{%(queriesSelector)s})', 'short'),
      kWebTitles: klsig('Web visits', '{%(queriesSelector)s} | json | kind="web" | user="$user" | line_format "{{.domain}} / {{.title}}"'),
    };
    local kid = pack.build(kidCfg, kidSignals, [
      {
        title: 'This kid — now',
        width: 6,
        height: 6,
        elements: {
          apps: kidSignals.kApps.asStat('Apps running now'),
          total: kidSignals.kTotal.asStat('Screen time today'),
          active: kidSignals.kActive.asStat('Active today'),
          focus: kidSignals.kFocusNow.asTable('On screen now'),
        },
      },
      {
        title: 'Screen time & runtime by app',
        width: 12,
        height: 9,
        elements: {
          screen: kidSignals.kScreenByApp.asTable('Screen time today by app (focused)'),
          runtime: kidSignals.kRuntimeByApp.asTable('Runtime today by app'),
        },
      },
      {
        title: 'Over time',
        width: 12,
        height: 7,
        elements: {
          screen: kidSignals.kScreenByApp.asTimeSeries('Foreground seconds by app'),
          apps: kidSignals.kApps.asTimeSeries('Apps running at once'),
        },
      },
      {
        title: 'Web / browsing (this kid)',
        width: 12,
        height: 8,
        elements: {
          domains: kidSignals.kWebByDomain.asTable('Top domains today'),
          visits: panel.logs.new('Recent web visits') + panel.logs.withTargets([kidSignals.kWebTitles.asTarget()]),
        },
      },
      {
        title: 'On screen — window titles (this kid)',
        width: 24,
        height: 10,
        elements: {
          titles: panel.logs.new('On-screen window titles') + panel.logs.withTargets([kidSignals.kTitles.asTarget()]),
        },
      },
    ], [], []);

    // expose both boards; render-lib emits every entry in grafana.dashboards.
    main {
      grafana+: {
        dashboards: {
          [cfg.uid + '.json']: main.grafana.dashboard,
          [kidCfg.uid + '.json']: kid.grafana.dashboard,
        },
      },
    },
}
