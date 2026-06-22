"""JSON Schema loader for the foundation-sdk Grafana dashboard v2beta1 schema.

This is the AUTHORITATIVE source. It reads
``generator/schemas/dashboardv2beta1.jsonschema.json`` (and the referenced
``common.jsonschema.json``) and resolves ``$ref`` / ``definitions`` / ``allOf``
/ ``oneOf`` into a small IR:

    SchemaKind { name, kind_const, fields[] }
    SchemaField { name, json_type, enum, default, ref, nested, items_ref }

The emitter (emit.py) turns SchemaKind IR into the observ-viz libsonnet setter
style. The IR is intentionally lossless enough to drive the NEW structural kinds
(layout/*, conditionalRendering) directly from the schema, and to CROSS-CHECK the
curated setter files (dashboard/variable/annotation/timeSettings/query) against
the schema so the hand-curated help text/defaults stay provably schema-backed.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional

_HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA_DIR = os.path.join(os.path.dirname(_HERE), "schemas")
DASHBOARD_SCHEMA = os.path.join(SCHEMA_DIR, "dashboardv2beta1.jsonschema.json")
COMMON_SCHEMA = os.path.join(SCHEMA_DIR, "common.jsonschema.json")


# ---------------------------------------------------------------------------
# IR
# ---------------------------------------------------------------------------
@dataclass
class SchemaField:
    """One property of an object definition.

    name      : property name as written in the schema (jsonnet spec key).
    json_type : resolved JSON-schema type token
                (string|boolean|integer|number|object|array|null), best-effort.
    enum      : list of allowed values when the (possibly $ref-resolved) type is
                an enum; else None.
    default   : schema ``default`` (after $ref resolution), or None.
    ref       : the bare definition name this property points at (if a $ref),
                else None.
    items_ref : for arrays, the bare definition name of the element $ref.
    required  : whether the property is in the object's ``required`` list.
    """

    name: str
    json_type: str = "object"
    enum: Optional[List[str]] = None
    default: object = None
    ref: Optional[str] = None
    items_ref: Optional[str] = None
    required: bool = False
    const: Optional[str] = None


@dataclass
class SchemaKind:
    """A resolved object definition.

    kind_const : the value of a ``kind`` property declared ``const`` (the
                 serialized kind tag, e.g. ``GridLayout``), else None.
    spec_ref   : the definition name of the ``spec`` property's $ref (Kind ->
                 Spec pairing), else None.
    """

    name: str
    fields: List[SchemaField] = field(default_factory=list)
    kind_const: Optional[str] = None
    spec_ref: Optional[str] = None
    description: str = ""

    def field_map(self) -> Dict[str, SchemaField]:
        return {f.name: f for f in self.fields}


class Schema:
    """The merged definition table with $ref/allOf resolution helpers."""

    def __init__(self, definitions: Dict[str, dict]):
        self.defs = definitions

    # -- ref helpers --------------------------------------------------------
    @staticmethod
    def ref_name(ref: str) -> str:
        """``#/definitions/Foo`` -> ``Foo``."""
        return ref.rsplit("/", 1)[-1]

    def resolve(self, node: dict) -> dict:
        """Follow a single ``$ref`` (one hop) to its definition body."""
        if "$ref" in node:
            return self.defs[self.ref_name(node["$ref"])]
        return node

    def deep_resolve(self, node: dict) -> dict:
        """Follow chained ``$ref`` until a concrete node is reached."""
        seen = set()
        while "$ref" in node:
            name = self.ref_name(node["$ref"])
            if name in seen:
                break
            seen.add(name)
            node = self.defs[name]
        return node

    # -- type inference -----------------------------------------------------
    def json_type_of(self, node: dict) -> str:
        node = self.deep_resolve(node)
        t = node.get("type")
        if isinstance(t, list):
            # e.g. ["string", "null"] -> first non-null
            for x in t:
                if x != "null":
                    return x
            return t[0]
        if t:
            return t
        if "enum" in node:
            return "string"
        if "oneOf" in node or "anyOf" in node:
            return "object"
        return "object"

    def enum_of(self, node: dict) -> Optional[List[str]]:
        node = self.deep_resolve(node)
        en = node.get("enum")
        if en is None:
            return None
        return [str(x) for x in en]

    # -- object flattening --------------------------------------------------
    def properties_of(self, defn: dict) -> Dict[str, dict]:
        """Return merged properties, resolving a top-level ``allOf`` of refs."""
        props: Dict[str, dict] = {}
        if "allOf" in defn:
            for part in defn["allOf"]:
                part = self.resolve(part)
                props.update(self.properties_of(part))
        props.update(defn.get("properties", {}))
        return props

    def required_of(self, defn: dict) -> List[str]:
        req = list(defn.get("required", []))
        for part in defn.get("allOf", []):
            part = self.resolve(part)
            req += self.required_of(part)
        return req

    # -- the main entry: build a SchemaKind from a definition name ----------
    def kind(self, name: str) -> SchemaKind:
        defn = self.defs[name]
        props = self.properties_of(defn)
        required = set(self.required_of(defn))
        sk = SchemaKind(name=name, description=defn.get("description", ""))
        for pname, pnode in props.items():
            sf = SchemaField(
                name=pname,
                json_type=self.json_type_of(pnode),
                enum=self.enum_of(pnode),
                default=self.deep_resolve(pnode).get("default", pnode.get("default")),
                required=pname in required,
            )
            raw = pnode
            if "$ref" in raw:
                sf.ref = self.ref_name(raw["$ref"])
            if raw.get("type") == "array" and isinstance(raw.get("items"), dict):
                items = raw["items"]
                if "$ref" in items:
                    sf.items_ref = self.ref_name(items["$ref"])
            # const detection (kind tag / fixed values)
            rnode = self.deep_resolve(raw)
            if "const" in rnode:
                sf.const = rnode["const"]
            if pname == "kind" and sf.const:
                sk.kind_const = sf.const
            if pname == "spec" and sf.ref:
                sk.spec_ref = sf.ref
            sk.fields.append(sf)
        return sk


# ---------------------------------------------------------------------------
# loading
# ---------------------------------------------------------------------------
def load(dashboard_path: str = DASHBOARD_SCHEMA,
         common_path: str = COMMON_SCHEMA) -> Schema:
    with open(dashboard_path, "r", encoding="utf-8") as fh:
        dash = json.load(fh)
    defs = dict(dash.get("definitions", {}))
    if common_path and os.path.exists(common_path):
        with open(common_path, "r", encoding="utf-8") as fh:
            common = json.load(fh)
        # common defs fill in any names the dashboard schema references but does
        # not itself define (do not overwrite dashboard-local definitions).
        for k, v in common.get("definitions", {}).items():
            defs.setdefault(k, v)
    return Schema(defs)
