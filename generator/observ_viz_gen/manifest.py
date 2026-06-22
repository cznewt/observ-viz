"""Declarative SOURCE OF TRUTH for the observ-viz v2beta1 generated builders.

Every kind + field below maps 1:1 onto the committed gen/observ-viz-v2beta1
tree (and gen/observ-viz-latest/main.libsonnet). Editing this manifest and
rerunning ``observ-viz-gen all`` is the supported way to add kinds/fields.

The manifest is intentionally plain Python data (dicts/lists + the model.py
dataclasses) — no schema fetching at generate time. See
generator/schemas/SOURCES.md for provenance and the hand-authored decision.

New v2 facts captured as data here:
  * variable ``hide`` is a STRING enum (dontHide|hideLabel|hideVariable), NOT an
    int. In the compact variable file it is a bare ``withHide(value)`` setter,
    so the enum lives only in this manifest + SOURCES.md (the compact dialect
    emits no doc descriptors).
  * conditionalRendering kinds and the {kind,spec} transformation wrapping live
    in custom/ (out of generator scope) — documented in SOURCES.md.
"""
from __future__ import annotations

from .model import CompactSetter, Field, Group, Kind

# Header line that prefixes every generated file (byte-exact).
HEADER = "// This file is generated, do not manually edit."


# ---------------------------------------------------------------------------
# Documented setter files (each setter preceded by a `'#withX'::` descriptor).
# ---------------------------------------------------------------------------

DASHBOARD = Kind(
    name="dashboard",
    fields=[
        Field("Title", "string", comment="Dashboard title."),
        Field("Description", "string", comment="Dashboard description."),
        Field(
            "CursorSync",
            "string",
            default="Off",
            enums=["Off", "Crosshair", "Tooltip"],
            comment="Cursor sync mode (string enum).",
        ),
        Field("LiveNow", "boolean", default=True, has_arg_default=True,
              comment='Continuously re-evaluate "now".'),
        Field("Preload", "boolean", default=True, has_arg_default=True,
              comment="Load all panels on dashboard load."),
        Field("Editable", "boolean", default=True, has_arg_default=True,
              comment="Allow editing."),
        Field("Tags", "array", comment="Dashboard tags."),
        Field("TagsMixin", "array", comment="Append dashboard tags.", key="tags+"),
        Field("Links", "array", comment="Dashboard links."),
        Field("LinksMixin", "array", comment="Append dashboard links.", key="links+"),
    ],
)

ANNOTATION = Kind(
    name="annotation",
    fields=[
        Field("Name", "string", comment="Annotation name."),
        Field("Datasource", "object", comment="DataSourceRef {type,uid}."),
        Field("Query", "object", comment="DataQueryKind."),
        Field("Enable", "boolean", default=True, has_arg_default=True,
              comment="Enable annotation."),
        Field("Hide", "boolean", default=True, has_arg_default=True,
              comment="Hide annotation toggle."),
        Field("IconColor", "string", comment="Annotation icon color."),
    ],
)

# timeSettings roots at the bare object (no `spec+`).
TIME_SETTINGS = Kind(
    name="timeSettings",
    root_open="{ ",
    root_close=" }",
    fields=[
        Field("Timezone", "string", comment='IANA TZDB zone, "browser" or "utc".'),
        Field("From", "string", default="now-6h", has_arg_default=True,
              comment="Range start."),
        Field("To", "string", default="now", has_arg_default=True,
              comment="Range end."),
        Field("AutoRefresh", "string", comment='Auto-refresh interval, "" for off.'),
        Field("AutoRefreshIntervals", "array", comment="Selectable refresh intervals."),
        Field("HideTimepicker", "boolean", default=True, has_arg_default=True,
              comment="Hide the timepicker UI."),
        Field("WeekStart", "string", comment="Week start day."),
        Field("FiscalYearStartMonth", "integer", default=0, has_arg_default=True,
              comment="Fiscal year start month (0-11)."),
        Field("NowDelay", "string", comment='Delay applied to "now".'),
    ],
)

