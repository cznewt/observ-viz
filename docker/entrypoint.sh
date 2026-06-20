#!/usr/bin/env bash
# observ-viz image CLI. The observ-viz library is at $OBSERV_VIZ_HOME on the
# jpath, so consumer manifests can import it without vendoring.
set -euo pipefail
H="${OBSERV_VIZ_HOME:-/observ-viz}"
cmd="${1:-help}"; shift || true
case "$cmd" in
  render)  exec python3 "$H/scripts/render.py" "$@" ;;       # render a manifest -> v2 JSON
  render-lib) exec python3 "$H/scripts/render-lib.py" "$@" ;;  # render an observ-lib -> dashboards/+alerts/+rules/
  load)    exec python3 "$H/scripts/load.py" "$@" ;;         # apply dashboards to Grafana (v2 API)
  deploy)  exec python3 "$H/scripts/deploy.py" "$@" ;;       # deploy a scenario profile
  catalog) exec python3 "$H/scripts/gen-catalog.py" "$@" ;;  # backstage catalog
  jb)      exec jb "$@" ;;                                    # jsonnet-bundler (vendoring)
  sh|bash) exec /bin/bash ;;
  version) cat "$H/VERSION" 2>/dev/null || echo "unknown" ;;
  help|*)
    cat <<EOF
observ-viz — render Grafana v2 dashboards from Jsonnet.

  render <file.jsonnet> [-m <dir>] [-J <path>]   render a manifest to v2 JSON
  render-lib <lib> [--validate] [--deploy]        render a bundled observ-lib
                                                  -> build/<lib>/{dashboards,alerts,rules}/
  load   <file.jsonnet> ...                       apply dashboards to Grafana
  deploy <profile> | all                          deploy a scenario profile
  catalog                                          emit the Backstage catalog
  jb ...                                           jsonnet-bundler
  sh                                               a shell

The library is at \$OBSERV_VIZ_HOME ($H), already on the jpath. Mount your repo
at /work:
  docker run --rm -v "\$PWD":/work ghcr.io/cznewt/observ-lib \\
    render operations/home-assistant-observ-lib/render.jsonnet
EOF
    ;;
esac
