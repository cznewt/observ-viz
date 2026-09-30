# Minecraft  (`g.libs.applications.minecraft`)

Dashboard uid `observ-viz-minecraft` · 16 signals · 2 alerts · 0 recording rules.

## Signals

Each signal's dashboard query (metric/expr) and the recording rule it produces (if any).

| Signal | Unit | Query | Recorded as |
|--------|------|-------|-------------|
| `containerReady` | short | `max by (server) (label_replace(kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"}, "server", "$1", "container", "minecraft-java-(.*)"))` | — |
| `cpu` | short | `sum by (server) (label_replace(rate(container_cpu_usage_seconds_total{job=~".*cadvisor", cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"}[$__rate_interval]), "server", "$1", "container", "minecraft-java-(.*)"))` | — |
| `events` | short | `{cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"} \|~ `joined the game\|left the game\|\[connected player\] .* has (dis)?connected`` | — |
| `joins` | short | `sum by (server) (label_replace(count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"} \|~ `joined the game\|\[connected player\] .* has connected` [$__auto]), "server", "$1", "container", "minecraft-java-(.*)"))` | — |
| `joinsRange` | short | `sum(count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server", container!~"minecraft-java-.*proxy"} \|~ `joined the game\|\[connected player\] .* has connected` [$__range])) or vector(0)` | — |
| `leaves` | short | `sum by (server) (label_replace(count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"} \|~ `left the game\|\[connected player\] .* has disconnected` [$__auto]), "server", "$1", "container", "minecraft-java-(.*)"))` | — |
| `loginsRange` | short | `sum(count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server", container=~"minecraft-java-.*proxy"} \|~ `joined the game\|\[connected player\] .* has connected` [$__range])) or vector(0)` | — |
| `logs` | short | `{cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"} !~ `Players stats have been saved\|\[mc-image-helper\]\|\[ChunkHolderManager\]\|^\s*$\|^</?(html\|head\|body\|hr\|center)`` | — |
| `memory` | bytes | `sum by (server) (label_replace(container_memory_working_set_bytes{job=~".*cadvisor", cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"}, "server", "$1", "container", "minecraft-java-(.*)"))` | — |
| `playersOnline` | short | `sum by (server) (label_replace(last_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"} \|~ `joined the game\|left the game\|\[connected player\] .* has (dis)?connected` \| regexp `(?:\]: (?:\x1b\[[0-9;]*m)?\|\[connected player\] )(?P<player>\w{1,16})(?: \([^)]*\))? (?P<event>joined\|left\|has connected\|has disconnected)` \| player != "" \| label_format online=`{{ if or (eq .event "joined") (eq .event "has connected") }}1{{ else }}0{{ end }}` \| unwrap online [12h]) by (container, player), "server", "$1", "container", "minecraft-java-(.*)"))` | — |
| `playersTotal` | short | `sum(last_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server", container!~"minecraft-java-.*proxy"} \|~ `joined the game\|left the game\|\[connected player\] .* has (dis)?connected` \| regexp `(?:\]: (?:\x1b\[[0-9;]*m)?\|\[connected player\] )(?P<player>\w{1,16})(?: \([^)]*\))? (?P<event>joined\|left\|has connected\|has disconnected)` \| player != "" \| label_format online=`{{ if or (eq .event "joined") (eq .event "has connected") }}1{{ else }}0{{ end }}` \| unwrap online [12h]) by (container, player)) or vector(0)` | — |
| `problems` | short | `sum by (server) (label_replace(count_over_time({cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"} \|~ `(?:[ /])(?:WARN\|ERROR)\]` [$__auto]), "server", "$1", "container", "minecraft-java-(.*)"))` | — |
| `restarts` | short | `sum by (server) (label_replace(increase(kube_pod_container_status_restarts_total{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"}[1h]), "server", "$1", "container", "minecraft-java-(.*)"))` | — |
| `restartsRange` | short | `sum(increase(kube_pod_container_status_restarts_total{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"}[$__range]))` | — |
| `serversNotReady` | short | `count(max by (container) (kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"}) == 0) or vector(0)` | — |
| `serversReady` | short | `sum(max by (container) (kube_pod_container_status_ready{job=~".*kube-state-metrics", cluster=~"$cluster", namespace=~"$namespace", container=~"minecraft-java-$server"}))` | — |

## Dashboard

- **Status** — `s1_ready`, `s2_notready`, `s3_players`, `s4_logins`, `s5_joins`, `s6_restarts`
- **Servers** — `t1_servers`

## Alerts

| Alert | Severity | For | Runbook |
|-------|----------|-----|---------|
| `MinecraftServerDown` | critical | 5m | — |
| `MinecraftServerCrashLooping` | warning | 5m | — |
