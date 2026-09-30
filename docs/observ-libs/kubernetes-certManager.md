# cert-manager  (`g.libs.kubernetes.certManager`)

Dashboard uid `observ-viz-cert-manager` · 13 signals · 5 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `acmeByAction` | reqps | `sum by (action) (rate(certmanager_http_acme_client_request_count{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |
| `acmeByStatus` | reqps | `sum by (status) (rate(certmanager_http_acme_client_request_count{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |
| `acmeLatency` | s | `sum by (action) (rate(certmanager_http_acme_client_request_duration_seconds_sum{job=~"$job", cluster=~"$cluster"}[$__rate_interval])) / sum by (action) (rate(certmanager_http_acme_client_request_duration_seconds_count{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |
| `certificates` | short | `count(certmanager_certificate_expiration_timestamp_seconds{namespace=~"$namespace", job=~"$job", cluster=~"$cluster"})` | — |
| `challengesPending` | short | `count(certmanager_certificate_challenge_status{status!="valid", namespace=~"$namespace", job=~"$job", cluster=~"$cluster"} == 1) or vector(0)` | — |
| `daysLeft` | d | `(certmanager_certificate_expiration_timestamp_seconds{namespace=~"$namespace", job=~"$job", cluster=~"$cluster"} - time()) / 86400` | — |
| `expiringSoon` | short | `count((certmanager_certificate_expiration_timestamp_seconds{namespace=~"$namespace", job=~"$job", cluster=~"$cluster"} - time()) < 1814400) or vector(0)` | — |
| `issuersNotReady` | short | `count(certmanager_clusterissuer_ready_status{condition!="True", job=~"$job", cluster=~"$cluster"} == 1) or vector(0)` | — |
| `notReady` | short | `count(certmanager_certificate_ready_status{condition!="True", namespace=~"$namespace", job=~"$job", cluster=~"$cluster"} == 1) or vector(0)` | — |
| `readyState` | short | `max by (namespace, name) (certmanager_certificate_ready_status{condition="True", namespace=~"$namespace", job=~"$job", cluster=~"$cluster"})` | — |
| `soonest` | d | `min((certmanager_certificate_expiration_timestamp_seconds{namespace=~"$namespace", job=~"$job", cluster=~"$cluster"} - time()) / 86400)` | — |
| `syncCalls` | ops | `sum by (controller) (rate(certmanager_controller_sync_call_count{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |
| `syncErrors` | ops | `sum by (controller) (rate(certmanager_controller_sync_error_count{job=~"$job", cluster=~"$cluster"}[$__rate_interval]))` | — |

## Dashboard

- **Overview** — `a_certs`, `b_notReady`, `c_expiring`, `d_soonest`, `e_issuers`, `f_challenges`
- **Certificates** — `certsTable`
- **Expiry** — `a_days`
- **Controller & ACME** — `a_sync`, `b_acme`, `c_action`, `d_latency`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `CertManagerDown` | critical | 10m | — |
| `CertManagerCertExpirySoon` | warning | 1h | — |
| `CertManagerCertNotReady` | critical | 10m | — |
| `CertManagerClusterIssuerNotReady` | warning | 10m | — |
| `CertManagerHittingRateLimits` | critical | 5m | — |
