#!/usr/bin/env python3
"""Render observ-viz dashboard examples and push them to a local Grafana via the
v2 app-platform (kubernetes-style) API.

Usage:  python3 scripts/load.py [example.jsonnet ...]
Env:    GRAFANA_URL (default http://localhost:3000)
        GRAFANA_USER / GRAFANA_PASS (default admin/admin)
        GRAFANA_NAMESPACE (default default)
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.request

import _jsonnet

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXAMPLES = os.path.join(ROOT, "examples")
URL = os.environ.get("GRAFANA_URL", "http://localhost:3000")
USER = os.environ.get("GRAFANA_USER", "admin")
PASS = os.environ.get("GRAFANA_PASS", "admin")
NS = os.environ.get("GRAFANA_NAMESPACE", "default")
API = f"{URL}/apis/dashboard.grafana.app/v2beta1/namespaces/{NS}/dashboards"
AUTH = "Basic " + base64.b64encode(f"{USER}:{PASS}".encode()).decode()


def req(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Authorization", AUTH)
    r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def push(path):
    doc = json.loads(_jsonnet.evaluate_file(path, jpathdir=[ROOT]))
    if doc.get("kind") != "Dashboard":
        print(f"  skip {os.path.basename(path)} (not a Dashboard)")
        return
    name = doc["metadata"]["name"]
    # the app-platform wants metadata.namespace on the object too
    doc["metadata"]["namespace"] = NS
    status, _ = req("POST", API, doc)
    if status == 409:  # exists -> replace
        req("DELETE", f"{API}/{name}", None)
        status, body = req("POST", API, doc)
    label = os.path.basename(path)
    if 200 <= status < 300:
        print(f"  OK   {label} -> {URL}/d/{name}")
    else:
        print(f"  FAIL {label} (HTTP {status})")


def main():
    args = sys.argv[1:]
    if args:
        paths = [a if os.path.isabs(a) else os.path.join(EXAMPLES, a) for a in args]
    else:
        paths = [
            os.path.join(EXAMPLES, f)
            for f in sorted(os.listdir(EXAMPLES))
            if f.endswith(".jsonnet") and f != "render.jsonnet"
        ]
    print(f"Pushing {len(paths)} dashboard(s) to {API}")
    for p in paths:
        push(p)


if __name__ == "__main__":
    main()
