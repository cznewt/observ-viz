#!/usr/bin/env python3
"""Validate every rendered board against the foundation-sdk v2beta1 JSON schema
(generator/schemas/dashboardv2beta1.jsonschema.json, def `Dashboard`).

This catches v2 structure bugs — wrong enum (e.g. variable hide as int), wrong
kind tag, wrong type, or stray fields — the kind Grafana's v2 API rejects. We
IGNORE `required` violations: the schema marks many fields required that Grafana
fills with server-side defaults and that our minimal boards legitimately omit.
"""
import json
import os
import sys

import copy

import _jsonnet
from jsonschema.validators import validator_for

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCHEMA = json.load(open(os.path.join(ROOT, "generator/schemas/dashboardv2beta1.jsonschema.json")))


def _strip_required(node):
    """Drop every `required` constraint so validation checks structure/enums/types
    (the real bugs) without flagging Grafana-default fields our minimal boards omit
    — otherwise the per-kind oneOf branches never match."""
    if isinstance(node, dict):
        node.pop("required", None)
        for v in node.values():
            _strip_required(v)
    elif isinstance(node, list):
        for v in node:
            _strip_required(v)
    return node


_DEFS = _strip_required(copy.deepcopy(SCHEMA["definitions"]))
# The SDK types these as `object`, but Grafana accepts any: field-override values
# are unit strings / link arrays / min-max numbers, and matcher options are names.
_DEFS["DynamicConfigValue"]["properties"]["value"] = {}
_DEFS["MatcherConfig"]["properties"]["options"] = {}
_Validator = validator_for(SCHEMA)
VALIDATOR = _Validator({"$ref": "#/definitions/Dashboard", "definitions": _DEFS})

# observ-lib boards (dotted g.libs paths) + the base boards. Cross-cutting libs
# without a single .grafana.dashboard are skipped at render time.
LIBS = [
    "runtimes.golang", "runtimes.jvm", "runtimes.python", "runtimes.dotnet", "runtimes.nodejs",
    "system.linux", "system.docker", "system.windows",
    "kubernetes.pod", "kubernetes.cadvisor",
    "databases.sql.postgres", "databases.sql.mysql",
    "databases.kv.redis", "databases.kv.memcached", "databases.kv.etcd",
    "monitoring.prometheus", "monitoring.mimir", "monitoring.loki", "monitoring.tempo", "monitoring.pyroscope",
    "collector.alloy",
    "networking.wireguard", "networking.unifi",
    "applications.syncthing",
    "base.home", "base.cluster", "base.clusterDetail",
]


def ev(expr):
    return json.loads(_jsonnet.evaluate_snippet("t", "local g=import 'g.libsonnet'; " + expr, jpathdir=[ROOT]))


def boards():
    out = {}
    for p in LIBS:
        try:
            out[p] = ev("g.libs.%s.new({}).grafana.dashboard.toResource().spec" % p)
        except RuntimeError as exc:
            print("  skip %s: %s" % (p, str(exc).splitlines()[-1][:70]))
    ref = json.loads(_jsonnet.evaluate_file(os.path.join(ROOT, "libs/reference-lib/render.jsonnet"), jpathdir=[ROOT]))
    for name, res in ref.items():
        if isinstance(res, dict) and res.get("kind") == "Dashboard":
            out["ref:" + name] = res["spec"]
    return out


def main():
    fails = 0
    items = boards()
    for name, spec in items.items():
        errs = [e for e in VALIDATOR.iter_errors(spec) if e.validator != "required"]
        if errs:
            fails += 1
            print("FAIL %s: %d schema error(s)" % (name, len(errs)))
            for e in errs[:6]:
                path = "/".join(str(x) for x in e.absolute_path) or "<root>"
                print("   %s: %s — %s" % (path, e.validator, str(e.message)[:100]))
    ok = len(items) - fails
    print("\n%d/%d boards schema-valid against v2beta1 (required-defaults ignored)." % (ok, len(items)))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
