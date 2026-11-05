#!/usr/bin/env python3
"""Every $variable a board's queries read must be declared on that board.

An undeclared reference is invisible in review and fatal at runtime: Grafana
sends the literal `$instance` to Prometheus, the query errors, and the panel is
silently empty. This caught the Analysis boards after a change that built a
cascading variable only when the pack-level selector mentioned it, while the
panels filtered on it.

Builtins ($__rate_interval and friends) and Grafana's own $__all/$__field/... are
ignored, as are the repeat/regex modifiers (${var:regex}).

Three more mistakes that render, review and deploy fine, and only show on the board:
- `offset` inside a selector's braces, `up{job="x" offset 7d}`: a parse error, so
  the panel errors. The capacity boards shipped one for a month.
- a subquery over a window a variable chooses, in a range query: months of data
  evaluated once per dashboard step, which is minutes, for a number a table reads
  once. It has to be instant.
- a filter variable asking `up` for a label it cannot have. `up` carries a scrape
  target's labels and no others, so the variable comes out empty, `label=~""`
  matches nothing and the board says No data. Name the series with `varMetric`.
  An analysis board reads someone else's metrics, so there it goes for every filter
  but the job: `up` lists only what has a scrape target, and the rest go missing
  with no sign of it (35 of 57 namespaces on one fleet).
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


# a string can say anything, so strings are blanked first
STRING = re.compile(r'"(?:[^"\\]|\\.)*"')
OFFSET_IN_SELECTOR = re.compile(r"\{[^{}]*\boffset\b")
# [${window}s:1h], [$window:1h]
VARIABLE_SUBQUERY = re.compile(r"\[\$\{?\w+\}?[a-z]*:")
# label_values(up, x), label_values(up{job=~"$job"}, x)
UP_VARIABLE = re.compile(r"label_values\(up(?:\{.*\})?,\s*(\w+)\)")
TARGET_LABELS = {"job", "instance", "cluster", "namespace", "pod", "container", "node", "service", "endpoint"}


def queries_in(node):
    """Every query of a board's elements: (panel title, query spec)."""
    for element in node.values():
        spec = element.get("spec", {})
        for query in spec.get("data", {}).get("spec", {}).get("queries", []):
            inner = query.get("spec", {}).get("query", {}).get("spec", {})
            if isinstance(inner.get("expr"), str):
                yield spec.get("title", "?"), inner


def query_defects(spec):
    defects = []
    for title, query in queries_in(spec.get("elements", {})):
        expr = STRING.sub('""', query["expr"])
        if OFFSET_IN_SELECTOR.search(expr):
            defects.append(f"{title}: offset inside a selector")
        if VARIABLE_SUBQUERY.search(expr) and not query.get("instant"):
            defects.append(f"{title}: a subquery over a variable window that is not instant")
    return defects


def up_variables(name, spec):
    """The labels a board's filter variables ask `up` for and should not."""
    allowed = {"job"} if name.startswith("ref:analysis-") else TARGET_LABELS
    labels = set()
    for variable in spec.get("variables", []):
        var = variable.get("spec", {})
        query = var.get("query")
        # the hidden ones gate the pod rows, and name no filter
        if isinstance(query, dict) and var.get("hide") != "hideVariable":
            found = UP_VARIABLE.search(query.get("spec", {}).get("query") or "")
            if found and found.group(1) not in allowed:
                labels.add(found.group(1))
    return sorted(labels)


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
        defects = query_defects(spec)
        if defects:
            fails += 1
            print("  FAIL %s: %s" % (name, "; ".join(sorted(set(defects)))))
        asks_up = up_variables(name, spec)
        if asks_up:
            fails += 1
            print("  FAIL %s: asks `up` for %s; name the series with varMetric" % (name, ", ".join(asks_up)))
    print("\n%d boards checked, %d with undeclared variable references or bad queries" % (checked, fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
