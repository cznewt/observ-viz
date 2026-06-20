# Example justfile — render with the observ-viz image (NOTHING installed locally,
# no jb/vendoring). The image bundles observ-viz on the jpath.
# Copy this into your repo as `justfile`.

IMAGE := "ghcr.io/cznewt/observ-lib:latest"
RUN   := "docker run --rm -v \"$PWD\":/work " + IMAGE

# list targets
default:
    @just --list

# render one of YOUR manifests -> Grafana v2 JSON on stdout
#   just render dashboards/my-board.jsonnet > my-board.json
render FILE:
    {{RUN}} render {{FILE}}

# render a manifest -> one file per top-level key, into a dir
render-multi FILE OUT="dashboards_out":
    {{RUN}} render {{FILE}} -m {{OUT}}

# render a BUNDLED observ-lib -> build/<lib>/{dashboards,alerts,rules}/
#   just lib iot.homeAssistant --validate
lib LIB *ARGS:
    {{RUN}} render-lib {{LIB}} {{ARGS}}

# apply your rendered dashboards to a local Grafana (v2 app-platform API)
load FILE:
    docker run --rm --network host -v "$PWD":/work {{IMAGE}} load {{FILE}}
