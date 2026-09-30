// observ-viz WordPress pack (hand-written).
// WordPress is PHP behind a web server with a MySQL/MariaDB database, and no
// single exporter covers it. This board joins every source the site's
// namespace can have, each tab shown only where its series exist:
//
//   WordPress   aorfanos/wordpress-exporter (wordpress_*_count gauges, read over
//               the WP REST API; label exported_instance = the site). Picked
//               over the alternatives because it needs no plugin inside WP and
//               is the most used of a small, fragmented field: the
//               origama/zostay "wordpress-exporter-prometheus" plugin
//               (wp_users_total, wp_posts_total{status}, wp_pages_total{status}),
//               kotsis/wordpress_exporter (wp_num_{posts,comments,users}_metric)
//               and the SlyMetrics plugin (wordpress_*_total{wordpress_site})
//               all name things differently - override `wp` below to map one.
//   PHP-FPM     hipages/php-fpm_exporter: the runtimes.php pack's own signals.
//   Web server  nginx-prometheus-exporter (stub_status) / apache_exporter
//               (mod_status) for throughput, and the ingress-nginx controller
//               for status codes and latency (stub/mod_status carry neither).
//   MySQL       mysqld_exporter: the databases.sql.mysql pack's own signals.
//   Containers  kube-state-metrics + cAdvisor, and Loki for the logs.
//
//   g.libs.frameworks.wordpress.new({ containerMatcher: 'wordpress.*' }).grafana.dashboard
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local mysql = import 'libs/mysql-observ-lib/main.libsonnet';
local php = import 'libs/php-observ-lib/main.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { query: gv.query + cv.query };

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-wordpress',
      dashboardTitle: 'WordPress',
      dashboardTags: ['wordpress', 'php', 'cms'],
      description: 'A WordPress site on Kubernetes, from every source its namespace can have: content counts from the WordPress exporter, the PHP-FPM pool, the web server and ingress in front of it, the MySQL database behind it, and the containers and logs. Each source gets its own tab, shown only where its series exist.',
      datasource: '${datasource}',
      lokiDatasource: true,
      // the site's containers (a regex over `container`); scopes $namespace
      containerMatcher: 'wordpress.*',
      // $cluster is the group variable; $namespace / $container are built below
      groupVar: 'cluster',
      varMetric: 'kube_pod_container_status_ready',
      selector: 'cluster=~"$cluster", namespace=~"$namespace"',
      // ingress-nginx labels the Ingress's namespace `namespace`
      ingressSelector: 'cluster=~"$cluster", namespace=~"$namespace"',
      containerSelector: 'cluster=~"$cluster", namespace=~"$namespace", container=~"$container"',
      cadvisorSelector: 'job=~".*cadvisor"',
      ksmSelector: 'job=~".*kube-state-metrics"',
      // the WordPress exporter's series (aorfanos/wordpress-exporter)
      wp: {
        posts: 'wordpress_post_count',
        pages: 'wordpress_page_count',
        comments: 'wordpress_comment_count',
        users: 'wordpress_user_count',
        media: 'wordpress_media_count',
        plugins: 'wordpress_plugin_count',
        themes: 'wordpress_theme_count',
      },
      // static filter for the alerting rules (no dashboard vars)
      ruleSelector: 'namespace=~".*wordpress.*"',
      references: [
        { title: 'wordpress-exporter', url: 'https://github.com/aorfanos/wordpress-exporter', description: 'the wordpress_*_count series (WP REST API)' },
        { title: 'php-fpm_exporter', url: 'https://github.com/hipages/php-fpm_exporter', description: 'the phpfpm_* pool series' },
        { title: 'nginx-prometheus-exporter', url: 'https://github.com/nginx/nginx-prometheus-exporter', description: 'nginx_* stub_status series' },
        { title: 'mysqld_exporter', url: 'https://github.com/prometheus/mysqld_exporter', description: 'the mysql_* series' },
      ],
      links: [
        { title: t[0], type: 'link', icon: 'dashboard', url: '/d/' + t[1], keepTime: true, targetBlank: false, asDropdown: false, includeVars: false, tooltip: t[0] + ' board', tags: [] }
        for t in [['PHP runtime', 'observ-viz-php'], ['NGINX', 'observ-viz-nginx'], ['Apache', 'observ-viz-apache'], ['MySQL', 'observ-viz-mysql']]
      ],
      overviewInstances: false,
      docTabs: true,
      tabbed: true,
      // Workloads / Content Management
      folderPath: (import 'libs/common-lib/folders.libsonnet').cms,
    } + config;

    local allCurrent = { spec+: { current: { text: 'All', value: '$__all' } } };
    local qvar(name, label, title, query) =
      variable.query.new(name)
      + variable.query.withLabel(title)
      + variable.query.withLabelValues(label, query)
      + variable.query.withMulti()
      + variable.query.withIncludeAll()
      + allCurrent;
    local cfgVars = cfg {
      extraVariables: [
        qvar('namespace', 'namespace', 'Namespace', cfg.varMetric + '{cluster=~"$cluster", container=~"' + cfg.containerMatcher + '"}'),
        // every container of the site's pods: wordpress, php-fpm, nginx, exporters
        qvar('container', 'container', 'Container', cfg.varMetric + '{cluster=~"$cluster", namespace=~"$namespace"}'),
      ],
    };

    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend, desc, selector=cfg.selector) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(selector).withLegendFormat(legend).withDescription(desc);
    local wpSig(key, name, desc) =
      sig(name, 'max by (exported_instance) (' + cfg.wp[key] + '{%(queriesSelector)s})', 'short', '{{exported_instance}}', desc);
    local ing(extra='') = 'rate(nginx_ingress_controller_requests{%(queriesSelector)s' + extra + '}[$__rate_interval])';

    // the runtime and database packs' own signals, on this board's filters
    local fpm = php.new({ datasource: cfg.datasource, selector: cfg.selector }).signals;
    local db = mysql.new({ datasource: cfg.datasource, selector: cfg.selector }).signals;

    local signals = {
      // ---- site status
      containersReady: sig('Containers ready',
                           'sum(max by (pod, container) (kube_pod_container_status_ready{' + cfg.ksmSelector + ', %(queriesSelector)s}))',
                           'short',
                           'ready',
                           'Site containers currently ready (kube-state-metrics).',
                           cfg.containerSelector),
      restartsRange: sig('Restarts in range',
                         'sum(increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[$__range]))',
                         'short',
                         'restarts',
                         'Container restarts over the selected time range.',
                         cfg.containerSelector),
      // ---- WordPress exporter
      posts: wpSig('posts', 'Posts', 'Posts in the site.'),
      pages: wpSig('pages', 'Pages', 'Pages in the site.'),
      comments: wpSig('comments', 'Comments', 'Comments in the site.'),
      commentsGrowth: sig('New comments',
                          'sum by (exported_instance) (delta(' + cfg.wp.comments + '{%(queriesSelector)s}[1h]))',
                          'short',
                          '{{exported_instance}}',
                          'Change in the comment count over the trailing hour. A spike is usually comment spam getting past the filter.'),
      users: wpSig('users', 'Users', 'Registered users. Unexpected growth on a site without open registration is worth a look.'),
      media: wpSig('media', 'Media items', 'Attachments in the media library.'),
      plugins: wpSig('plugins', 'Plugins', 'Installed plugins.'),
      themes: wpSig('themes', 'Themes', 'Installed themes.'),
      // ---- PHP-FPM (runtimes.php)
      fpmUp: fpm.up,
      fpmActive: fpm.active,
      fpmIdle: fpm.idle,
      fpmTotal: fpm.total,
      fpmPoolUtil: fpm.poolUtil,
      fpmMaxChildren: fpm.maxChildren,
      fpmListenQueue: fpm.listenQueue,
      fpmSlow: fpm.slowRequests,
      fpmAccepted: fpm.accepted,
      // ---- web server
      nginxRequests: sig('NGINX requests',
                         'sum(rate(nginx_http_requests_total{%(queriesSelector)s}[$__rate_interval]))',
                         'reqps',
                         'nginx',
                         'Requests per second through NGINX (stub_status).'),
      nginxConnections: sig('NGINX active connections',
                            'sum(nginx_connections_active{%(queriesSelector)s})',
                            'short',
                            'active',
                            'Open client connections on NGINX.'),
      apacheRequests: sig('Apache requests',
                          'sum(rate(apache_accesses_total{%(queriesSelector)s}[$__rate_interval]))',
                          'reqps',
                          'apache',
                          'Requests per second through Apache (mod_status).'),
      apacheBusy: sig('Apache busy workers',
                      'sum(apache_workers{%(queriesSelector)s, state="busy"})',
                      'short',
                      'busy',
                      'Apache workers serving a request.'),
      ingressByStatus: sig('Ingress responses by status',
                           'sum by (status) (' + ing() + ')',
                           'reqps',
                           '{{status}}',
                           'Responses per second at the ingress-nginx controller, by status code.',
                           cfg.ingressSelector),
      errorRatio: sig('5xx ratio',
                      'sum(' + ing(', status=~"5.."') + ') / clamp_min(sum(' + ing() + '), 0.001)',
                      'percentunit',
                      '5xx',
                      "Share of the site's responses at the ingress that are server errors. 502/504 with a healthy pod usually means PHP-FPM ran out of workers or timed out.",
                      cfg.ingressSelector),
      ingressP95: sig('Ingress latency p95',
                      'histogram_quantile(0.95, sum by (le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))',
                      's',
                      'p95',
                      'Slowest 5 percent of requests as the ingress measured them, WordPress render time included.',
                      cfg.ingressSelector),
      // ---- MySQL (databases.sql.mysql)
      dbConnected: db.connected,
      dbRunning: db.running,
      dbQps: db.qps,
      dbSlow: db.slow,
      dbBufferPool: db.bufferPool,
      // ---- containers
      cpu: sig('CPU',
               'sum by (container) (rate(container_cpu_usage_seconds_total{' + cfg.cadvisorSelector + ', %(queriesSelector)s}[$__rate_interval]))',
               'short',
               '{{container}}',
               'CPU cores used per container (cAdvisor).',
               cfg.containerSelector),
      memory: sig('Memory',
                  'sum by (container) (container_memory_working_set_bytes{' + cfg.cadvisorSelector + ', %(queriesSelector)s})',
                  'bytes',
                  '{{container}}',
                  'Working-set memory per container (cAdvisor).',
                  cfg.containerSelector),
      restarts: sig('Restarts',
                    'sum by (container) (increase(kube_pod_container_status_restarts_total{' + cfg.ksmSelector + ', %(queriesSelector)s}[1h]))',
                    'short',
                    '{{container}}',
                    'Container restarts in the trailing hour.',
                    cfg.containerSelector),
      // ---- logs
      logs: signal.new('Site logs', 'loki', '${loki_datasource}', '{%(queriesSelector)s}', 'short')
            .filteringSelector('namespace=~"$namespace", container=~"$container"')
            .withDescription('Container logs of the site (web server access/error log, PHP-FPM, WordPress).'),
      logErrors: signal.new('PHP error lines', 'loki', '${loki_datasource}', 'sum(count_over_time({%(queriesSelector)s} |~ "PHP (Fatal|Parse|Warning)|\\\\[error\\\\]" [$__auto]))', 'short')
                 .filteringSelector('namespace=~"$namespace", container=~"$container"')
                 .withDescription('PHP fatal/parse/warning lines and web-server [error] lines.'),
    };

    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };
    local redAbove(v) = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: v }]);
    local presence(q) = { label: 'namespace', query: q };

    pack.build(cfgVars, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_ready: signals.containersReady.asStat('Containers ready'),
          ov2_fpm: signals.fpmUp.asStat('PHP-FPM pools up'),
          ov3_pool: signals.fpmPoolUtil.asStat('PHP-FPM pool usage'),
          ov4_errors: signals.errorRatio.asStat('5xx ratio') + panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]),
          ov5_p95: signals.ingressP95.asStat('Latency p95'),
          ov6_restarts: signals.restartsRange.asStat('Restarts in range') + redAbove(1),
        },
      } + stats,
    ], [
      alert.rule.group('wordpress', [
        alert.rule.new('WordPressSiteDown',
                       '(max by (cluster, namespace) (kube_pod_container_status_ready{container=~"' + cfg.containerMatcher + '"' + rsComma + '}) == 0)'
                       + ' or (max by (cluster, namespace, instance) (phpfpm_up' + rs + ') == 0)'
                       + ' or (max by (cluster, namespace, job) (up{job=~".*wordpress.*"' + rsComma + '}) == 0)',
                       '5m',
                       'critical',
                       {},
                       { summary: 'WordPress in {{ $labels.namespace }} is down.', description: 'The WordPress container is not ready, its PHP-FPM pool is unreachable, or a WordPress scrape target is down in {{ $labels.namespace }} ({{ $labels.cluster }}) for 5 minutes.' }),
        alert.rule.new('WordPressPhpFpmMaxChildrenReached',
                       'increase(phpfpm_max_children_reached' + rs + '[10m]) > 0',
                       '5m',
                       'warning',
                       {},
                       { summary: 'PHP-FPM behind WordPress in {{ $labels.namespace }} hit max_children; requests are queueing for a worker.' }),
        alert.rule.new('WordPressErrorRateHigh',
                       'sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests{status=~"5.."' + rsComma + '}[5m])) / clamp_min(sum by (cluster, namespace, ingress) (rate(nginx_ingress_controller_requests' + rs + '[5m])), 0.001) > 0.05',
                       '10m',
                       'critical',
                       {},
                       { summary: 'More than 5 percent of responses from WordPress ingress {{ $labels.namespace }}/{{ $labels.ingress }} are server errors.' }),
      ]),
    ], [], [
      {
        title: 'WordPress',
        presence: presence('{__name__=~"' + cfg.wp.posts + '|' + cfg.wp.users + '", cluster=~"$cluster", namespace=~"$namespace"}'),
        groups: [
          { title: 'Content', width: 4, height: 4, elements: {
            w1_posts: signals.posts.asStat('Posts'),
            w2_pages: signals.pages.asStat('Pages'),
            w3_comments: signals.comments.asStat('Comments'),
            w4_users: signals.users.asStat('Users'),
            w5_media: signals.media.asStat('Media items'),
            w6_plugins: signals.plugins.asStat('Plugins'),
          } },
          { title: 'Trends', width: 12, height: 7, elements: {
            w7_content: signals.posts.asTimeSeries('Posts and pages') + panel.withTargetsMixin([signals.pages.asTarget()]),
            w8_comments: signals.commentsGrowth.asTimeSeries('New comments / 1h'),
            w9_users: signals.users.asTimeSeries('Users'),
            w10_plugins: signals.plugins.asTimeSeries('Plugins and themes') + panel.withTargetsMixin([signals.themes.asTarget()]),
          } },
        ],
      },
      {
        title: 'PHP pool',
        presence: presence('phpfpm_up{cluster=~"$cluster", namespace=~"$namespace"}'),
        width: 12,
        height: 7,
        elements: {
          f1_workers: signals.fpmActive.asTimeSeries('Workers')
                      + panel.withTargetsMixin([signals.fpmIdle.asTarget(), signals.fpmTotal.asTarget()]),
          f2_util: signals.fpmPoolUtil.asTimeSeries('Pool usage'),
          f3_maxChildren: signals.fpmMaxChildren.asTimeSeries('max_children reached'),
          f4_queue: signals.fpmListenQueue.asTimeSeries('Listen queue'),
          f5_slow: signals.fpmSlow.asTimeSeries('Slow requests'),
          f6_accepted: signals.fpmAccepted.asTimeSeries('Accepted connections/s'),
        },
      },
      {
        title: 'Web server',
        presence: presence('{__name__=~"nginx_up|apache_up|nginx_ingress_controller_requests", cluster=~"$cluster", namespace=~"$namespace"}'),
        width: 12,
        height: 7,
        elements: {
          h1_status: signals.ingressByStatus.asTimeSeries('Ingress responses/s by status'),
          h2_errors: signals.errorRatio.asTimeSeries('5xx ratio'),
          h3_p95: signals.ingressP95.asTimeSeries('Ingress latency p95'),
          h4_requests: signals.nginxRequests.asTimeSeries('Web server requests/s') + panel.withTargetsMixin([signals.apacheRequests.asTarget()]),
          h5_busy: signals.nginxConnections.asTimeSeries('Connections / busy workers') + panel.withTargetsMixin([signals.apacheBusy.asTarget()]),
        },
      },
      {
        title: 'MySQL',
        presence: presence('mysql_up{cluster=~"$cluster", namespace=~"$namespace"}'),
        width: 12,
        height: 7,
        elements: {
          d1_qps: signals.dbQps.asTimeSeries('Queries/s'),
          d2_threads: signals.dbConnected.asTimeSeries('Threads') + panel.withTargetsMixin([signals.dbRunning.asTarget()]),
          d3_slow: signals.dbSlow.asTimeSeries('Slow queries/s'),
          d4_buffer: signals.dbBufferPool.asTimeSeries('InnoDB buffer pool data'),
        },
      },
      {
        title: 'Containers',
        alwaysShow: true,
        elements: {
          c1_cpu: signals.cpu.asTimeSeries('CPU (cores)'),
          c2_memory: signals.memory.asTimeSeries('Memory working set'),
          c3_restarts: signals.restarts.asTimeSeries('Restarts / 1h'),
        },
        width: 12,
        height: 7,
      },
      {
        title: 'Logs',
        alwaysShow: true,
        width: 24,
        height: 12,
        elements: {
          l1_errors: signals.logErrors.asTimeSeries('PHP / web server error lines'),
          l2_logs: panel.logs.new('Site logs')
                   + panel.withDescription(signals.logs._description)
                   + panel.logs.withTargets([signals.logs.asTarget()]),
        },
      },
    ]),
}
