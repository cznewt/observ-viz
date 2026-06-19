#!/usr/bin/env python3
"""observ-viz local compile + structural verification (no docker required).

Evaluates each example via the Python _jsonnet binding and asserts v2 structural
invariants, then (if a matching tests/golden/<name>.json exists) diffs the output
against the committed golden.

Run:  python3 tests/compile.py
"""
import json
import os
import sys

import _jsonnet

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXAMPLES_DIR = os.path.join(ROOT, "examples")
GOLDEN_DIR = os.path.join(ROOT, "tests", "golden")

# Auto-discover examples; *.mixin.jsonnet / mixin.libsonnet are not dashboards.
def discover_examples():
    out = []
    for fn in sorted(os.listdir(EXAMPLES_DIR)):
        if not fn.endswith(".jsonnet"):
            continue
        if fn.endswith(".mixin.jsonnet") or fn == "render.jsonnet":
            continue
        out.append(fn)
    return out


def evaluate(path):
    return json.loads(_jsonnet.evaluate_file(path, jpathdir=[ROOT]))


def collect_refs(layout):
    kind = layout.get("kind")
    spec = layout.get("spec", {})
    if kind in ("GridLayout", "AutoGridLayout"):
        return [it["spec"]["element"]["name"] for it in spec.get("items", [])]
    if kind == "RowsLayout":
        out = []
        for row in spec.get("rows", []):
            out += collect_refs(row["spec"]["layout"])
        return out
    if kind == "TabsLayout":
        out = []
        for tab in spec.get("tabs", []):
            out += collect_refs(tab["spec"]["layout"])
        return out
    return []


def check_dashboard(name, doc):
    errors = []
    assert doc.get("apiVersion", "").startswith("dashboard.grafana.app/"), \
        f"{name}: missing/invalid apiVersion"
    assert doc.get("kind") == "Dashboard", f"{name}: kind != Dashboard"
    spec = doc["spec"]
    elements = spec.get("elements", {})
    layout = spec.get("layout", {})

    refs = collect_refs(layout)
    # Every ElementReference must resolve to a defined element.
    for r in refs:
        if r not in elements:
            errors.append(f"{name}: layout references undefined element '{r}'")
    # Warn (not fail) on orphan elements never referenced by the layout.
    for el in elements:
        if el not in refs:
            print(f"  WARN {name}: element '{el}' defined but never referenced")

    # Panel ids must be unique.
    ids = [
        e["spec"]["id"]
        for e in elements.values()
        if e.get("kind") == "Panel"
    ]
    if len(ids) != len(set(ids)):
        errors.append(f"{name}: duplicate panel ids {ids}")

    # refIds unique within each panel's query group.
    for el_name, e in elements.items():
        if e.get("kind") != "Panel":
            continue
        queries = e["spec"].get("data", {}).get("spec", {}).get("queries", [])
        refids = [q["spec"].get("refId") for q in queries]
        if len(refids) != len(set(refids)):
            errors.append(f"{name}: duplicate refIds in element '{el_name}': {refids}")
        if any(r is None for r in refids):
            errors.append(f"{name}: unassigned refId in element '{el_name}'")
    return errors


def maybe_golden(name, doc):
    golden = os.path.join(GOLDEN_DIR, name.replace(".jsonnet", ".json"))
    if not os.path.exists(golden):
        return []
    with open(golden) as fh:
        expected = json.load(fh)
    if json.dumps(doc, sort_keys=True) != json.dumps(expected, sort_keys=True):
        return [f"{name}: output differs from golden {golden}"]
    return []


def main():
    all_errors = []
    ran = 0
    for name in discover_examples():
        path = os.path.join(EXAMPLES_DIR, name)
        if not os.path.exists(path):
            continue
        ran += 1
        try:
            doc = evaluate(path)
        except Exception as exc:  # noqa: BLE001
            all_errors.append(f"{name}: COMPILE ERROR: {exc}")
            continue
        all_errors += check_dashboard(name, doc)
        all_errors += maybe_golden(name, doc)
        if not any(e.startswith(name) for e in all_errors):
            print(f"  OK   {name}")

    if all_errors:
        print("\nFAILURES:")
        for e in all_errors:
            print(f"  - {e}")
        sys.exit(1)
    print(f"\nAll {ran} example(s) compiled and passed structural checks.")


if __name__ == "__main__":
    main()