# Query spec files root at spec.query.spec via the `q(o)` helper; emitted with
# doc descriptors.
QUERY_PROMETHEUS_FIELDS = [
    Field("Expr", "string", comment="PromQL expression."),
    Field("LegendFormat", "string", comment="Legend template."),
    Field("Format", "string", enums=["time_series", "table", "heatmap"],
          comment="Result format."),
    Field("Instant", "boolean", default=True, has_arg_default=True,
          comment="Instant query."),
    Field("Range", "boolean", default=True, has_arg_default=True,
          comment="Range query."),
    Field("Interval", "string", comment="Min step interval."),
    Field("EditorMode", "string", enums=["code", "builder"],
          comment="Query editor mode."),
    Field("Exemplar", "boolean", default=True, has_arg_default=True,
          comment="Query exemplars."),
]

QUERY_LOKI_FIELDS = [
    Field("Expr", "string", comment="LogQL expression."),
    Field("LegendFormat", "string", comment="Legend template."),
    Field("QueryType", "string", enums=["range", "instant"],
          comment="Loki query type."),
    Field("MaxLines", "integer", comment="Max log lines."),
    Field("Direction", "string", enums=["forward", "backward"],
          comment="Sort direction."),
]


# ---------------------------------------------------------------------------
# Compact variable file (variable/main.libsonnet).
# ---------------------------------------------------------------------------
# Shared `local` setter groups. Each tuple is (setter name, default-or-None,
# has_arg_default). All variable setters root at `spec`.
VARIABLE_COMMON = [
    ("withName", None, False),
    ("withLabel", None, False),
    ("withDescription", None, False),
    # NOTE: hide is a STRING enum (dontHide|hideLabel|hideVariable) in v2, NOT an
    # int. The compact dialect emits no doc descriptor so the enum is recorded in
    # SOURCES.md; the setter itself is a bare `withHide(value)`.
    ("withHide", None, False),
    ("withSkipUrlSync", True, True),
]
VARIABLE_SELECTION = [
    ("withMulti", True, True),
    ("withIncludeAll", True, True),
    ("withAllValue", None, False),
]

# Per-kind extra setters (added after the common/selection/withDsRef groups).
# Each entry is (setter name, spec key, default-or-None, has_arg_default).
VARIABLE_KINDS = {
    "query": {
        "groups": ["common", "selection", "withDsRef"],
        "extra": [
            ("withQuery", "query", None, False),
            ("withRegex", "regex", None, False),
            ("withSort", "sort", None, False),
            ("withRefresh", "refresh", None, False),
        ],
    },
    "datasource": {
        "groups": ["common", "selection"],
        "extra": [
            ("withPluginId", "pluginId", None, False),
            ("withRegex", "regex", None, False),
        ],
    },
    "custom": {
        "groups": ["common", "selection"],
        "extra": [
            ("withQuery", "query", None, False),
            ("withOptions", "options", None, False),
        ],
    },
    "interval": {
        "groups": ["common"],
        "extra": [
            ("withQuery", "query", None, False),
            ("withOptions", "options", None, False),
            ("withAuto", "auto", True, True),
        ],
    },
    # text/constant carry a single inline setter (emitted on one line).
    "text": {"groups": ["common"], "extra": [("withQuery", "query", None, False)]},
    "constant": {"groups": ["common"], "extra": [("withQuery", "query", None, False)]},
    "groupBy": {"groups": ["common", "withDsRef"], "extra": []},
    "adhoc": {"groups": ["common", "withDsRef"], "extra": []},
}


# ---------------------------------------------------------------------------
# Compact panel option files (panel/{stat,table,timeSeries}.libsonnet).
# ---------------------------------------------------------------------------
# Each setter writes to a nested path inside the `viz(o)` wrapper, which roots at
# spec.vizConfig.spec. body_path is the key chain under that root.
def _cs(name, path, default=None, has_default=False):
    return CompactSetter(name=name, body_path=path, default=default,
                         has_arg_default=has_default)


