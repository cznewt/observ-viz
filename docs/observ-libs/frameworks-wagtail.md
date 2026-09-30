# Wagtail  (`g.libs.frameworks.wagtail`)

Dashboard uid `observ-viz-wagtail` · 65 signals · 3 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `adminByStatus` | reqps | `sum by (status) (rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtailadmin.*"}[$__rate_interval]))` | — |
| `adminByView` | reqps | `topk(10, sum by (view) (rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtailadmin.*"}[$__rate_interval])))` | — |
| `adminErrors` | percentunit | `sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtailadmin.*", status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtailadmin.*"}[$__rate_interval])), 0.001)` | — |
| `adminP95` | s | `histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtailadmin.*"}[$__rate_interval])))` | — |
| `adminP95ByView` | s | `topk(10, histogram_quantile(0.95, sum by (le, view) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtailadmin.*"}[$__rate_interval]))))` | — |
| `adminRequests` | reqps | `sum(rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtailadmin.*"}[$__rate_interval]))` | — |
| `byStatus` | reqps | `sum by (status) (rate(django_http_responses_total_by_status_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `cacheFails` | ops | `sum by (backend) (rate(django_cache_get_fail_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `cacheGets` | ops | `sum by (backend) (rate(django_cache_get_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `cacheHitRatio` | percentunit | `sum by (backend) (rate(django_cache_get_hits_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval])) / clamp_min(sum by (backend) (rate(django_cache_get_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval])), 0.001)` | — |
| `cacheMisses` | ops | `sum by (backend) (rate(django_cache_get_misses_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `dbConnections` | ops | `sum by (alias) (rate(django_db_new_connections_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `dbErrors` | ops | `sum by (alias, type) (rate(django_db_errors_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `dbP95` | s | `histogram_quantile(0.95, sum by (le, alias) (rate(django_db_query_duration_seconds_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval])))` | — |
| `dbQueries` | ops | `sum by (alias, vendor) (rate(django_db_execute_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `dbQueriesPerRequest` | short | `sum(rate(django_db_execute_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval])) / clamp_min(sum(rate(django_http_requests_before_middlewares_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval])), 0.001)` | — |
| `documentsByStatus` | reqps | `sum by (status) (rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtaildocs.*"}[$__rate_interval]))` | — |
| `documentsByView` | reqps | `topk(10, sum by (view) (rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtaildocs.*"}[$__rate_interval])))` | — |
| `documentsErrors` | percentunit | `sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtaildocs.*", status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtaildocs.*"}[$__rate_interval])), 0.001)` | — |
| `documentsP95` | s | `histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtaildocs.*"}[$__rate_interval])))` | — |
| `documentsP95ByView` | s | `topk(10, histogram_quantile(0.95, sum by (le, view) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtaildocs.*"}[$__rate_interval]))))` | — |
| `documentsRequests` | reqps | `sum(rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtaildocs.*"}[$__rate_interval]))` | — |
| `errorRate` | percentunit | `sum(rate(django_http_responses_total_by_status_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(django_http_responses_total_by_status_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval])), 0.001)` | — |
| `exceptionsByType` | ops | `sum by (type) (rate(django_http_exceptions_total_by_type_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `gunicornErrors` | ops | `sum by (instance) (rate({__name__=~"gunicorn_log_(error\|critical\|exception)(_total)?", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `gunicornRequests` | reqps | `sum by (instance) (rate({__name__=~"gunicorn_requests(_total)?", namespace=~"$namespace"}[$__rate_interval]))` | — |
| `gunicornWorkers` | short | `sum by (instance) (gunicorn_workers{namespace=~"$namespace"})` | — |
| `imagesByStatus` | reqps | `sum by (status) (rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtailimages.*"}[$__rate_interval]))` | — |
| `imagesByView` | reqps | `topk(10, sum by (view) (rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtailimages.*"}[$__rate_interval])))` | — |
| `imagesErrors` | percentunit | `sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtailimages.*", status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtailimages.*"}[$__rate_interval])), 0.001)` | — |
| `imagesP95` | s | `histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtailimages.*"}[$__rate_interval])))` | — |
| `imagesP95ByView` | s | `topk(10, histogram_quantile(0.95, sum by (le, view) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtailimages.*"}[$__rate_interval]))))` | — |
| `imagesRequests` | reqps | `sum(rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*wagtailimages.*"}[$__rate_interval]))` | — |
| `instErrors` | percentunit | `sum by (instance) (rate(django_http_responses_total_by_status_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", status=~"5.."}[$__rate_interval])) / clamp_min(sum by (instance) (rate(django_http_responses_total_by_status_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval])), 0.001)` | — |
| `instP95` | s | `histogram_quantile(0.95, sum by (le, instance) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval])))` | — |
| `instRequests` | reqps | `sum by (instance) (rate(django_http_requests_before_middlewares_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `logErrors` | short | `sum(count_over_time({namespace=~"$namespace", container=~"$container"} \|~ "(?i)(error\|traceback\|exception)" [$__auto]))` | — |
| `logs` | short | `{namespace=~"$namespace", container=~"$container"}` | — |
| `mediaDeletes` | ops | `sum by (model) (rate(django_model_deletes_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", model=~"(?i).*(image\|rendition\|document).*"}[$__rate_interval]))` | — |
| `mediaInserts` | ops | `sum by (model) (rate(django_model_inserts_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", model=~"(?i).*(image\|rendition\|document).*"}[$__rate_interval]))` | — |
| `mediaUpdates` | ops | `sum by (model) (rate(django_model_updates_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", model=~"(?i).*(image\|rendition\|document).*"}[$__rate_interval]))` | — |
| `migrationsApplied` | short | `max(django_migrations_applied_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"})` | — |
| `migrationsUnapplied` | short | `max(django_migrations_unapplied_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"})` | — |
| `p95` | s | `histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval])))` | — |
| `pageDeletes` | ops | `sum by (model) (rate(django_model_deletes_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", model=~"(?i).*page.*"}[$__rate_interval]))` | — |
| `pageInserts` | ops | `sum by (model) (rate(django_model_inserts_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", model=~"(?i).*page.*"}[$__rate_interval]))` | — |
| `pageUpdates` | ops | `sum by (model) (rate(django_model_updates_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", model=~"(?i).*page.*"}[$__rate_interval]))` | — |
| `pagesByStatus` | reqps | `sum by (status) (rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtail_serve.*\|wagtail[.]core[.]views[.]serve.*"}[$__rate_interval]))` | — |
| `pagesByView` | reqps | `topk(10, sum by (view) (rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtail_serve.*\|wagtail[.]core[.]views[.]serve.*"}[$__rate_interval])))` | — |
| `pagesErrors` | percentunit | `sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtail_serve.*\|wagtail[.]core[.]views[.]serve.*", status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtail_serve.*\|wagtail[.]core[.]views[.]serve.*"}[$__rate_interval])), 0.001)` | — |
| `pagesP95` | s | `histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtail_serve.*\|wagtail[.]core[.]views[.]serve.*"}[$__rate_interval])))` | — |
| `pagesP95ByView` | s | `topk(10, histogram_quantile(0.95, sum by (le, view) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtail_serve.*\|wagtail[.]core[.]views[.]serve.*"}[$__rate_interval]))))` | — |
| `pagesRequests` | reqps | `sum(rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~"wagtail_serve.*\|wagtail[.]core[.]views[.]serve.*"}[$__rate_interval]))` | — |
| `requests` | reqps | `sum(rate(django_http_requests_before_middlewares_total{job=~"$job", namespace=~"$namespace", instance=~"$instance"}[$__rate_interval]))` | — |
| `searchByStatus` | reqps | `sum by (status) (rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*search.*"}[$__rate_interval]))` | — |
| `searchByView` | reqps | `topk(10, sum by (view) (rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*search.*"}[$__rate_interval])))` | — |
| `searchErrors` | percentunit | `sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*search.*", status=~"5.."}[$__rate_interval])) / clamp_min(sum(rate(django_http_responses_total_by_status_view_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*search.*"}[$__rate_interval])), 0.001)` | — |
| `searchP95` | s | `histogram_quantile(0.95, sum by (le) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*search.*"}[$__rate_interval])))` | — |
| `searchP95ByView` | s | `topk(10, histogram_quantile(0.95, sum by (le, view) (rate(django_http_requests_latency_seconds_by_view_method_bucket{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*search.*"}[$__rate_interval]))))` | — |
| `searchRequests` | reqps | `sum(rate(django_http_requests_total_by_view_transport_method_total{job=~"$job", namespace=~"$namespace", instance=~"$instance", view=~".*search.*"}[$__rate_interval]))` | — |
| `uwsgiBusy` | short | `sum by (instance) (uwsgi_worker_busy{namespace=~"$namespace"})` | — |
| `uwsgiHarakiri` | short | `sum by (instance) (increase(uwsgi_worker_harakiri_count_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `uwsgiQueue` | short | `sum by (instance) (uwsgi_listen_queue_length{namespace=~"$namespace"})` | — |
| `uwsgiRequests` | reqps | `sum by (instance) (rate(uwsgi_worker_requests_total{namespace=~"$namespace"}[$__rate_interval]))` | — |
| `uwsgiWorkers` | short | `sum by (instance) (uwsgi_workers{namespace=~"$namespace"})` | — |

## Dashboard

- **Overview** — `ov1_requests`, `ov2_errors`, `ov3_p95`, `ov4_pages`, `ov5_admin`, `ov6_migrations`
- **Pages** — `p1_requests`, `p2_status`, `p3_latency`, `p4_errors`, `p5_search`, `p6_writes`
- **Admin** — `a1_requests`, `a2_byView`, `a3_latency`, `a4_errors`
- **Media** — `m1_images`, `m2_latency`, `m3_byView`, `m4_errors`, `m5_writes`
- **Database & cache** — `d1_queries`, `d2_perRequest`, `d3_p95`, `d4_errors`, `d5_hitRatio`, `d6_gets`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `WagtailErrorRateHigh` | critical | 10m | — |
| `WagtailLatencyHigh` | warning | 15m | — |
| `WagtailUnappliedMigrations` | warning | 15m | — |
