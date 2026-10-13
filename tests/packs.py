#!/usr/bin/env python3
"""Verify every observ-viz pack renders end-to-end to a valid v2 Dashboard."""
import json
import os
import re
import sys

import _jsonnet

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PACKS = [
    "databases.kv.etcd", "databases.kv.memcached", "databases.kv.redis",
    "databases.sql.mysql", "databases.sql.postgres",
    "databases.document.mongodb", "databases.search.elasticsearch",
    "monitoring.prometheus", "monitoring.mimir", "monitoring.loki", "monitoring.grafana",
    "monitoring.tempo", "monitoring.pyroscope", "monitoring.alertmanager", "monitoring.alertHandler", "monitoring.opencost", "monitoring.anomalyExporter",
    "monitoring.blackboxExporter", "monitoring.pushgateway", "monitoring.statsdExporter", "monitoring.kubeStateMetrics",
    "collector.alloy",
    "system.linux", "system.docker", "system.windows", "system.systemd", "system.processExporter", "system.windowsService", "system.proxmox",
    "networking.ingressNginx", "networking.kong", "networking.traefik", "networking.envoy",
    "kubernetes.pod", "kubernetes.cadvisor", "kubernetes.coredns", "kubernetes.certManager",
    "runtimes.golang", "runtimes.jvm", "runtimes.python", "runtimes.dotnet", "runtimes.nodejs", "runtimes.process", "runtimes.rust", "runtimes.php", "runtimes.ruby", "runtimes.beam",
    "services.alloy", "services.k8sMonitoring", "services.grafana", "services.grafanaTest", "services.mimir", "services.loki", "services.tempo", "services.pyroscope", "services.prometheus", "services.redisTest", "services.demoGo", "services.demoPython", "services.demoJvm", "services.backstage", "services.alertmanager", "services.alertHandler", "services.opencost", "services.anomalyExporter", "services.argocd",
    "alerts",
    "backstage", "instrumentation.httpServer", "instrumentation.httpClient", "instrumentation.rpc", "instrumentation.messaging", "instrumentation.otelSdk",
    "webservers.nginx", "webservers.caddy", "webservers.apache", "frameworks.django", "frameworks.rails", "frameworks.wagtail", "frameworks.wordpress",
    "cicd.argocd", "cicd.backstage", "cicd.vault",
    "analysis.red", "analysis.use", "analysis.anomaly", "analysis.golden", "analysis.burnRate", "analysis.capacity",
    "applications.valheim", "applications.minecraft", "applications.minio",
    "networking.pangolin",
    "demos.demoApp",
    "logs",
]

# Packs whose Overview Instances table still shows one of several series per
# row (a column grouped by a label beyond the row labels). Each needs its own
# per-row overview signals, as kubernetes.cadvisor has; a pack fixed here must
# leave this list, or the run fails.
KNOWN_ROW_CLASHES = {
    "databases.sql.postgres",
    "monitoring.grafana", "monitoring.alertmanager", "monitoring.alertHandler", "monitoring.anomalyExporter",
    "system.docker", "system.systemd", "system.processExporter",
    "services.grafana", "services.grafanaTest", "services.backstage", "services.alertmanager", "services.alertHandler",
    "services.opencost", "services.anomalyExporter", "services.argocd",
    "instrumentation.httpServer", "instrumentation.httpClient", "instrumentation.rpc", "instrumentation.messaging",
    "webservers.caddy", "frameworks.django", "frameworks.rails",
    "cicd.argocd",
}


AGG_BY = re.compile(r"\b(?:sum|max|min|avg|count|stddev|stdvar|group)\s*by\s*\(([^)]*)\)\s*\(")
ROW_JOIN = re.compile(r'^label_join\((.*), "__row__", "/", (.*)\)$', re.S)


def outer_by_labels(expr):
    """Label sets of the `by` aggregations not nested inside another one."""
    spans, found = [], []
    for m in AGG_BY.finditer(expr):
        if any(start <= m.start() < end for start, end in spans):
            continue
        depth, end = 1, m.end()
        while end < len(expr) and depth:
            depth += {"(": 1, ")": -1}.get(expr[end], 0)
            end += 1
        spans.append((m.start(), end))
        found.append({label.strip() for label in m.group(1).split(",") if label.strip()})
    return found


def instance_row_clashes(dashboard):
    """The Overview's Instances table joins its columns on __row__, so a column
    query may return only one series per row: an outer aggregation that keeps
    labels beyond the row labels (le aside) leaves one value standing for many."""
    table = dashboard["spec"]["elements"].get("__instances")
    if not table:
        return []
    clashes = []
    for query in table["spec"]["data"]["spec"]["queries"]:
        m = ROW_JOIN.match(query["spec"]["query"]["spec"]["expr"])
        if not m:
            continue
        rows = set(re.findall(r'"([^"]+)"', m.group(2)))
        for labels in outer_by_labels(m.group(1)):
            extra = labels - rows - {"le"}
            if extra:
                clashes.append(f"{query['spec'].get('refId')} keeps {', '.join(sorted(extra))}")
    return clashes


def main():
    fail = 0
    for p in PACKS:
        snippet = f"(import 'g.libsonnet').libs.{p}.new({{}}).grafana.dashboard.toResource()"
        try:
            d = json.loads(_jsonnet.evaluate_snippet("t", snippet, jpathdir=[ROOT]))
            assert d["kind"] == "Dashboard"
            assert d["spec"]["elements"], "no elements"
            clashes = instance_row_clashes(d)
            if p in KNOWN_ROW_CLASHES:
                assert clashes, "Instances rows are unique now; drop it from KNOWN_ROW_CLASHES"
            else:
                assert not clashes, "Instances rows not unique: " + "; ".join(clashes)
            known = " (known Instances row clash)" if clashes else ""
            print(f"  OK   {p}: {len(d['spec']['elements'])} elements{known}")
        except Exception as exc:  # noqa: BLE001
            fail += 1
            print(f"  FAIL {p}: {str(exc).splitlines()[0]}")
    print(f"\n{len(PACKS) - fail}/{len(PACKS)} packs OK")
    if fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
