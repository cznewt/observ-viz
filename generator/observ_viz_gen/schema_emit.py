"""Schema-driven emitters for the NEW structural kinds.

Unlike emit.py (which renders the curated manifest byte-for-byte), this module
reads the resolved schema IR (schema.py) and emits the layout kinds
(gen/layout/{grid,autoGrid,rows,tabs}.libsonnet) and conditionalRendering
(gen/conditionalRendering.libsonnet) DIRECTLY FROM THE SCHEMA. These files are
the real win: they replace the hand-written constructs in custom/layout.libsonnet
with schema-generated, kind-tagged builders.

Emit style matches the existing documented setter files: a leading generated
header, a ``'#withX':: { 'function': {...} }`` doc descriptor before every
setter, and a ``new(...)`` constructor that stamps the schema ``kind`` const.
Every setter roots at ``spec`` so it composes onto the constructor envelope.
"""
from __future__ import annotations

from typing import List, Optional

from . import schema as S

HEADER = "// This file is generated, do not manually edit."

# Map the schema "number" type onto the doc-descriptor token observ-viz uses.
_TYPE_TOKEN = {
    "number": "number",
    "integer": "integer",
    "boolean": "boolean",
    "string": "string",
    "array": "array",
    "object": "object",
}


def _jval(v) -> str:
    if v is None:
        return "null"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, str):
        return "'" + v + "'"
    return str(v)


def _jstr_list(items: Optional[List[str]]) -> str:
    if items is None:
        return "null"
    return "[" + ", ".join("'" + i + "'" for i in items) + "]"


def _cap(name: str) -> str:
    return name[0].upper() + name[1:]


def _doc_descriptor(setter: str, field: S.SchemaField, help_text: str) -> str:
    token = _TYPE_TOKEN.get(field.json_type, "object")
    arg = (
        "{ default: %s, enums: %s, name: 'value', type: [%s] }"
        % (_jval(field.default), _jstr_list(field.enum), "'" + token + "'")
    )
    return "'#%s':: { 'function': { args: [%s], help: '%s' } }," % (setter, arg, help_text)


def _setter_help(field: S.SchemaField) -> str:
    if field.ref:
        base = "Set %s (%s)." % (field.name, field.ref)
    elif field.items_ref:
        base = "Set %s ([]%s)." % (field.name, field.items_ref)
    else:
        base = "Set %s." % field.name
    return base


# ---------------------------------------------------------------------------
# A single layout/conditional Kind -> a builder object.
# ---------------------------------------------------------------------------
def emit_kind_builder(sch: S.Schema, kind_name: str, comment_lines: List[str]) -> str:
    """Emit one ``{ new(...): ..., withX(value): ... }`` builder from a *Kind def.

    The Kind def carries ``kind`` (const) + ``spec`` ($ref to its *Spec). The
    spec's required scalar fields become ``new()`` arguments (so the constructor
    yields a schema-valid object); every spec field also gets a ``withX`` setter.
    """
    kind = sch.kind(kind_name)
    const = kind.kind_const
    spec = sch.kind(kind.spec_ref) if kind.spec_ref else S.SchemaKind(name="")

    # new(...) arguments: required scalar spec fields, in schema order.
    ctor_args = []
    ctor_spec = []
    for f in spec.fields:
        if f.json_type in ("string", "boolean", "integer", "number") and f.required:
            if f.default is not None:
                ctor_args.append("%s=%s" % (f.name, _jval(f.default)))
            else:
                ctor_args.append(f.name)
            ctor_spec.append("%s: %s" % (f.name, f.name))
        elif f.json_type == "array" and f.required:
            # required arrays seed as empty so the object is valid out of the box.
            ctor_spec.append("%s: []" % f.name)

    out = [HEADER]
    out += ["// " + c for c in comment_lines]
    out.append("{")
    # constructor
    arg_sig = ", ".join(ctor_args)
    spec_body = ", ".join(ctor_spec)
    if spec_body:
        out.append(
            "  new(%s): { kind: '%s', spec: { %s } }," % (arg_sig, const, spec_body)
        )
    else:
        out.append("  new(%s): { kind: '%s', spec: {} }," % (arg_sig, const))
    # setters for every spec field
    for f in spec.fields:
        setter = "with" + _cap(f.name)
        out.append("  " + _doc_descriptor(setter, f, _setter_help(f)))
        if f.json_type == "array":
            # arrays get both a replace and a +Mixin append setter.
            out.append("  %s(value): { spec+: { %s: value } }," % (setter, f.name))
            out.append(
                "  %sMixin(value): { spec+: { %s+: value } },"
                % (setter, f.name)
            )
        elif f.json_type == "boolean" and f.default is not None:
            out.append(
                "  %s(value=%s): { spec+: { %s: value } },"
                % (setter, _jval(f.default), f.name)
            )
        else:
            out.append("  %s(value): { spec+: { %s: value } }," % (setter, f.name))
    out.append("}")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------