PANEL_STAT = {
    "kind": "stat",
    "comment": "'stat' viz option + fieldConfig setters (root at spec.vizConfig.spec).",
    "groups": [
        Group(
            name="standardOptions",
            setters=[
                _cs("withUnit", ["fieldConfig+", "defaults+", "unit"]),
                _cs("withMin", ["fieldConfig+", "defaults+", "min"]),
                _cs("withMax", ["fieldConfig+", "defaults+", "max"]),
                _cs("withDecimals", ["fieldConfig+", "defaults+", "decimals"]),
            ],
            groups=[
                Group(
                    name="thresholds",
                    setters=[
                        _cs("withSteps",
                            ["fieldConfig+", "defaults+", "thresholds+", "steps"]),
                        _cs("withMode",
                            ["fieldConfig+", "defaults+", "thresholds+", "mode"],
                            default="absolute", has_default=True),
                    ],
                ),
            ],
            # withMappings comes AFTER the thresholds sub-group in stat.
            trailing_setters=[
                _cs("withMappings", ["fieldConfig+", "defaults+", "mappings"]),
            ],
        ),
        Group(
            name="options",
            setters=[
                _cs("withColorMode", ["options+", "colorMode"]),
                _cs("withGraphMode", ["options+", "graphMode"]),
                _cs("withJustifyMode", ["options+", "justifyMode"]),
                _cs("withTextMode", ["options+", "textMode"]),
            ],
            groups=[
                Group(
                    name="reduceOptions",
                    setters=[
                        _cs("withCalcs", ["options+", "reduceOptions+", "calcs"]),
                        _cs("withValues", ["options+", "reduceOptions+", "values"],
                            default=True, has_default=True),
                        _cs("withFields", ["options+", "reduceOptions+", "fields"]),
                    ],
                ),
            ],
        ),
    ],
}

PANEL_TABLE = {
    "kind": "table",
    "comment": "'table' viz option + fieldConfig setters (root at spec.vizConfig.spec).",
    "groups": [
        Group(
            name="standardOptions",
            setters=[
                _cs("withUnit", ["fieldConfig+", "defaults+", "unit"]),
                _cs("withDecimals", ["fieldConfig+", "defaults+", "decimals"]),
                _cs("withMappings", ["fieldConfig+", "defaults+", "mappings"]),
                _cs("withOverrides", ["fieldConfig+", "overrides"]),
            ],
        ),
        Group(
            name="options",
            setters=[
                _cs("withShowHeader", ["options+", "showHeader"],
                    default=True, has_default=True),
            ],
            groups=[
                Group(
                    name="footer",
                    setters=[
                        _cs("withShow", ["options+", "footer+", "show"],
                            default=True, has_default=True),
                        _cs("withReducer", ["options+", "footer+", "reducer"]),
                    ],
                ),
            ],
        ),
    ],
}

