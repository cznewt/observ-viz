#!/usr/bin/env python3
"""Render an observ-lib (the container) to 3 dirs — then test/validate/deploy.

An observ-lib handles BOTH the Grafana viz and the Prometheus alerting/recording
rules. This renders one to:

  <out>/dashboards/<uid>.json   full Grafana v2 dashboard resources
  <out>/alerts/<group>.yaml     prometheus alerting rule groups (one file per group)
  <out>/rules/<group>.yaml      prometheus recording rule groups (one file per group)

  render-lib.py <lib.dotted.path> [--out DIR] [--config '{json}'] [--validate] [--deploy]
  e.g.  render-lib.py iot.homeAssistant --validate

--validate runs structural checks (+ promtool on the rule files if installed).
--deploy pushes dashboards to Grafana (v2 API, like load.py) and, if
MIMIR_RULER_URL is set, the rule groups to the Mimir ruler.
"""
import argparse
import json
import os
import subprocess
import sys
from shutil import which

import _jsonnet

try:
    import yaml
except ImportError:
    yaml = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def render(lib, config):
    snip = (
        f"local lib=(import 'g.libsonnet').libs.{lib}.new({config});"
        "local dbs=if std.objectHas(lib.grafana,'dashboards') then lib.grafana.dashboards"
        "  else {{ [lib.config.uid+'.json']: lib.grafana.dashboard }};"
        "{{"
        " dashboards: {{ [k]: dbs[k].toResource() for k in std.objectFields(dbs) }},"
        " alerts: (if std.objectHas(lib,'prometheus') then lib.prometheus.alerts else []),"
        " rules: (if std.objectHas(lib,'prometheus') && std.objectHas(lib.prometheus,'rules')"
        "   then lib.prometheus.rules else []),"
        "}}"
    ).replace("{{", "{").replace("}}", "}")
    return json.loads(_jsonnet.evaluate_snippet("t", snip, jpathdir=[ROOT]))


def slug(s):
    return s.replace("/", "_").replace(":", "_")


def write_groups(groups, outdir):
    os.makedirs(outdir, exist_ok=True)
    out = []
    for g in groups:
        fn = os.path.join(outdir, slug(g["name"]) + ".yaml")
        doc = {"groups": [g]}
        with open(fn, "w") as fh:
            if yaml:
                yaml.safe_dump(doc, fh, sort_keys=False, default_flow_style=False)
            else:
                json.dump(doc, fh, indent=2)
        out.append((os.path.basename(fn), len(g.get("rules", []))))
    return out


def validate(m, alerts_dir, rules_dir):
    errs = []
    for kind, groups in (("alert", m["alerts"]), ("record", m["rules"])):
        for g in groups:
            if not g.get("name"):
                errs.append(f"{kind} group without a name")
            for r in g.get("rules", []):
                if kind not in r:
                    errs.append(f"{g['name']}: a rule is missing '{kind}'")
                if not r.get("expr"):
                    errs.append(f"{g['name']}: a rule is missing 'expr'")
    for name, d in m["dashboards"].items():
        if d.get("kind") != "Dashboard" or "spec" not in d:
            errs.append(f"dashboard {name}: not a v2 Dashboard resource")
    promtool = False
    if which("promtool"):
        promtool = True
        for d in (alerts_dir, rules_dir):
            for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
                r = subprocess.run(["promtool", "check", "rules", os.path.join(d, f)],
                                   capture_output=True, text=True)
                if r.returncode != 0:
                    errs.append(f"promtool {f}: {(r.stderr or r.stdout).strip()}")
    return errs, promtool


def deploy(m, lib):
    import load
    print("  deploy: dashboards -> Grafana")
    for name, d in m["dashboards"].items():
        load.push_doc(json.loads(json.dumps(d)), lib)
    ruler = os.environ.get("MIMIR_RULER_URL")
    if ruler and yaml:
        import urllib.request
        org = os.environ.get("MIMIR_ORG_ID", "anonymous")
        for g in m["alerts"] + m["rules"]:
            req = urllib.request.Request(
                f"{ruler}/prometheus/config/v1/rules/observ-viz",
                data=yaml.safe_dump(g).encode(), method="POST")
            req.add_header("X-Scope-OrgID", org)
            req.add_header("Content-Type", "application/yaml")
            try:
                urllib.request.urlopen(req)
                print(f"    OK   rule group {g['name']} -> mimir ruler")
            except Exception as e:  # noqa: BLE001
                print(f"    FAIL rule group {g['name']}: {e}")
    elif m["alerts"] or m["rules"]:
        print("  deploy: set MIMIR_RULER_URL to push rule groups to the Mimir ruler")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("lib", help="observ-lib dotted path, e.g. iot.homeAssistant")
    ap.add_argument("--out")
    ap.add_argument("--config", default="{}")
    ap.add_argument("--validate", action="store_true")
    ap.add_argument("--deploy", action="store_true")
    a = ap.parse_args()
    out = a.out or os.path.join(ROOT, "build", slug(a.lib))

    m = render(a.lib, a.config)

    dd = os.path.join(out, "dashboards")
    os.makedirs(dd, exist_ok=True)
    for name, d in m["dashboards"].items():
        fn = name if name.endswith(".json") else name + ".json"
        with open(os.path.join(dd, fn), "w") as fh:
            json.dump(d, fh, indent=2, sort_keys=True)
    ad, rd = os.path.join(out, "alerts"), os.path.join(out, "rules")
    na = write_groups(m["alerts"], ad)
    nr = write_groups(m["rules"], rd)

    print(f"{a.lib} -> {out}/")
    print(f"  dashboards/ : {len(m['dashboards'])} -> {sorted(m['dashboards'])}")
    print(f"  alerts/     : {len(na)} group(s) -> {[f for f, _ in na]} ({sum(n for _, n in na)} rules)")
    print(f"  rules/      : {len(nr)} group(s) -> {[f for f, _ in nr]} ({sum(n for _, n in nr)} rules)")

    if a.validate:
        errs, promtool = validate(m, ad, rd)
        if errs:
            print("  validate: FAILED")
            for e in errs:
                print("    -", e)
            sys.exit(1)
        print(f"  validate: OK ({'promtool + structural' if promtool else 'structural'})")
    if a.deploy:
        deploy(m, a.lib)


if __name__ == "__main__":
    main()
