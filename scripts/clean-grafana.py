#!/usr/bin/env python3
"""Delete all dashboards + folders from a Grafana (clean slate for incremental
deploys). Honours the same env as load.py: GRAFANA_URL / GRAFANA_TOKEN or
GRAFANA_USER+GRAFANA_PASS / GRAFANA_NAMESPACE.
"""
import base64
import json
import os
import urllib.error
import urllib.request

URL = os.environ.get("GRAFANA_URL", "http://localhost:3000")
USER = os.environ.get("GRAFANA_USER", "admin")
PASS = os.environ.get("GRAFANA_PASS", "admin")
TOKEN = os.environ.get("GRAFANA_TOKEN")
AUTH = ("Bearer " + TOKEN) if TOKEN else ("Basic " + base64.b64encode(f"{USER}:{PASS}".encode()).decode())


def req(method, path, body=None):
    r = urllib.request.Request(URL + path, data=(json.dumps(body).encode() if body else None), method=method)
    r.add_header("Authorization", AUTH)
    r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def main():
    st, b = req("GET", "/api/search?type=dash-db")
    dashes = json.loads(b) if 200 <= st < 300 else []
    for d in dashes:
        s, _ = req("DELETE", "/api/dashboards/uid/" + d["uid"])
        print(("  del dash   " + d["title"]) if 200 <= s < 300 else (f"  FAIL dash {d['title']} ({s})"))
    st, b = req("GET", "/api/folders")
    folders = json.loads(b) if 200 <= st < 300 else []
    for f in folders:
        s, _ = req("DELETE", "/api/folders/" + f["uid"])
        print(("  del folder " + f["title"]) if 200 <= s < 300 else (f"  FAIL folder {f['title']} ({s})"))
    print(f"cleaned {URL}: {len(dashes)} dashboard(s), {len(folders)} folder(s)")


if __name__ == "__main__":
    main()
