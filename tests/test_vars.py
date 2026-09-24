#!/usr/bin/env python3
"""Every $variable a board's queries read must be declared on that board.

An undeclared reference is invisible in review and fatal at runtime: Grafana
sends the literal `$instance` to Prometheus, the query errors, and the panel is
silently empty. This caught the Analysis boards after a change that built a
cascading variable only when the pack-level selector mentioned it, while the
panels filtered on it.

Builtins ($__rate_interval and friends) and Grafana's own $__all/$__field/... are
ignored, as are the repeat/regex modifiers (${var:regex}).
"""
import json
import os
import re
import sys

import _jsonnet

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tests"))

from test_schema import LIBS, boards  # noqa: E402  (same board set as the schema test)

# $name, ${name}, ${name:modifier}
REF = re.compile(r"\$\{?([a-zA-Z_][a-zA-Z0-9_.]*)\}?")
BUILTIN_PREFIX = "__"


def refs_in(node, out):
    """Collect variable names referenced anywhere in a board's query expressions."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k in ("expr", "query", "legendFormat", "url") and isinstance(v, str):
                for name in REF.findall(v):
                    if not name.startswith(BUILTIN_PREFIX):
                        out.add(name)
            else:
                refs_in(v, out)
    elif isinstance(node, list):
        for v in node:
            refs_in(v, out)
    return out


def declared(spec):
    return {v["spec"]["name"] for v in spec.get("variables", []) if "name" in v.get("spec", {})}


def main():
    fails = 0
    checked = 0
    for name, spec in sorted(boards().items()):
        have = declared(spec)
        used = refs_in(spec.get("elements", {}), set())
        # a dashboard link may carry vars of the board it points at, not this one
        missing = sorted(used - have)
        checked += 1
        if missing:
            fails += 1
            print("  FAIL %s: reads %s, declares %s"
                  % (name, ", ".join(missing), ", ".join(sorted(have)) or "nothing"))
    print("\n%d boards checked, %d with undeclared variable references" % (checked, fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
