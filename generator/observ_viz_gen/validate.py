"""Cross-check the curated manifest setters against the authoritative schema.

The manifest (manifest.py) carries curated help text + argument defaults, but
every field it exposes must be a REAL property of the corresponding v2beta1
schema definition. This module proves that: for each curated kind it verifies
the setter's spec key exists in the schema (and that enum/string-enum facts
agree), so the curated surface stays a faithful, schema-backed subset.

Run via ``observ-viz-gen --check`` (which calls check_all) or directly:
    PYTHONPATH=generator python -m observ_viz_gen.validate
"""
from __future__ import annotations

from typing import List

from . import manifest as M
from . import schema as S

# Curated kind -> schema definition whose properties back its setters.
# (The spec keys the manifest writes must all be properties of this def.)
_DASHBOARD_DEF = "Dashboard"  # DashboardV2Spec lives under Dashboard.spec.allOf
_DEF_MAP = {
    "annotation": "AnnotationQuerySpec",
    "timeSettings": "TimeSettingsSpec",
}

# Curated setters that intentionally do NOT map 1:1 to a schema property
# (documented in SOURCES.md). Keyed by "<area>.<key>".
_CURATED_EXTRAS = {
    # v2 embeds the datasource INSIDE the annotation's DataQueryKind; the
    # veneer keeps a convenience withDatasource that the constructor folds in.
    "annotation.datasource",
}

# Variable kind -> its *Spec definition.
_VARIABLE_SPEC = {
    "query": "QueryVariableSpec",
    "datasource": "DatasourceVariableSpec",
    "custom": "CustomVariableSpec",
    "interval": "IntervalVariableSpec",
    "text": "TextVariableSpec",
    "constant": "ConstantVariableSpec",
    "groupBy": "GroupByVariableSpec",
    "adhoc": "AdhocVariableSpec",
}


def _dashboard_spec_props(sch: S.Schema):
    """DashboardV2Spec properties.

    In this jsonschema export the ``Dashboard`` definition IS the DashboardV2Spec
    (its properties are title/cursorSync/timeSettings/... directly), so its
    properties are the root setter targets.
    """
    return sch.properties_of(sch.defs["Dashboard"])


def _strip_mixin(key: str) -> str:
    return key[:-1] if key.endswith("+") else key


def check_all() -> List[str]:
    """Return a list of human-readable mismatches (empty == fully backed)."""
    sch = S.load()
    problems: List[str] = []

    # dashboard root setters
    props = _dashboard_spec_props(sch)
    for f in M.DASHBOARD.fields:
        key = _strip_mixin(f.spec_key)
        if key not in props:
            problems.append("dashboard.%s: not a DashboardV2Spec property" % key)

    # annotation + timeSettings
    for name, defn in _DEF_MAP.items():
        kind = M.ANNOTATION if name == "annotation" else M.TIME_SETTINGS
        props = sch.properties_of(sch.defs[defn])
        for f in kind.fields:
            key = _strip_mixin(f.spec_key)
            if key not in props and "%s.%s" % (name, key) not in _CURATED_EXTRAS:
                problems.append("%s.%s: not a %s property" % (name, key, defn))

    # variable hide must be the VariableHide string enum
    hide = sch.kind("VariableHide")
    venums = sch.enum_of(sch.defs["VariableHide"]) or []
    if "dontHide" not in venums or sch.json_type_of(sch.defs["VariableHide"]) != "string":
        problems.append("VariableHide is not the expected string enum")

    # each variable kind's curated setters must be real spec properties
    for kind_name, spec in M.VARIABLE_KINDS.items():
        defn = _VARIABLE_SPEC[kind_name]
        props = sch.properties_of(sch.defs[defn])
        # common/selection groups + extras all write spec keys; collect them.
        keys = set()
        if "common" in spec["groups"]:
            for setter, *_ in M.VARIABLE_COMMON:
                keys.add(setter[4].lower() + setter[5:])
        if "selection" in spec["groups"]:
            for setter, *_ in M.VARIABLE_SELECTION:
                keys.add(setter[4].lower() + setter[5:])
        for entry in spec.get("extra", []):
            keys.add(entry[1])
        for key in keys:
            if key == "datasource":  # withDsRef writes spec.datasource (DataQuery ref)
                continue
            if key not in props:
                problems.append(
                    "variable.%s.%s: not a %s property" % (kind_name, key, defn)
                )

    return problems


if __name__ == "__main__":
    import sys

    issues = check_all()
    if issues:
        print("SCHEMA CROSS-CHECK FAILED:")
        for p in issues:
            print("  - " + p)
        sys.exit(1)
    print("SCHEMA CROSS-CHECK OK: curated manifest is fully schema-backed")
