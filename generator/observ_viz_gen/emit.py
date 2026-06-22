"""Emit libsonnet setter source from the manifest IR.

Every emitter returns a complete file string (ending in a single newline) that
is byte-identical to the committed gen/ file. The leading
``// This file is generated, do not manually edit.`` line is always written.
"""
from __future__ import annotations

from typing import List, Optional

from . import manifest as M
from .model import CompactSetter, Field, Group, Kind

HEADER = M.HEADER


# ---------------------------------------------------------------------------
# jsonnet literal helpers
# ---------------------------------------------------------------------------
def jval(v) -> str:
    """Render a Python value as a jsonnet literal (single-quoted strings)."""
    if v is None:
        return "null"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, str):
        return "'" + v + "'"
    return str(v)


def jstr_list(items: Optional[List[str]]) -> str:
    if items is None:
        return "null"
    return "[" + ", ".join("'" + i + "'" for i in items) + "]"


def arg_sig(field: Field) -> str:
    """The ``(value)`` / ``(value=<default>)`` setter signature."""
    if field.has_arg_default:
        return "(value=%s)" % jval(field.default)
    return "(value)"


def doc_descriptor(field: Field) -> str:
    """The ``'#withX':: { 'function': { ... } }`` line (no leading indent)."""
    arg = (
        "{ default: %s, enums: %s, name: 'value', type: [%s] }"
        % (jval(field.default), jstr_list(field.enums), "'" + field.json_type + "'")
    )
    return (
        "'#%s':: { 'function': { args: [%s], help: '%s' } },"
        % (field.setter_name, arg, field.comment)
    )


# ---------------------------------------------------------------------------
# Documented setter files (dashboard, annotation, timeSettings, query/*)
# ---------------------------------------------------------------------------
def emit_documented(kind: Kind, comment_lines: List[str],
                    helper_lines: Optional[List[str]] = None,
                    body_fn=None) -> str:
    """Render a documented setter object.

    body_fn(field) -> the setter body string (defaults to a spec-rooted
    assignment using kind.root_open/root_close). Used by query/* which wrap the
    body in the ``q(o)`` helper instead.
    """
    out = [HEADER]
    out += ["// " + c for c in comment_lines]
    if helper_lines:
        out += helper_lines
    out.append("{")
    for f in kind.fields:
        out.append("  " + doc_descriptor(f))
        if body_fn is not None:
            body = body_fn(f)
        else:
            body = kind.root_open + f.spec_key + ": value" + kind.root_close
        out.append("  %s%s: %s," % (f.setter_name, arg_sig(f), body))
    out.append("}")
    return "\n".join(out) + "\n"


def emit_dashboard() -> str:
    return emit_documented(
        M.DASHBOARD,
        [
            "DashboardV2Spec field setters. These root at `spec` so they compose with the",
            "hand-written custom/dashboard.libsonnet `new(title)` envelope.",
        ],
    )


def emit_annotation() -> str:
    return emit_documented(
        M.ANNOTATION,
        [
            "AnnotationQueryKind field setters (root at `spec`). Compose with the",
            "hand-written custom/annotation.libsonnet `new(name)`.",
        ],
    )


def emit_time_settings() -> str:
    return emit_documented(
        M.TIME_SETTINGS,
        [
            "TimeSettingsSpec field setters. Compose with `+`, pass result to",
            "g.dashboard.withTimeSettings(...).",
        ],
    )


def emit_query(kind_name: str, fields: List[Field], comment_lines: List[str]) -> str:
    """Query spec files: doc descriptors + bodies wrapped in the `q(o)` helper."""
    kind = Kind(name=kind_name, fields=fields)

    def body(f: Field) -> str:
        return "q({ %s: value })" % f.spec_key

    helper = ["local q(o) = { spec+: { query+: { spec+: o } } };"]
    return emit_documented(kind, comment_lines, helper_lines=helper, body_fn=body)


def emit_query_prometheus() -> str:
    return emit_query(
        "prometheus",
        M.QUERY_PROMETHEUS_FIELDS,
        [
            "Prometheus query-spec setters. Root at spec.query.spec so they compose with",
            "custom/query.libsonnet new('prometheus', ...).",
        ],
    )


def emit_query_loki() -> str:
    return emit_query(
        "loki",
        M.QUERY_LOKI_FIELDS,
        ["Loki query-spec setters (root at spec.query.spec)."],
    )


# ---------------------------------------------------------------------------
# Compact variable file
# ---------------------------------------------------------------------------
def _var_setter(name: str, key: str, default, has_default: bool) -> str:
    sig = "(value=%s)" % jval(default) if has_default else "(value)"
    return "  %s%s: { spec+: { %s: value } }," % (name, sig, key)


