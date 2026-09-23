# NGINX  (`g.libs.webservers.nginx`)

Dashboard uid `observ-viz-nginx` · 11 signals · 2 alerts · 1 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `accepted` | ops | `rate(nginx_connections_accepted{job=~"$job"}[$__rate_interval])` | — |
| `active` | short | `nginx_connections_active{job=~"$job"}` | — |
| `dropped` | ops | `rate(nginx_connections_accepted{job=~"$job"}[$__rate_interval]) - rate(nginx_connections_handled{job=~"$job"}[$__rate_interval])` | — |
| `handled` | ops | `rate(nginx_connections_handled{job=~"$job"}[$__rate_interval])` | — |
| `reading` | short | `nginx_connections_reading{job=~"$job"}` | — |
| `requests` | reqps | `sum(rate(nginx_http_requests_total{job=~"$job"}[$__rate_interval]))` | — |
| `requestsByInstance` | reqps | `sum by (instance) (rate(nginx_http_requests_total{job=~"$job"}[$__rate_interval]))` | — |
| `requestsPerConnection` | short | `rate(nginx_http_requests_total{job=~"$job"}[$__rate_interval]) / clamp_min(rate(nginx_connections_handled{job=~"$job"}[$__rate_interval]), 0.001)` | — |
| `up` | short | `sum(nginx_up{job=~"$job"})` | — |
| `waiting` | short | `nginx_connections_waiting{job=~"$job"}` | — |
| `writing` | short | `nginx_connections_writing{job=~"$job"}` | — |

## Dashboard

- **Overview** — `ov1_up`, `ov2_requests`, `ov3_active`, `ov4_dropped`
- **Traffic** — `connections`, `dropped`, `requests`, `requestsPerConnection`
- **Connection states** — `active`, `states`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `NginxDown` | critical | 5m | — |
| `NginxDroppingConnections` | warning | 10m | — |

## Recording rules

| Record | Expression |
|--------|------------|
| `instance:nginx_http_requests:rate5m` | `rate(nginx_http_requests_total[5m])` |