# Item sub-builder: a nested ``<key>: { new(...), withX } `` object for the
# layout's element/row/tab item Kind (e.g. GridLayoutItemKind).
# ---------------------------------------------------------------------------
def _item_builder_lines(sch: S.Schema, key: str, item_kind: str,
                        indent: str = "  ") -> List[str]:
    kind = sch.kind(item_kind)
    const = kind.kind_const
    spec = sch.kind(kind.spec_ref)
    ctor_args, ctor_spec = [], []
    for f in spec.fields:
        if f.name == "element":
            # element is an ElementReference keyed by NAME (define-once model).
            ctor_args.append("element")
            ctor_spec.append(
                "element: { kind: 'ElementReference', name: element }"
            )
        elif f.json_type in ("string", "boolean", "integer", "number") and f.required:
            if f.default is not None:
                ctor_args.append("%s=%s" % (f.name, _jval(f.default)))
            else:
                ctor_args.append(f.name)
            ctor_spec.append("%s: %s" % (f.name, f.name))
        elif f.name == "layout" and f.required:
            # nested layout (a oneOf of layout kinds) — required positional arg.
            ctor_args.append(f.name)
            ctor_spec.append("%s: %s" % (f.name, f.name))
    spec_body = ", ".join(ctor_spec)
    spec_obj = "{ %s }" % spec_body if spec_body else "{}"
    lines = ["%s%s: {" % (indent, key)]
    lines.append(
        "%s  new(%s): { kind: '%s', spec: %s },"
        % (indent, ", ".join(ctor_args), const, spec_obj)
    )
    for f in spec.fields:
        if f.name == "element":
            continue
        setter = "with" + _cap(f.name)
        lines.append("%s  " % indent + _doc_descriptor(setter, f, _setter_help(f)))
        if f.json_type == "array":
            lines.append(
                "%s  %s(value): { spec+: { %s: value } }," % (indent, setter, f.name)
            )
            lines.append(
                "%s  %sMixin(value): { spec+: { %s+: value } },"
                % (indent, setter, f.name)
            )
        elif f.json_type == "boolean" and f.default is not None:
            lines.append(
                "%s  %s(value=%s): { spec+: { %s: value } },"
                % (indent, setter, _jval(f.default), f.name)
            )
        else:
            lines.append(
                "%s  %s(value): { spec+: { %s: value } }," % (indent, setter, f.name)
            )
    lines.append("%s}," % indent)
    return lines


def _emit_layout_with_item(sch: S.Schema, kind_name: str, item_key: str,
                          item_kind: str, comment_lines: List[str]) -> str:
    """Layout builder + an embedded item sub-builder (e.g. grid + grid.item)."""
    base = emit_kind_builder(sch, kind_name, comment_lines)
    # splice the item sub-builder in before the closing brace.
    lines = base.rstrip("\n").split("\n")
    assert lines[-1] == "}"
    item_lines = _item_builder_lines(sch, item_key, item_kind, indent="  ")
    return "\n".join(lines[:-1] + item_lines + ["}"]) + "\n"


def emit_layout_grid(sch: S.Schema) -> str:
    return _emit_layout_with_item(
        sch, "GridLayoutKind", "item", "GridLayoutItemKind",
        ["GridLayout builder (schema-driven from GridLayoutKind/Spec).",
         "grid.item(element, x, y, width, height) wraps an element NAME in a",
         "GridLayoutItemKind (ElementReference) — never a panel object."],
    )