def emit_variable() -> str:
    out = [HEADER]
    out += [
        "// v2 variable-kind field setters (root at `spec`). Constructors (new) and the",
        "// kind tag live in custom/variable.libsonnet, merged over these per kind.",
    ]
    # local common = { ... };
    out.append("local common = {")
    for name, default, has_default in M.VARIABLE_COMMON:
        key = name[4].lower() + name[5:]  # withName -> name
        out.append(_var_setter(name, key, default, has_default))
    out.append("};")
    # local selection = { ... };
    out.append("local selection = {")
    for name, default, has_default in M.VARIABLE_SELECTION:
        key = name[4].lower() + name[5:]
        out.append(_var_setter(name, key, default, has_default))
    out.append("};")
    # local withDsRef = { ... };
    out.append("local withDsRef = {")
    out.append("  withDatasource(value): { spec+: { datasource: value } },")
    out.append(
        "  withDatasourceFromVariable(name): { spec+: { datasource: { uid: '${' + name + '}' } } },"
    )
    out.append("};")
    # per-kind object
    out.append("{")
    for kind_name, spec in M.VARIABLE_KINDS.items():
        groups = " + ".join(spec["groups"])
        extra = spec["extra"]
        if not extra:
            out.append("  %s: %s," % (kind_name, groups))
            continue
        if kind_name in ("text", "constant"):
            # single inline setter on one line
            name, key, default, has_default = extra[0]
            sig = "(value=%s)" % jval(default) if has_default else "(value)"
            out.append(
                "  %s: %s + { %s%s: { spec+: { %s: value } } },"
                % (kind_name, groups, name, sig, key)
            )
            continue
        out.append("  %s: %s + {" % (kind_name, groups))
        for name, key, default, has_default in extra:
            sig = "(value=%s)" % jval(default) if has_default else "(value)"
            out.append("    %s%s: { spec+: { %s: value } }," % (name, sig, key))
        out.append("  },")
    out.append("}")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------
# Compact panel option files
# ---------------------------------------------------------------------------
def _viz_body(path: List[str], leaf: str = "value") -> str:
    """Build the ``viz({ a+: { b+: { c: value } } })`` body from a key chain."""
    inner = leaf
    for key in reversed(path):
        inner = "{ %s: %s }" % (key, inner)
    return "viz(%s)" % inner


def _emit_compact_setter(cs: CompactSetter, indent: str) -> str:
    sig = "(value=%s)" % jval(cs.default) if cs.has_arg_default else "(value)"
    return "%s%s%s: %s," % (indent, cs.name, sig, _viz_body(cs.body_path))


def _emit_group(group: Group, indent: str) -> List[str]:
    out = [indent + group.name + "+: {"]
    child = indent + "  "
    for cs in group.setters:
        out.append(_emit_compact_setter(cs, child))
    for sub in group.groups:
        out += _emit_group(sub, child)
    for cs in group.trailing_setters:
        out.append(_emit_compact_setter(cs, child))
    out.append(indent + "},")
    return out


def emit_panel_option(spec: dict) -> str:
    comment = spec["comment"]
    out = [HEADER]
    # comment may carry an embedded continuation line (timeSeries)
    out.append("// " + comment)
    out.append("local viz(o) = { spec+: { vizConfig+: { spec+: o } } };")
    out.append("{")
    for group in spec["groups"]:
        out += _emit_group(group, "  ")
    out.append("}")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------
# Import maps
# ---------------------------------------------------------------------------
def emit_import_map(comment_lines: List[str], imports: List) -> str:
    out = [HEADER]
    out += ["// " + c for c in comment_lines]
    out.append("{")
    for key, path in imports:
        out.append("  %s: import '%s'," % (key, path))
    out.append("}")
    return "\n".join(out) + "\n"


def emit_main() -> str:
    return emit_import_map(
        ["Generated builders for Grafana dashboard schema v2beta1 (dashboard.grafana.app)."],
        M.MAIN_IMPORTS,
    )


def emit_panel_main() -> str:
    return emit_import_map([], M.PANEL_MAIN_IMPORTS)


def emit_query_main() -> str:
    return emit_import_map([], M.QUERY_MAIN_IMPORTS)


def emit_versions() -> str:
    out = [HEADER]
    out += [
        "// Maps a panel viz kind to the pluginVersion stamped into vizConfig.spec.",
        "// Populated by the generator from generator/schemas/SOURCES.md pins.",
    ]
    out.append("{")
    for kind in M.VERSIONS:
        # quote keys that are not valid bare identifiers (contain '-')
        key = "'%s'" % kind if "-" in kind else kind
        out.append("  %s: ''," % key)
    out.append("}")
    return "\n".join(out) + "\n"


def emit_latest_main() -> str:
    return "\n".join([
        HEADER,
        "// Redirect package: always points at the newest generated schema version.",
        "import 'gen/observ-viz-v2beta1/main.libsonnet'",
    ]) + "\n"