PANEL_TIMESERIES = {
    "kind": "timeSeries",
    "comment": (
        "'timeseries' viz option + fieldConfig setters. Each roots at\n"
        "// spec.vizConfig.spec so it composes with custom/panel.libsonnet new('timeseries')."
    ),
    "groups": [
        Group(
            name="standardOptions",
            setters=[
                _cs("withUnit", ["fieldConfig+", "defaults+", "unit"]),
                _cs("withMin", ["fieldConfig+", "defaults+", "min"]),
                _cs("withMax", ["fieldConfig+", "defaults+", "max"]),
                _cs("withDecimals", ["fieldConfig+", "defaults+", "decimals"]),
                _cs("withNoValue", ["fieldConfig+", "defaults+", "noValue"]),
            ],
            groups=[
                Group(
                    name="thresholds",
                    setters=[
                        _cs("withSteps",
                            ["fieldConfig+", "defaults+", "thresholds+", "steps"]),
                        _cs("withMode",
                            ["fieldConfig+", "defaults+", "thresholds+", "mode"],
                            default="absolute", has_default=True),
                    ],
                ),
            ],
            trailing_setters=[
                _cs("withOverrides", ["fieldConfig+", "overrides"]),
            ],
        ),
        Group(
            name="options",
            setters=[],
            groups=[
                Group(
                    name="legend",
                    setters=[
                        _cs("withShowLegend", ["options+", "legend+", "showLegend"],
                            default=True, has_default=True),
                        _cs("withDisplayMode", ["options+", "legend+", "displayMode"]),
                        _cs("withPlacement", ["options+", "legend+", "placement"]),
                        _cs("withCalcs", ["options+", "legend+", "calcs"]),
                    ],
                ),
                Group(
                    name="tooltip",
                    setters=[
                        _cs("withMode", ["options+", "tooltip+", "mode"]),
                    ],
                ),
            ],
        ),
        Group(
            name="custom",
            setters=[
                _cs("withFillOpacity",
                    ["fieldConfig+", "defaults+", "custom+", "fillOpacity"]),
                _cs("withLineWidth",
                    ["fieldConfig+", "defaults+", "custom+", "lineWidth"]),
                _cs("withShowPoints",
                    ["fieldConfig+", "defaults+", "custom+", "showPoints"]),
                _cs("withDrawStyle",
                    ["fieldConfig+", "defaults+", "custom+", "drawStyle"]),
                _cs("withGradientMode",
                    ["fieldConfig+", "defaults+", "custom+", "gradientMode"]),
            ],
            groups=[
                Group(
                    name="stacking",
                    setters=[
                        _cs("withMode",
                            ["fieldConfig+", "defaults+", "custom+", "stacking+",
                             "mode"]),
                    ],
                ),
                Group(
                    name="scaleDistribution",
                    setters=[
                        _cs("withType",
                            ["fieldConfig+", "defaults+", "custom+",
                             "scaleDistribution+", "type"]),
                        _cs("withLog",
                            ["fieldConfig+", "defaults+", "custom+",
                             "scaleDistribution+", "log"]),
                    ],
                ),
            ],
        ),
    ],
}


# ---------------------------------------------------------------------------
# _versions map: viz kind -> pluginVersion pin (empty string until pinned).
# ---------------------------------------------------------------------------
VERSIONS = [
    "timeseries", "stat", "table", "gauge", "bargauge", "piechart",
    "heatmap", "logs", "text", "state-timeline", "alertlist",
]


# ---------------------------------------------------------------------------
# Import maps (plain `import` objects).
# ---------------------------------------------------------------------------
# (key, import-path) pairs.
MAIN_IMPORTS = [
    ("dashboard", "gen/observ-viz-v2beta1/dashboard.libsonnet"),
    ("annotation", "gen/observ-viz-v2beta1/annotation.libsonnet"),
    ("timeSettings", "gen/observ-viz-v2beta1/timeSettings.libsonnet"),
    ("panel", "gen/observ-viz-v2beta1/panel/main.libsonnet"),
    ("query", "gen/observ-viz-v2beta1/query/main.libsonnet"),
    ("variable", "gen/observ-viz-v2beta1/variable/main.libsonnet"),
    # NEW schema-driven structural kinds.
    ("layout", "gen/observ-viz-v2beta1/layout/main.libsonnet"),
    ("conditionalRendering", "gen/observ-viz-v2beta1/conditionalRendering.libsonnet"),
]

PANEL_MAIN_IMPORTS = [
    ("timeSeries", "gen/observ-viz-v2beta1/panel/timeSeries.libsonnet"),
    ("stat", "gen/observ-viz-v2beta1/panel/stat.libsonnet"),
    ("table", "gen/observ-viz-v2beta1/panel/table.libsonnet"),
]

QUERY_MAIN_IMPORTS = [
    ("prometheus", "gen/observ-viz-v2beta1/query/prometheus.libsonnet"),
    ("loki", "gen/observ-viz-v2beta1/query/loki.libsonnet"),
]
