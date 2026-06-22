"""Orchestration: map each target name to (relative path, emitter)."""
from __future__ import annotations

import os
from typing import Callable, Dict, List, Tuple

from . import emit
from . import schema as schema_mod
from . import schema_emit

# The resolved schema is loaded once (lazily) and passed to the schema-driven
# emitters for the layout + conditionalRendering kinds.
_SCHEMA = None


def _schema():
    global _SCHEMA
    if _SCHEMA is None:
        _SCHEMA = schema_mod.load()
    return _SCHEMA

# Each entry: target-group -> list of (relative output path, emitter callable).
# Paths are relative to the --out directory (gen/observ-viz-v2beta1 by default),
# except the 'latest' redirect which lives one level up under observ-viz-latest.
FileSpec = Tuple[str, Callable[[], str]]

V2 = "observ-viz-v2beta1"
LATEST = "observ-viz-latest"


def _files() -> Dict[str, List[Tuple[str, Callable[[], str]]]]:
    """Group -> list of (path-relative-to-gen-root, emitter)."""
    return {
        "dashboard": [(f"{V2}/dashboard.libsonnet", emit.emit_dashboard)],
        "annotation": [(f"{V2}/annotation.libsonnet", emit.emit_annotation)],
        "timeSettings": [(f"{V2}/timeSettings.libsonnet", emit.emit_time_settings)],
        "variable": [(f"{V2}/variable/main.libsonnet", emit.emit_variable)],
        "panel": [
            (f"{V2}/panel/main.libsonnet", emit.emit_panel_main),
            (f"{V2}/panel/stat.libsonnet",
             lambda: emit.emit_panel_option(_panel_specs()["stat"])),
            (f"{V2}/panel/table.libsonnet",
             lambda: emit.emit_panel_option(_panel_specs()["table"])),
            (f"{V2}/panel/timeSeries.libsonnet",
             lambda: emit.emit_panel_option(_panel_specs()["timeSeries"])),
        ],
        "query": [
            (f"{V2}/query/main.libsonnet", emit.emit_query_main),
            (f"{V2}/query/prometheus.libsonnet", emit.emit_query_prometheus),
            (f"{V2}/query/loki.libsonnet", emit.emit_query_loki),
        ],
        "versions": [(f"{V2}/_versions.libsonnet", emit.emit_versions)],
        # NEW schema-driven kinds (emitted FROM the JSON schema, not the manifest).
        "layout": [
            (f"{V2}/layout/main.libsonnet", schema_emit.emit_layout_main),
            (f"{V2}/layout/grid.libsonnet", lambda: schema_emit.emit_layout_grid(_schema())),
            (f"{V2}/layout/autoGrid.libsonnet", lambda: schema_emit.emit_layout_auto_grid(_schema())),
            (f"{V2}/layout/rows.libsonnet", lambda: schema_emit.emit_layout_rows(_schema())),
            (f"{V2}/layout/tabs.libsonnet", lambda: schema_emit.emit_layout_tabs(_schema())),
        ],
        "conditional": [
            (f"{V2}/conditionalRendering.libsonnet",
             lambda: schema_emit.emit_conditional_rendering(_schema())),
        ],
        "main": [
            (f"{V2}/main.libsonnet", emit.emit_main),
            (f"{LATEST}/main.libsonnet", emit.emit_latest_main),
        ],
    }


def _panel_specs():
    from . import manifest as M

    return {"stat": M.PANEL_STAT, "table": M.PANEL_TABLE, "timeSeries": M.PANEL_TIMESERIES}


def all_groups() -> List[str]:
    return list(_files().keys())


def files_for(group: str) -> List[Tuple[str, Callable[[], str]]]:
    """Resolve a target group name (or 'all') to its file specs."""
    table = _files()
    if group == "all":
        out: List[Tuple[str, Callable[[], str]]] = []
        for g in table.values():
            out += g
        return out
    if group not in table:
        raise SystemExit(
            "unknown target '%s'; choose from: all, %s"
            % (group, ", ".join(table.keys()))
        )
    return table[group]


def gen_root(out_dir: str) -> str:
    """Given --out (which points at the v2beta1 dir), return the gen/ root so the
    'latest' redirect (observ-viz-latest/) lands beside observ-viz-v2beta1/.
    """
    out_dir = os.path.normpath(out_dir)
    base = os.path.basename(out_dir)
    if base == V2:
        return os.path.dirname(out_dir)
    return out_dir
