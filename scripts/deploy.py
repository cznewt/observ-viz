#!/usr/bin/env python3
"""observ-viz deployer — render a deployment profile's observ-lib boards and
apply them to Grafana (into the profile's folder), then point at its Alloy config.

Usage:
  python3 scripts/deploy.py --list
  python3 scripts/deploy.py <profile>          # e.g. linux-server
  python3 scripts/deploy.py all                # every profile

Env: GRAFANA_URL / GRAFANA_USER / GRAFANA_PASS / GRAFANA_NAMESPACE (see load.py)
"""
import json
import os
import sys

import _jsonnet

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import load  # reuse push_doc / ensure_folder / API config

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCEN = os.path.join(ROOT, "scenarios")


def profiles():
    return sorted(
        d for d in os.listdir(SCEN)
        if os.path.isdir(os.path.join(SCEN, d))
        and os.path.exists(os.path.join(SCEN, d, "render.jsonnet"))
    )


def deploy(name):
    render = os.path.join(SCEN, name, "render.jsonnet")
    if not os.path.exists(render):
        print(f"  unknown profile: {name}")
        return
    docs = json.loads(_jsonnet.evaluate_file(render, jpathdir=[ROOT]))
    boards = [d for d in docs.values() if isinstance(d, dict) and d.get("kind") == "Dashboard"]
    print(f"[{name}] deploying {len(boards)} board(s)")
    for doc in boards:
        load.push_doc(doc, name)
    alloy = os.path.join("scenarios", name, "alloy.alloy")
    print(f"[{name}] Alloy config: {alloy}  (point Alloy at it; METRICS_URL/LOGS_URL -> Mimir/Loki)")


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("--list", "-l"):
        print("deployment profiles:")
        for p in profiles():
            print(f"  - {p}")
        return
    if args[0] == "all":
        for p in profiles():
            deploy(p)
    else:
        for name in args:
            deploy(name)


if __name__ == "__main__":
    main()
