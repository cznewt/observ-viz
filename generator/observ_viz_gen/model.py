"""Intermediate representation for the observ-viz code generator.

The manifest (manifest.py) is the declarative source of truth. It is expressed
in terms of these dataclasses, which the emitter (emit.py) turns into libsonnet
setter source byte-for-byte matching the committed gen/ tree.

Two setter dialects exist in gen/ and are modelled here:

* "documented" files (dashboard, annotation, timeSettings, query/*) emit a
  ``'#withX':: { 'function': { args: [...], help: '...' } }`` doc descriptor in
  front of every setter. Field.comment + Field.default + Field.json_type +
  Field.enums drive that descriptor.

* "compact" files (variable/main, panel/*) omit the doc descriptors and lean on
  ``local`` helpers (``viz(o)``, ``q(o)``, the variable ``common``/``selection``
  groups) plus nested sub-groups.

Both dialects ultimately emit the same ``withX(value): <body>`` setter lines, so
Field carries everything needed for either.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class Field:
    """A single ``withX`` setter.

    name        : capitalised suffix, e.g. ``Title`` -> ``withTitle``.
    json_type   : JSON schema type token for the doc descriptor
                  (string|boolean|integer|object|array). Ignored by compact files.
    default     : default value baked into the doc descriptor AND, when
                  ``has_arg_default`` is set, into the setter signature
                  (e.g. ``withHide(value=true)``). Python ``None`` -> jsonnet null.
    has_arg_default : whether the setter signature carries ``value=<default>``.
                  (A field can advertise a doc default of true while still
                  taking a bare ``value`` — but in practice the two travel
                  together in the committed gen/, so default+has_arg_default.)
    enums       : optional list of allowed string values for the doc descriptor.
    comment     : the ``help`` text in the doc descriptor.
    key         : the spec key written by the setter (defaults to lowercased
                  first letter of name; set explicitly when they differ).
    """

    name: str
    json_type: str = "string"
    default: object = None
    has_arg_default: bool = False
    enums: Optional[List[str]] = None
    comment: str = ""
    key: Optional[str] = None

    @property
    def setter_name(self) -> str:
        return "with" + self.name

    @property
    def spec_key(self) -> str:
        if self.key is not None:
            return self.key
        return self.name[0].lower() + self.name[1:]


@dataclass
class Group:
    """A nested sub-object of setters inside a compact file.

    e.g. the ``thresholds+:`` / ``reduceOptions+:`` / ``legend+:`` groups inside
    the panel option files. ``name`` is the object key; ``path`` is the list of
    object keys (relative to the ``viz``/``q`` wrapper body) that the setters
    nest under.
    """

    name: str
    setters: List["CompactSetter"] = field(default_factory=list)
    groups: List["Group"] = field(default_factory=list)
    # setters emitted AFTER the nested sub-groups (e.g. stat's withMappings,
    # timeSeries' withOverrides, which sit below the thresholds sub-group).
    trailing_setters: List["CompactSetter"] = field(default_factory=list)


@dataclass
class CompactSetter:
    """A setter line in a compact file.

    body_path : the nested object path (list of keys) the value is written to,
                inside the wrapper helper (``viz``/``q``) or the variable spec.
    """

    name: str
    body_path: List[str]
    default: object = None
    has_arg_default: bool = False


@dataclass
class Kind:
    """A documented setter file: a flat object of Field setters rooted at a
    given spec path (``spec`` for dashboard/variable; raw for timeSettings).
    """

    name: str
    fields: List[Field] = field(default_factory=list)
    # the assignment prefix/suffix wrapping the value, e.g.
    #   spec_root=("{ spec+: { ", " } }")  ->  { spec+: { title: value } }
    # documented files always root at spec; timeSettings roots at the bare obj.
    root_open: str = "{ spec+: { "
    root_close: str = " } }"
