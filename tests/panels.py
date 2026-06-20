#!/usr/bin/env python3
"""Test the common chart types: every common-lib panel preset builds to a valid
v2 vizConfig, and every reference panel board is a tabbed variations board."""
import json
import os
import sys

import _jsonnet

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATEGORIES = ["generic", "cpu", "memory", "disk", "network", "system", "requests", "hardware"]
TD = "[g.query.base('grafana-testdata-datasource',{scenarioId:'random_walk'})+g.query.withDatasource('testdata')]"


def ev(snippet):
    return json.loads(_jsonnet.evaluate_snippet("t", snippet, jpathdir=[ROOT]))


def presets(cat):
    return ev(f"std.objectFields((import 'g.libsonnet').common.panels.{cat})")


def build_preset(cat, name):
    snip = (
        f"local g=import 'g.libsonnet'; local t={TD};"
        f"local p=g.common.panels.{cat}.{name}('Demo', t);"
        "g.dashboard.new('d')+g.dashboard.withElements(g.element.panel('a',p))"
        "+g.dashboard.withLayout(g.layout.grid.new()+g.layout.grid.withItems([g.layout.grid.item('a',0,0,12,8)]))"
    )
    e = ev(snip)["spec"]["elements"]["a"]["spec"]["vizConfig"]
    return e["group"], e["spec"]["fieldConfig"]["defaults"].get("unit")


def main():
    fail = 0
    n = 0
    print("== common-lib base presets ==")
    for cat in CATEGORIES:
        for name in presets(cat):
            n += 1
            try:
                kind, unit = build_preset(cat, name)
                # sanity: a real Grafana viz plugin id
                assert kind and isinstance(kind, str)
            except Exception as exc:  # noqa: BLE001
                fail += 1
                print(f"  FAIL {cat}.{name}: {str(exc).splitlines()[0]}")
        print(f"  {cat}: {len(presets(cat))} presets")

    print("== reference variation boards ==")
    boards = ev("import 'libs/reference-lib/render.jsonnet'")
    panels = {k: v for k, v in boards.items() if k.startswith("panel-")}
    for name in sorted(panels):
        b = panels[name]
        lay = b["spec"]["layout"]
        tabs = [t["spec"]["title"] for t in lay["spec"]["tabs"]] if lay["kind"] == "TabsLayout" else []
        if not tabs or tabs[0] != "Overview":
            fail += 1
            print(f"  FAIL {name}: not a tabbed board with Overview")

    print(f"\n{n} presets + {len(panels)} chart boards checked, {fail} failure(s)")
    if fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
