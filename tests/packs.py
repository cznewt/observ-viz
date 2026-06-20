#!/usr/bin/env python3
"""Verify every observ-viz pack renders end-to-end to a valid v2 Dashboard."""
import json
import os
import sys

import _jsonnet

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PACKS = [
    "databases.kv.etcd", "databases.kv.memcached", "databases.kv.redis",
    "databases.sql.mysql", "databases.sql.postgres",
    "databases.timeseries.loki", "databases.timeseries.mimir",
    "databases.timeseries.tempo", "databases.timeseries.pyroscope",
    "collector.alloy",
    "system.linux", "system.docker", "system.windows",
    "kubernetes.pod", "kubernetes.cadvisor",
    "runtimes.golang", "runtimes.jvm", "runtimes.python", "runtimes.dotnet", "runtimes.nodejs",
    "infra.prometheus",
    "iot.homeAssistant",
]


def main():
    fail = 0
    for p in PACKS:
        snippet = f"(import 'g.libsonnet').libs.{p}.new({{}}).grafana.dashboard.toResource()"
        try:
            d = json.loads(_jsonnet.evaluate_snippet("t", snippet, jpathdir=[ROOT]))
            assert d["kind"] == "Dashboard"
            assert d["spec"]["elements"], "no elements"
            print(f"  OK   {p}: {len(d['spec']['elements'])} elements")
        except Exception as exc:  # noqa: BLE001
            fail += 1
            print(f"  FAIL {p}: {str(exc).splitlines()[0]}")
    print(f"\n{len(PACKS) - fail}/{len(PACKS)} packs OK")
    if fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
