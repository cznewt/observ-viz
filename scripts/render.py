#!/usr/bin/env python3
"""Render a Jsonnet manifest against observ-viz and emit Grafana v2 JSON.

The observ-viz library is on the jpath (OBSERV_VIZ_HOME, default /observ-viz), so
a consumer manifest can `import 'libs/common-lib/...'` / `import 'g.libsonnet'`
without vendoring.

Usage:
  render.py <file.jsonnet>            # -> JSON on stdout
  render.py <file.jsonnet> -m <dir>   # map output -> one .json per key in <dir>

jpath = [OBSERV_VIZ_HOME, cwd, dir(file), <extra -J ...>]
"""
import json
import os
import sys

import _jsonnet

HOME = os.environ.get("OBSERV_VIZ_HOME", "/observ-viz")


def main():
    args = sys.argv[1:]
    outdir = None
    jpath = [HOME, os.getcwd()]
    # parse -m <dir> and -J <path>
    rest = []
    i = 0
    while i < len(args):
        if args[i] == "-m":
            outdir = args[i + 1]; i += 2
        elif args[i] in ("-J", "--jpath"):
            jpath.append(args[i + 1]); i += 2
        else:
            rest.append(args[i]); i += 1
    if not rest:
        print("usage: render.py <file.jsonnet> [-m <dir>] [-J <path> ...]", file=sys.stderr)
        sys.exit(2)
    path = rest[0]
    jpath.append(os.path.dirname(os.path.abspath(path)))

    val = json.loads(_jsonnet.evaluate_file(path, jpathdir=jpath))

    # normalize to a {name: doc} map for -m, or print as-is for stdout
    if outdir:
        if isinstance(val, dict) and val.get("kind"):
            out = {os.path.splitext(os.path.basename(path))[0]: val}
        elif isinstance(val, dict):
            out = val
        else:
            out = {os.path.splitext(os.path.basename(path))[0]: val}
        os.makedirs(outdir, exist_ok=True)
        for name, doc in out.items():
            fn = name if name.endswith(".json") else name + ".json"
            with open(os.path.join(outdir, fn), "w") as fh:
                json.dump(doc, fh, indent=2, sort_keys=True)
        print(f"wrote {len(out)} file(s) to {outdir}")
    else:
        json.dump(val, sys.stdout, indent=2, sort_keys=True)
        print()


if __name__ == "__main__":
    main()
