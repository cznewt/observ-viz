# observ-viz — render Grafana v2 dashboards from Jsonnet manifests.
# The library lives at /observ-viz (on the jpath), so consumer manifests can
# `import 'g.libsonnet'` / `import 'libs/common-lib/...'` without vendoring.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates bash \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir jsonnet pyyaml requests

# jsonnet-bundler (jb), for consumers that vendor additional deps
ARG JB_VERSION=v0.6.0
RUN curl -fsSL -o /usr/local/bin/jb \
      "https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/${JB_VERSION}/jb-linux-amd64" \
 && chmod +x /usr/local/bin/jb

ENV OBSERV_VIZ_HOME=/observ-viz
COPY . /observ-viz
RUN chmod +x /observ-viz/docker/entrypoint.sh

WORKDIR /work
ENTRYPOINT ["/observ-viz/docker/entrypoint.sh"]
CMD ["help"]
