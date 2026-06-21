#!/usr/bin/env python3
"""Deploy a set of observ-libs into one Grafana folder (a "domain").

  deploy-domain.py "<Folder Title>" <lib.path> [<lib.path> ...]
  e.g. deploy-domain.py "Runtimes" runtimes.golang runtimes.jvm

Honours the same Grafana env as load.py.
"""
import json
import os
import re
import sys

import _jsonnet

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import load  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    title = sys.argv[1]
    libs = sys.argv[2:]
    uid = "observ-viz-" + re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    print(f"Deploying {len(libs)} board(s) into folder '{title}' ({uid})")
    for p in libs:
        snip = (
            f"local g=import 'g.libsonnet';"
            f"(g.libs.{p}.new({{}}).grafana.dashboard + g.dashboard.withFolder('{uid}', '{title}')).toResource()"
        )
        doc = json.loads(_jsonnet.evaluate_snippet("t", snip, jpathdir=[ROOT]))
        load.push_doc(doc, p)


if __name__ == "__main__":
    main()