def emit_layout_auto_grid(sch: S.Schema) -> str:
    return _emit_layout_with_item(
        sch, "AutoGridLayoutKind", "item", "AutoGridLayoutItemKind",
        ["AutoGridLayout builder (schema-driven from AutoGridLayoutKind/Spec).",
         "autoGrid.item(element) wraps an element NAME in an AutoGridLayoutItemKind."],
    )


def emit_layout_rows(sch: S.Schema) -> str:
    return _emit_layout_with_item(
        sch, "RowsLayoutKind", "row", "RowsLayoutRowKind",
        ["RowsLayout builder (schema-driven from RowsLayoutKind/Spec).",
         "rows.row(layout) is a RowsLayoutRowKind holding a nested layout."],
    )


def emit_layout_tabs(sch: S.Schema) -> str:
    return _emit_layout_with_item(
        sch, "TabsLayoutKind", "tab", "TabsLayoutTabKind",
        ["TabsLayout builder (schema-driven from TabsLayoutKind/Spec).",
         "tabs.tab(layout) is a TabsLayoutTabKind holding a nested layout."],
    )


def emit_layout_main() -> str:
    out = [HEADER]
    out.append("{")
    for key, fn in (
        ("grid", "grid"),
        ("autoGrid", "autoGrid"),
        ("rows", "rows"),
        ("tabs", "tabs"),
    ):
        out.append("  %s: import 'gen/observ-viz-v2beta1/layout/%s.libsonnet'," % (key, fn))
    out.append("}")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------
# conditionalRendering — all three kinds in one file (group/data/variable).
# ---------------------------------------------------------------------------
def emit_conditional_rendering(sch: S.Schema) -> str:
    out = [HEADER]
    out += [
        "// ConditionalRendering builders (schema-driven from the",
        "// ConditionalRendering{Group,Data,Variable,TimeRangeSize}Kind/Spec defs).",
        "// Attach a group to a row/tab/auto-grid item via withConditionalRendering.",
    ]
    out.append("{")

    def block(key: str, kind_name: str, indent: str) -> None:
        kind = sch.kind(kind_name)
        const = kind.kind_const
        spec = sch.kind(kind.spec_ref)
        # constructor args: required scalars (+ seed required arrays empty).
        ctor_args, ctor_spec = [], []
        for f in spec.fields:
            if f.json_type in ("string", "boolean", "integer", "number") and f.required:
                if f.default is not None:
                    ctor_args.append("%s=%s" % (f.name, _jval(f.default)))
                else:
                    ctor_args.append(f.name)
                ctor_spec.append("%s: %s" % (f.name, f.name))
            elif f.json_type == "array" and f.required:
                ctor_args.append("%s=[]" % f.name)
                ctor_spec.append("%s: %s" % (f.name, f.name))
        out.append("%s%s: {" % (indent, key))
        out.append(
            "%s  new(%s): { kind: '%s', spec: { %s } },"
            % (indent, ", ".join(ctor_args), const, ", ".join(ctor_spec))
        )
        for f in spec.fields:
            setter = "with" + _cap(f.name)
            out.append("%s  " % indent + _doc_descriptor(setter, f, _setter_help(f)))
            if f.json_type == "array":
                out.append(
                    "%s  %s(value): { spec+: { %s: value } },"
                    % (indent, setter, f.name)
                )
                out.append(
                    "%s  %sMixin(value): { spec+: { %s+: value } },"
                    % (indent, setter, f.name)
                )
            else:
                out.append(
                    "%s  %s(value): { spec+: { %s: value } },"
                    % (indent, setter, f.name)
                )
        out.append("%s}," % indent)

    block("group", "ConditionalRenderingGroupKind", "  ")
    block("data", "ConditionalRenderingDataKind", "  ")
    block("variable", "ConditionalRenderingVariableKind", "  ")
    block("timeRangeSize", "ConditionalRenderingTimeRangeSizeKind", "  ")
    # convenience: attach a group to the enclosing row/tab/item spec.
    out.append(
        "  withConditionalRendering(group): { spec+: { conditionalRendering: group } },"
    )
    out.append("}")
    return "\n".join(out) + "\n"
