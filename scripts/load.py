#!/usr/bin/env python3
"""Render observ-viz dashboard examples and push them to a local Grafana via the
v2 app-platform (kubernetes-style) API.

Usage:  python3 scripts/load.py [example.jsonnet ...]
Env:    GRAFANA_URL (default http://localhost:3000)
        GRAFANA_TOKEN (service-account / API token — preferred for any remote
          Grafana incl. Grafana Cloud) OR GRAFANA_USER / GRAFANA_PASS (default admin/admin)
        GRAFANA_NAMESPACE (default default; the org/stack namespace on Grafana Cloud)
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
TOKEN = os.environ.get("GRAFANA_TOKEN")
NS = os.environ.get("GRAFANA_NAMESPACE", "default")
API = f"{URL}/apis/dashboard.grafana.app/v2beta1/namespaces/{NS}/dashboards"
# token auth (any remote Grafana / Grafana Cloud) takes precedence over basic auth.
AUTH = ("Bearer " + TOKEN) if TOKEN else ("Basic " + base64.b64encode(f"{USER}:{PASS}".encode()).decode())


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


_folders_done = set()


def ensure_folder(uid, title=None, parent_uid=None):
    """Create a Grafana folder (idempotent); nest under parent_uid if given."""
    if not uid or uid in _folders_done:
        return
    body = {"uid": uid, "title": title or uid.replace("-", " ").title()}
    if parent_uid:
        body["parentUid"] = parent_uid
    status, _ = req("POST", f"{URL}/api/folders", body)
    if status == 409 and parent_uid:  # already exists -> move under the parent
        req("POST", f"{URL}/api/folders/{uid}/move", {"parentUid": parent_uid})
    _folders_done.add(uid)


def docs_from_file(path):
    """A file may evaluate to one Dashboard resource or a map { name: resource }."""
    val = json.loads(_jsonnet.evaluate_file(path, jpathdir=[ROOT]))
    if isinstance(val, dict) and val.get("kind") == "Dashboard":
        return [val]
    if isinstance(val, dict):
        return [v for v in val.values() if isinstance(v, dict) and v.get("kind") == "Dashboard"]
    return []


def push_doc(doc, label):
    name = doc["metadata"]["name"]
    doc["metadata"]["namespace"] = NS
    anns = doc.get("metadata", {}).get("annotations", {})
    folder = anns.get("grafana.app/folder")
    title = anns.pop("observ-viz.dev/folder-title", None)  # private hint -> strip before push
    parent_uid = anns.pop("observ-viz.dev/folder-parent-uid", None)
    parent_title = anns.pop("observ-viz.dev/folder-parent-title", None)
    if parent_uid:
        ensure_folder(parent_uid, parent_title)
    ensure_folder(folder, title, parent_uid)
    status, _ = req("POST", API, doc)
    if status == 409:  # exists -> replace
        req("DELETE", f"{API}/{name}", None)
        status, _ = req("POST", API, doc)
    fld = f" [folder: {folder}]" if folder else ""
    if 200 <= status < 300:
        print(f"  OK   {label}:{name}{fld} -> {URL}/d/{name}")
    else:
        print(f"  FAIL {label}:{name} (HTTP {status})")


def push(path):
    docs = docs_from_file(path)
    if not docs:
        print(f"  skip {os.path.basename(path)} (no Dashboard)")
        return
    for doc in docs:
        push_doc(doc, os.path.basename(path))


def main():
    args = sys.argv[1:]
    if args:
        paths = [
            a if (os.path.isabs(a) or os.path.exists(a)) else os.path.join(EXAMPLES, a)
            for a in args
        ]
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
