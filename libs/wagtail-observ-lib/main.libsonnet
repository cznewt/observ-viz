// observ-viz Wagtail pack (hand-written).
// Wagtail exports no Prometheus metrics of its own: it is a Django app, so this
// board reads korfuri/django-prometheus (django_*) and cuts it by the Wagtail
// views behind each job a CMS does - serving pages, the editor admin, image
// renditions and documents, search - plus the database, the cache and the
// model writes an editor causes. The site-wide request signals are the Django
// pack's own (frameworks.django), so the two boards agree on every number.
//
//   g.libs.frameworks.wagtail.new({}).grafana.dashboard
//
// What the app has to do for the tabs to fill:
//   - django-prometheus middleware + urls (every request / view tab),
//   - its database backends (django_prometheus.db.backends.*) for Database,
//   - its cache backends (django_prometheus.cache.backends.*) for Cache,
//   - ExportModelOperationsMixin('<name>') on the models for Model changes -
//     the `model` label is whatever name the app gives the mixin, so the
//     pageModels / mediaModels regexes below are a guess to adjust per site.
// Gunicorn (statsd_exporter) and uWSGI (uwsgi_exporter) tabs appear only where
// those series exist.
local panel = import 'custom/panel.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local filters = import 'libs/common-lib/filters.libsonnet';
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local django = import 'libs/django-observ-lib/main.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { query: gv.query + cv.query };

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-wagtail',
      dashboardTitle: 'Wagtail',
      dashboardTags: ['wagtail', 'django', 'python', 'cms'],
      description: 'A Wagtail site as django-prometheus reports it, cut by what a CMS does: page serving, the editor admin, image renditions and documents, search, and the database, cache and model writes behind them. Wagtail has no metrics of its own; every series here is django_*.',
      datasource: '${datasource}',
      lokiDatasource: true,
      // $job, then $namespace / $instance cascade off the identity metric
      selector: 'job=~"$job"',
      varLabels: ['namespace', 'instance'],
      varMetric: 'django_http_requests_before_middlewares_total',
      legend: '{{view}}',
      // the Wagtail URL names (the django-prometheus `view` label). Page
      // serving is wagtail_serve; images/documents have their own serve views,
      // so they are counted under Media, not Pages.
      views: {
        pages: 'wagtail_serve.*|wagtail[.]core[.]views[.]serve.*',
        admin: 'wagtailadmin.*',
        images: '.*wagtailimages.*',
        documents: '.*wagtaildocs.*',
        search: '.*search.*',
      },
      // ExportModelOperationsMixin names (the `model` label)
      pageModels: '(?i).*page.*',
      mediaModels: '(?i).*(image|rendition|document).*',
      // logs: the app container(s) in the selected namespace
      containerMatcher: '.*',
      // static filter for the alerting rules (no dashboard vars)
      ruleSelector: '',
      latencyThreshold: 1,
      references: [
        { title: 'django-prometheus', url: 'https://github.com/korfuri/django-prometheus', description: 'the exporter behind every django_* series here' },
        { title: 'Wagtail URL config', url: 'https://docs.wagtail.org/en/stable/getting_started/integrating_into_django.html', description: 'the wagtail_serve / wagtailadmin / wagtailimages / wagtaildocs URL names the tabs filter on' },
        { title: 'Image renditions', url: 'https://docs.wagtail.org/en/stable/advanced_topics/images/renditions.html', description: 'why the first request for an image size is slow' },
      ],
      links: [
        { title: 'Django', type: 'link', icon: 'dashboard', url: '/d/observ-viz-django', keepTime: true, targetBlank: false, asDropdown: false, includeVars: true, tooltip: 'The same app on the generic Django board', tags: [] },
      ],
      overviewSignals: ['instRequests', 'instErrors', 'instP95'],
      docTabs: true,
      tabbed: true,
      // Workloads / Content Management
      folderPath: (import 'libs/common-lib/folders.libsonnet').cms,
    } + config;

    local sel = filters.selector(cfg);
    local rs = if cfg.ruleSelector != '' then '{' + cfg.ruleSelector + '}' else '';
    local rsComma = if cfg.ruleSelector != '' then ', ' + cfg.ruleSelector else '';
    local sig(name, expr, unit, legend=cfg.legend, desc='') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(sel).withLegendFormat(legend).withDescription(desc);
    // gunicorn / uwsgi exporters are their own scrape jobs: join on namespace only
    local nsSel = 'namespace=~"$namespace"';
    local nsig(name, expr, unit, legend, desc) =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(nsSel).withLegendFormat(legend).withDescription(desc);

    // the Django pack's own site-wide signals, on this board's filters
    local dj = django.new({ datasource: cfg.datasource, selector: cfg.selector, varLabels: cfg.varLabels, docTabs: false }).signals;

    // per view group: requests, 5xx ratio, p95
    local req(v) = 'rate(django_http_requests_total_by_view_transport_method_total{%(queriesSelector)s, view=~"' + v + '"}[$__rate_interval])';
    local resp(v, extra='') = 'rate(django_http_responses_total_by_status_view_method_total{%(queriesSelector)s, view=~"' + v + '"' + extra + '}[$__rate_interval])';
    local lat(v) = 'rate(django_http_requests_latency_seconds_by_view_method_bucket{%(queriesSelector)s, view=~"' + v + '"}[$__rate_interval])';
    local groupSignals(key, label) = {
      [key + 'Requests']: sig(label + ' requests',
                              'sum(' + req(cfg.views[key]) + ')',
                              'reqps',
                              label,
                              desc='Requests per second to the ' + label + ' views (view=~"' + cfg.views[key] + '").'),
      [key + 'ByView']: sig(label + ' requests by view',
                            'topk(10, sum by (view) (' + req(cfg.views[key]) + '))',
                            'reqps',
                            desc='The ten busiest ' + label + ' views.'),
      [key + 'Errors']: sig(label + ' 5xx ratio',
                            'sum(' + resp(cfg.views[key], ', status=~"5.."') + ') / clamp_min(sum(' + resp(cfg.views[key]) + '), 0.001)',
                            'percentunit',
                            '5xx',
                            desc='Share of ' + label + ' responses that are server errors.'),
      [key + 'ByStatus']: sig(label + ' responses by status',
                              'sum by (status) (' + resp(cfg.views[key]) + ')',
                              'reqps',
                              '{{status}}',
                              desc=label + ' responses per second by status code.'),
      [key + 'P95']: sig(label + ' latency p95',
                         'histogram_quantile(0.95, sum by (le) (' + lat(cfg.views[key]) + '))',
                         's',
                         'p95',
                         desc='Slowest 5 percent of ' + label + ' requests, measured in the view.'),
      [key + 'P95ByView']: sig(label + ' latency p95 by view',
                               'topk(10, histogram_quantile(0.95, sum by (le, view) (' + lat(cfg.views[key]) + ')))',
                               's',
                               desc='The ten slowest ' + label + ' views at p95.'),
    };
    local modelOps(key, label, models) = {
      [key + 'Inserts']: sig(label + ' inserts',
                             'sum by (model) (rate(django_model_inserts_total{%(queriesSelector)s, model=~"' + models + '"}[$__rate_interval]))',
                             'ops',
                             'insert {{model}}',
                             desc='Rows created per second for ' + label + ' models (ExportModelOperationsMixin).'),
      [key + 'Updates']: sig(label + ' updates',
                             'sum by (model) (rate(django_model_updates_total{%(queriesSelector)s, model=~"' + models + '"}[$__rate_interval]))',
                             'ops',
                             'update {{model}}',
                             desc='Rows saved per second for ' + label + ' models. Every page publish and draft save lands here.'),
      [key + 'Deletes']: sig(label + ' deletes',
                             'sum by (model) (rate(django_model_deletes_total{%(queriesSelector)s, model=~"' + models + '"}[$__rate_interval]))',
                             'ops',
                             'delete {{model}}',
                             desc='Rows deleted per second for ' + label + ' models.'),
    };

    local signals =
      {
        requests: dj.requests,
        errorRate: dj.errorRate,
        p95: dj.p95,
        byStatus: dj.byStatus,
        exceptionsByType: dj.exceptionsByType,
        // per instance, for the Overview table
        instRequests: sig('Requests', 'sum by (instance) (rate(django_http_requests_before_middlewares_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{instance}}', desc='Requests per second per instance.'),
        instErrors: sig('5xx ratio', 'sum by (instance) (rate(django_http_responses_total_by_status_total{%(queriesSelector)s, status=~"5.."}[$__rate_interval])) / clamp_min(sum by (instance) (rate(django_http_responses_total_by_status_total{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'percentunit', '{{instance}}', desc='Share of responses per instance that are server errors.'),
        instP95: sig('Latency p95', 'histogram_quantile(0.95, sum by (le, instance) (rate(django_http_requests_latency_seconds_by_view_method_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{instance}}', desc='p95 view latency per instance.'),
        migrationsUnapplied: sig('Unapplied migrations', 'max(django_migrations_unapplied_total{%(queriesSelector)s})', 'short', 'unapplied', desc='Migrations present in code but not applied to the database at process start. Anything above 0 is a deploy that skipped migrate.'),
        migrationsApplied: sig('Applied migrations', 'max(django_migrations_applied_total{%(queriesSelector)s})', 'short', 'applied', desc='Migrations applied to the database, as seen at process start.'),
        // database
        dbQueries: sig('Queries', 'sum by (alias, vendor) (rate(django_db_execute_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{alias}} ({{vendor}})', desc='SQL statements executed per second, by connection alias.'),
        dbQueriesPerRequest: sig('Queries per request', 'sum(rate(django_db_execute_total{%(queriesSelector)s}[$__rate_interval])) / clamp_min(sum(rate(django_http_requests_before_middlewares_total{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'short', 'queries / request', desc='SQL statements per HTTP request. A jump after a deploy is usually an N+1 in a page template or a StreamField block.'),
        dbP95: sig('Query latency p95', 'histogram_quantile(0.95, sum by (le, alias) (rate(django_db_query_duration_seconds_bucket{%(queriesSelector)s}[$__rate_interval])))', 's', '{{alias}}', desc='Slowest 5 percent of SQL statements.'),
        dbErrors: sig('Query errors', 'sum by (alias, type) (rate(django_db_errors_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{alias}} {{type}}', desc='Database errors per second by exception type.'),
        dbConnections: sig('New connections', 'sum by (alias) (rate(django_db_new_connections_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{alias}}', desc='Database connections opened per second. High with CONN_MAX_AGE=0: one per request.'),
        // cache
        cacheGets: sig('Cache gets', 'sum by (backend) (rate(django_cache_get_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{backend}}', desc='Cache reads per second by backend.'),
        cacheHitRatio: sig('Cache hit ratio', 'sum by (backend) (rate(django_cache_get_hits_total{%(queriesSelector)s}[$__rate_interval])) / clamp_min(sum by (backend) (rate(django_cache_get_total{%(queriesSelector)s}[$__rate_interval])), 0.001)', 'percentunit', '{{backend}}', desc='Share of cache reads that hit. Wagtail caches renditions and the page tree here; a low ratio makes every page render hit the database.'),
        cacheMisses: sig('Cache misses', 'sum by (backend) (rate(django_cache_get_misses_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{backend}}', desc='Cache reads per second that missed.'),
        cacheFails: sig('Cache failures', 'sum by (backend) (rate(django_cache_get_fail_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{backend}}', desc='Cache reads per second that raised (backend unreachable).'),
        // gunicorn (statsd_exporter; counters with or without _total, by version)
        gunicornWorkers: nsig('Gunicorn workers', 'sum by (instance) (gunicorn_workers{%(queriesSelector)s})', 'short', '{{instance}}', 'Gunicorn worker processes, from the statsd gunicorn.workers gauge.'),
        gunicornRequests: nsig('Gunicorn requests', 'sum by (instance) (rate({__name__=~"gunicorn_requests(_total)?", %(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{instance}}', 'Requests per second Gunicorn handled.'),
        gunicornErrors: nsig('Gunicorn error logs', 'sum by (instance) (rate({__name__=~"gunicorn_log_(error|critical|exception)(_total)?", %(queriesSelector)s}[$__rate_interval]))', 'ops', '{{instance}}', 'Error, critical and exception log lines per second from Gunicorn itself (worker timeouts, boot failures).'),
        // uwsgi (timonwong/uwsgi_exporter)
        uwsgiWorkers: nsig('uWSGI workers', 'sum by (instance) (uwsgi_workers{%(queriesSelector)s})', 'short', '{{instance}}', 'uWSGI worker processes.'),
        uwsgiBusy: nsig('uWSGI busy workers', 'sum by (instance) (uwsgi_worker_busy{%(queriesSelector)s})', 'short', '{{instance}}', 'Workers serving a request right now.'),
        uwsgiQueue: nsig('uWSGI listen queue', 'sum by (instance) (uwsgi_listen_queue_length{%(queriesSelector)s})', 'short', '{{instance}}', 'Requests waiting for a free worker.'),
        uwsgiRequests: nsig('uWSGI requests', 'sum by (instance) (rate(uwsgi_worker_requests_total{%(queriesSelector)s}[$__rate_interval]))', 'reqps', '{{instance}}', 'Requests per second across workers.'),
        uwsgiHarakiri: nsig('uWSGI harakiri', 'sum by (instance) (increase(uwsgi_worker_harakiri_count_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{instance}}', 'Workers killed for exceeding the harakiri timeout.'),
        // logs
        logs: signal.new('App logs', 'loki', '${loki_datasource}', '{%(queriesSelector)s}', 'short')
              .filteringSelector('namespace=~"$namespace", container=~"$container"')
              .withDescription('Container logs of the Wagtail app in the selected namespace.'),
        logErrors: signal.new('Error log lines', 'loki', '${loki_datasource}', 'sum(count_over_time({%(queriesSelector)s} |~ "(?i)(error|traceback|exception)" [$__auto]))', 'short')
                   .filteringSelector('namespace=~"$namespace", container=~"$container"')
                   .withDescription('Log lines that look like errors or tracebacks.'),
      }
      + groupSignals('pages', 'Page')
      + groupSignals('admin', 'Admin')
      + groupSignals('images', 'Image')
      + groupSignals('documents', 'Document')
      + groupSignals('search', 'Search')
      + modelOps('page', 'Page', cfg.pageModels)
      + modelOps('media', 'Media', cfg.mediaModels);

    local stats = { width: 4, height: 4 };
    local charts = { width: 12, height: 7 };
    local ratioThresholds = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'orange', value: 0.01 }, { color: 'red', value: 0.05 }]);
    local redAbove(v) = panel.stat.withThresholds([{ color: 'green', value: null }, { color: 'red', value: v }]);

    local containerVar =
      variable.query.new('container')
      + variable.query.withLabel('Container')
      + variable.query.withLabelValues('container', 'kube_pod_container_status_ready{namespace=~"$namespace", container=~"' + cfg.containerMatcher + '"}')
      + variable.query.withMulti()
      + variable.query.withIncludeAll()
      + { spec+: { current: { text: 'All', value: '$__all' } } };

    pack.build(cfg { extraVariables+: [containerVar] }, signals, [
      {
        title: 'Overview',
        elements: {
          ov1_requests: signals.requests.asStat('Requests/s'),
          ov2_errors: signals.errorRate.asStat('5xx ratio') + ratioThresholds,
          ov3_p95: signals.p95.asStat('Latency p95'),
          ov4_pages: signals.pagesRequests.asStat('Page views/s'),
          ov5_admin: signals.adminRequests.asStat('Admin requests/s'),
          ov6_migrations: signals.migrationsUnapplied.asStat('Unapplied migrations') + redAbove(1),
        },
      } + stats,
      {
        title: 'Pages',
        signalKeys: ['pagesRequests', 'pagesByView', 'pagesErrors', 'pagesByStatus', 'pagesP95', 'pagesP95ByView', 'searchRequests', 'searchP95', 'pageInserts', 'pageUpdates', 'pageDeletes'],
        elements: {
          p1_requests: signals.pagesRequests.asTimeSeries('Page views/s'),
          p2_status: signals.pagesByStatus.asTimeSeries('Page responses/s by status'),
          p3_latency: signals.pagesP95.asTimeSeries('Page latency p95'),
          p4_errors: signals.pagesErrors.asTimeSeries('Page 5xx ratio'),
          p5_search: signals.searchRequests.asTimeSeries('Search requests/s') + panel.withTargetsMixin([signals.searchP95.asTarget()]),
          p6_writes: signals.pageUpdates.asTimeSeries('Page model writes')
                     + panel.withTargetsMixin([signals.pageInserts.asTarget(), signals.pageDeletes.asTarget()]),
        },
      } + charts,
      {
        title: 'Admin',
        signalKeys: ['adminRequests', 'adminByView', 'adminErrors', 'adminByStatus', 'adminP95', 'adminP95ByView'],
        elements: {
          a1_requests: signals.adminRequests.asTimeSeries('Admin requests/s'),
          a2_byView: signals.adminByView.asTimeSeries('Admin requests/s by view'),
          a3_latency: signals.adminP95ByView.asTimeSeries('Slowest admin views (p95)'),
          a4_errors: signals.adminErrors.asTimeSeries('Admin 5xx ratio'),
        },
      } + charts,
      {
        title: 'Media',
        signalKeys: ['imagesRequests', 'imagesP95', 'imagesErrors', 'imagesByView', 'documentsRequests', 'documentsP95', 'documentsErrors', 'mediaInserts', 'mediaUpdates', 'mediaDeletes'],
        elements: {
          m1_images: signals.imagesRequests.asTimeSeries('Image requests/s') + panel.withTargetsMixin([signals.documentsRequests.asTarget()]),
          m2_latency: signals.imagesP95.asTimeSeries('Media latency p95') + panel.withTargetsMixin([signals.documentsP95.asTarget()]),
          m3_byView: signals.imagesByView.asTimeSeries('Image requests/s by view'),
          m4_errors: signals.imagesErrors.asTimeSeries('Media 5xx ratio') + panel.withTargetsMixin([signals.documentsErrors.asTarget()]),
          m5_writes: signals.mediaInserts.asTimeSeries('Image / rendition / document writes')
                     + panel.withTargetsMixin([signals.mediaUpdates.asTarget(), signals.mediaDeletes.asTarget()]),
        },
      } + charts,
      {
        title: 'Database & cache',
        elements: {
          d1_queries: signals.dbQueries.asTimeSeries('Queries/s'),
          d2_perRequest: signals.dbQueriesPerRequest.asTimeSeries('Queries per request'),
          d3_p95: signals.dbP95.asTimeSeries('Query latency p95'),
          d4_errors: signals.dbErrors.asTimeSeries('Query errors/s') + panel.withTargetsMixin([signals.dbConnections.asTarget()]),
          d5_hitRatio: signals.cacheHitRatio.asTimeSeries('Cache hit ratio'),
          d6_gets: signals.cacheGets.asTimeSeries('Cache gets/s')
                   + panel.withTargetsMixin([signals.cacheMisses.asTarget(), signals.cacheFails.asTarget()]),
        },
      } + charts,
    ], [
      alert.rule.group('wagtail', [
        alert.rule.new('WagtailErrorRateHigh',
                       'sum by (job) (rate(django_http_responses_total_by_status_total{status=~"5.."' + rsComma + '}[5m])) / clamp_min(sum by (job) (rate(django_http_responses_total_by_status_total' + rs + '[5m])), 0.001) > 0.05',
                       '10m',
                       'critical',
                       {},
                       { summary: 'More than 5 percent of responses from the Wagtail site on {{ $labels.job }} are server errors.' }),
        alert.rule.new('WagtailLatencyHigh',
                       'histogram_quantile(0.95, sum by (le, job) (rate(django_http_requests_latency_seconds_by_view_method_bucket' + rs + '[5m]))) > ' + cfg.latencyThreshold,
                       '15m',
                       'warning',
                       {},
                       { summary: 'The Wagtail site on {{ $labels.job }} answers its slowest 5 percent of requests in over ' + cfg.latencyThreshold + 's.' }),
        alert.rule.new('WagtailUnappliedMigrations',
                       'max by (job) (django_migrations_unapplied_total' + rs + ') > 0',
                       '15m',
                       'warning',
                       {},
                       { summary: 'The Wagtail site on {{ $labels.job }} runs with {{ $value }} unapplied migrations; a deploy skipped migrate.' }),
      ]),
    ], [], [
      {
        title: 'Gunicorn',
        presence: { label: 'instance', query: 'gunicorn_workers{' + nsSel + '}' },
        width: 12,
        height: 7,
        elements: {
          g1_workers: signals.gunicornWorkers.asTimeSeries('Gunicorn workers'),
          g2_requests: signals.gunicornRequests.asTimeSeries('Gunicorn requests/s'),
          g3_errors: signals.gunicornErrors.asTimeSeries('Gunicorn error logs/s'),
        },
      },
      {
        title: 'uWSGI',
        presence: { label: 'instance', query: 'uwsgi_workers{' + nsSel + '}' },
        width: 12,
        height: 7,
        elements: {
          u1_workers: signals.uwsgiBusy.asTimeSeries('uWSGI busy workers') + panel.withTargetsMixin([signals.uwsgiWorkers.asTarget()]),
          u2_queue: signals.uwsgiQueue.asTimeSeries('uWSGI listen queue'),
          u3_requests: signals.uwsgiRequests.asTimeSeries('uWSGI requests/s'),
          u4_harakiri: signals.uwsgiHarakiri.asTimeSeries('uWSGI harakiri'),
        },
      },
      {
        title: 'Logs',
        alwaysShow: true,
        width: 24,
        height: 12,
        elements: {
          l1_errors: signals.logErrors.asTimeSeries('Error log lines'),
          l2_logs: panel.logs.new('App logs')
                   + panel.withDescription(signals.logs._description)
                   + panel.logs.withTargets([signals.logs.asTarget()]),
        },
      },
    ]),
}
